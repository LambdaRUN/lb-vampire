LBVampire = LBVampire or {}
LBVampire.ClientState = LBVampire.ClientState or {}
LBVampire.BeastCallClient = LBVampire.BeastCallClient or {}

local Beast = LBVampire.BeastCallClient

Beast.active = false
Beast.token = nil
Beast.phase = 'IDLE'
Beast.animalKey = nil
Beast.label = nil
Beast.model = nil
Beast.animationProfile = nil
Beast.preyPed = nil
Beast.netId = nil
Beast.maxBlood = nil
Beast.feeding = false
Beast.interruptSent = false
Beast.generation = 0
Beast.nextPulseAt = 0
Beast.startHealth = nil
Beast.startArmor = nil
Beast.lastCoords = nil
Beast.bloodFxGeneration = 0

local function GetConfig()
    return Config.BeastCall or {}
end

local function GetSpawnConfig()
    return GetConfig().Spawn or {}
end

local function GetTrackingConfig()
    return GetConfig().Tracking or {}
end

local function GetFeedingConfig()
    return GetConfig().Feeding or {}
end

local function GetBloodEffectsConfig()
    return GetFeedingConfig().BloodEffects or {}
end

local function Notify(message, notifyType, duration)
    TriggerEvent('QBCore:Notify', message, notifyType or 'primary', duration or 5000)
end

local function Distance(a, b)
    if not a or not b then return math.huge end
    local dx = a.x - b.x
    local dy = a.y - b.y
    local dz = a.z - b.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function RequestControl(entity, timeout)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return false end
    if NetworkHasControlOfEntity(entity) then return true end

    timeout = tonumber(timeout) or 1500
    local expires = GetGameTimer() + timeout

    repeat
        NetworkRequestControlOfEntity(entity)
        Wait(20)
        if NetworkHasControlOfEntity(entity) then return true end
    until GetGameTimer() >= expires

    return NetworkHasControlOfEntity(entity)
end

local function LoadModel(modelName, timeout)
    local hash = joaat(tostring(modelName or ''))
    if hash == 0 or not IsModelInCdimage(hash) or not IsModelValid(hash) then
        return nil
    end

    RequestModel(hash)
    local expires = GetGameTimer() + math.max(tonumber(timeout) or 5000, 500)

    while not HasModelLoaded(hash) do
        Wait(20)
        if GetGameTimer() >= expires then
            return nil
        end
    end

    return hash
end

local function LoadAnimDict(dictionary)
    dictionary = tostring(dictionary or '')
    if dictionary == '' then return false end
    if HasAnimDictLoaded(dictionary) then return true end

    RequestAnimDict(dictionary)
    local expires = GetGameTimer() + 5000

    while not HasAnimDictLoaded(dictionary) do
        Wait(10)
        if GetGameTimer() >= expires then return false end
    end

    return true
end

local function LoadPtfxAsset(assetName, timeout)
    assetName = tostring(assetName or '')
    if assetName == '' then return false end
    if HasNamedPtfxAssetLoaded(assetName) then return true end

    RequestNamedPtfxAsset(assetName)
    local expires = GetGameTimer() + math.max(math.floor(tonumber(timeout) or 3000), 250)

    while not HasNamedPtfxAssetLoaded(assetName) do
        Wait(10)
        if GetGameTimer() >= expires then
            return false
        end
    end

    return true
end

local function RandomInterval(minimum, maximum)
    local minValue = math.max(math.floor(tonumber(minimum) or 0), 0)
    local maxValue = math.max(math.floor(tonumber(maximum) or minValue), minValue)
    if maxValue <= minValue then return minValue end
    return math.random(minValue, maxValue)
end

local function StopAnimalBloodEffects()
    -- Non-looped blood pulses run in a generation-scoped thread. Incrementing
    -- this value stops any further flow/accent pulses immediately.
    Beast.bloodFxGeneration = (tonumber(Beast.bloodFxGeneration) or 0) + 1
end

local function PlayBloodFxOnPedBone(assetName, effectName, prey, boneIndex, offsetX, offsetY, offsetZ, scale)
    if not prey or prey == 0 or not DoesEntityExist(prey) then return false end

    effectName = tostring(effectName or '')
    if effectName == '' then return false end

    UseParticleFxAssetNextCall(assetName)

    return StartParticleFxNonLoopedOnPedBone(
        effectName,
        prey,
        tonumber(offsetX) or 0.0,
        tonumber(offsetY) or 0.0,
        tonumber(offsetZ) or 0.0,
        0.0,
        0.0,
        0.0,
        boneIndex,
        math.max(tonumber(scale) or 0.10, 0.01),
        false,
        false,
        false
    ) == true
end

local function AddAnimalGroundBloodDecal(prey, profile, groundConfig)
    if not prey or prey == 0 or not DoesEntityExist(prey) then return false end
    if not groundConfig or groundConfig.Enabled ~= true then return false end

    local boneId = math.floor(tonumber(profile.AnchorBone) or 31086)
    local anchorCoords = GetPedBoneCoords(prey, boneId, 0.0, 0.0, 0.0)
    if not anchorCoords then return false end

    local spread = math.max(tonumber(groundConfig.Spread) or 0.0, 0.0)
    local jitterX = ((math.random() * 2.0) - 1.0) * spread
    local jitterY = ((math.random() * 2.0) - 1.0) * spread
    local x = anchorCoords.x + jitterX
    local y = anchorCoords.y + jitterY

    local foundGround, groundZ = GetGroundZFor_3dCoord(
        x,
        y,
        anchorCoords.z + 2.5,
        false
    )

    if not foundGround then return false end

    local profileFx = profile.BloodEffect or {}
    local scale = math.max(tonumber(profileFx.GroundScale) or 1.0, 0.05)
    local width = math.max((tonumber(groundConfig.Width) or 0.62) * scale, 0.05)
    local height = math.max((tonumber(groundConfig.Height) or 0.62) * scale, 0.05)

    AddDecal(
        math.floor(tonumber(groundConfig.DecalType) or 9001),
        x,
        y,
        groundZ + (tonumber(groundConfig.GroundOffsetZ) or 0.018),
        0.0,
        0.0,
        -1.0,
        0.0,
        1.0,
        0.0,
        width,
        height,
        tonumber(groundConfig.Red) or 0.32,
        tonumber(groundConfig.Green) or 0.0,
        tonumber(groundConfig.Blue) or 0.0,
        tonumber(groundConfig.Opacity) or 0.88,
        tonumber(groundConfig.Timeout) or 45.0,
        false,
        false,
        false
    )

    return true
end

local function StartAnimalBloodEffects(generation)
    local prey = Beast.preyPed
    if not prey or prey == 0 or not DoesEntityExist(prey) then return end
    if Beast.active ~= true or Beast.feeding ~= true or generation ~= Beast.generation then return end

    local feedingConfig = GetFeedingConfig()
    local profiles = feedingConfig.AnimationProfiles or {}
    local profile = profiles[Beast.animationProfile] or profiles.deer or profiles.boar
    local config = GetBloodEffectsConfig()

    if not profile or config.Enabled ~= true then return end

    local assetName = tostring(config.Asset or 'core')
    if not LoadPtfxAsset(assetName, config.LoadTimeout) then
        if Config.Debug then
            print(('^1[LB-VAMPIRE]^7 Animal blood PTFX asset failed | Asset:%s'):format(assetName))
        end
        return
    end

    if Beast.active ~= true or Beast.feeding ~= true or generation ~= Beast.generation then return end

    StopAnimalBloodEffects()
    local fxGeneration = Beast.bloodFxGeneration
    local profileFx = profile.BloodEffect or {}
    local boneId = math.floor(tonumber(profile.AnchorBone) or 31086)
    local boneIndex = GetPedBoneIndex(prey, boneId)
    if not boneIndex or boneIndex < 0 then boneIndex = 0 end

    local flow = config.Flow or {}
    local accent = config.Accent or {}
    local ground = config.Ground or {}
    local effects = accent.Effects or {}
    local now = GetGameTimer()
    local nextFlowAt = now
    local nextAccentAt = now + RandomInterval(accent.MinInterval, accent.MaxInterval)
    local nextGroundAt = now + math.max(math.floor(tonumber(ground.InitialDelay) or 650), 0)
    local groundCount = 0
    local maxGroundDecals = math.max(math.floor(tonumber(ground.MaxDecals) or 3), 0)

    CreateThread(function()
        while
            Beast.active == true and
            Beast.feeding == true and
            generation == Beast.generation and
            fxGeneration == Beast.bloodFxGeneration and
            prey == Beast.preyPed and
            DoesEntityExist(prey)
        do
            Wait(100)

            local now = GetGameTimer()

            if flow.Enabled == true and now >= nextFlowAt then
                PlayBloodFxOnPedBone(
                    assetName,
                    tostring(flow.Effect or 'blood_fall'),
                    prey,
                    boneIndex,
                    flow.OffsetX,
                    flow.OffsetY,
                    flow.OffsetZ,
                    profileFx.FlowScale
                )

                nextFlowAt = now + math.max(math.floor(tonumber(flow.Interval) or 280), 120)
            end

            if accent.Enabled == true and #effects > 0 and now >= nextAccentAt then
                PlayBloodFxOnPedBone(
                    assetName,
                    tostring(effects[math.random(1, #effects)]),
                    prey,
                    boneIndex,
                    accent.OffsetX,
                    accent.OffsetY,
                    accent.OffsetZ,
                    profileFx.AccentScale
                )

                nextAccentAt = now + RandomInterval(accent.MinInterval, accent.MaxInterval)
            end

            if
                ground.Enabled == true and
                groundCount < maxGroundDecals and
                now >= nextGroundAt
            then
                if AddAnimalGroundBloodDecal(prey, profile, ground) then
                    groundCount = groundCount + 1
                end

                nextGroundAt = now + math.max(math.floor(tonumber(ground.Interval) or 1400), 250)
            end
        end
    end)
end

local function GetNetworkPed(netId, timeout)
    netId = tonumber(netId)
    if not netId or netId <= 0 then return nil end

    local expires = GetGameTimer() + math.max(tonumber(timeout) or 2000, 0)
    repeat
        if NetworkDoesEntityExistWithNetworkId(netId) then
            local ped = NetToPed(netId)
            if ped and ped ~= 0 and DoesEntityExist(ped) then return ped end
        end
        Wait(25)
    until GetGameTimer() >= expires

    return nil
end

local function HideScentUI()
    SendNUIMessage({
        action = 'scent:hide'
    })
end

local function ShowScentUI()
    SendNUIMessage({
        action = 'scent:tracking',
        visible = true
    })
end

local function PulseScentUI(strengthKey, label, direction, duration)
    SendNUIMessage({
        action = 'scent:pulse',
        strength = tostring(strengthKey or 'FAINT'),
        label = tostring(label or 'KOKU'),
        direction = tostring(direction or 'ÖNÜNDE'),
        duration = math.max(math.floor(tonumber(duration) or 450), 150)
    })
end

local function NormalizeAngle(angle)
    angle = tonumber(angle) or 0.0
    while angle > 180.0 do angle = angle - 360.0 end
    while angle < -180.0 do angle = angle + 360.0 end
    return angle
end

local function GetDirectionLabel(playerPed, playerCoords, preyCoords)
    local dx = preyCoords.x - playerCoords.x
    local dy = preyCoords.y - playerCoords.y
    local targetHeading = GetHeadingFromVector_2d(dx, dy)
    local relative = NormalizeAngle(targetHeading - GetEntityHeading(playerPed))
    local absolute = math.abs(relative)

    if absolute <= 38.0 then
        return 'ÖNÜNDE'
    end

    if absolute >= 142.0 then
        return 'ARKANDA'
    end

    if relative > 0.0 then
        return 'SOLDA'
    end

    return 'SAĞDA'
end

function Beast.GetScentStrength(distance)
    local tracking = GetTrackingConfig()
    local strengths = tracking.Strengths or {}
    local faint = strengths.Faint or {}
    local detected = strengths.Detected or {}
    local strong = strengths.Strong or {}
    local nearby = strengths.Nearby or {}

    distance = tonumber(distance) or math.huge

    if distance >= (tonumber(faint.MinDistance) or 120.0) then
        return faint, 'FAINT'
    end

    if distance >= (tonumber(detected.MinDistance) or 65.0) then
        return detected, 'DETECTED'
    end

    if distance >= (tonumber(strong.MinDistance) or 28.0) then
        return strong, 'STRONG'
    end

    return nearby, 'NEARBY'
end

local function RemovePreyTarget(entity)
    if not entity or entity == 0 then return end
    if LBVampire.TargetBridge and LBVampire.TargetBridge.UnregisterBeastPrey then
        LBVampire.TargetBridge.UnregisterBeastPrey(entity)
    end
end

local function RegisterPreyTarget(entity)
    if not entity or entity == 0 then return false end

    if LBVampire.TargetBridge and LBVampire.TargetBridge.RegisterBeastPrey then
        return LBVampire.TargetBridge.RegisterBeastPrey(entity)
    end

    CreateThread(function()
        for _ = 1, 30 do
            Wait(100)
            if not Beast.active or Beast.preyPed ~= entity then return end
            if LBVampire.TargetBridge and LBVampire.TargetBridge.RegisterBeastPrey then
                LBVampire.TargetBridge.RegisterBeastPrey(entity)
                return
            end
        end
    end)

    return false
end

local function DeletePreyLater(ped, delay)
    if not ped or ped == 0 then return end

    CreateThread(function()
        Wait(math.max(tonumber(delay) or 0, 0))

        if not DoesEntityExist(ped) then return end
        RequestControl(ped, 1000)
        SetEntityAsMissionEntity(ped, true, true)
        DeletePed(ped)

        if DoesEntityExist(ped) then
            DeleteEntity(ped)
        end
    end)
end

local function ClearPlayerAnimation()
    StopAnimalBloodEffects()

    local playerPed = PlayerPedId()
    if playerPed and playerPed ~= 0 then
        FreezeEntityPosition(playerPed, false)
        ClearPedTasks(playerPed)
        ClearPedSecondaryTask(playerPed)
    end
end

local function RestorePrey(ped)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end

    RequestControl(ped, 750)
    FreezeEntityPosition(ped, false)
    SetBlockingOfNonTemporaryEvents(ped, false)
    SetPedCanRagdoll(ped, true)
end

local function ResetState(keepEntity)
    HideScentUI()
    StopAnimalBloodEffects()
    Beast.generation = Beast.generation + 1

    if not keepEntity and Beast.preyPed and Beast.preyPed ~= 0 then
        RemovePreyTarget(Beast.preyPed)
    end

    Beast.active = false
    Beast.token = nil
    Beast.phase = 'IDLE'
    Beast.animalKey = nil
    Beast.label = nil
    Beast.model = nil
    Beast.animationProfile = nil
    Beast.preyPed = nil
    Beast.netId = nil
    Beast.maxBlood = nil
    Beast.feeding = false
    Beast.interruptSent = false
    Beast.nextPulseAt = 0
    Beast.startHealth = nil
    Beast.startArmor = nil
    Beast.lastCoords = nil
end

local function FindSpawnCoords()
    local spawn = GetSpawnConfig()
    local playerPed = PlayerPedId()
    local origin = GetEntityCoords(playerPed)
    local attempts = math.max(math.floor(tonumber(spawn.Attempts) or 14), 1)
    local minDistance = math.max(tonumber(spawn.MinDistance) or 90.0, 20.0)
    local maxDistance = math.max(tonumber(spawn.MaxDistance) or 160.0, minDistance)
    local probeHeight = math.max(tonumber(spawn.GroundProbeHeight) or 60.0, 20.0)
    local collisionWait = math.max(math.floor(tonumber(spawn.CollisionWait) or 120), 0)

    for _ = 1, attempts do
        local angle = math.random() * math.pi * 2.0
        local distance = minDistance + (math.random() * (maxDistance - minDistance))
        local x = origin.x + math.cos(angle) * distance
        local y = origin.y + math.sin(angle) * distance
        local probeZ = origin.z + probeHeight

        RequestCollisionAtCoord(x, y, probeZ)
        Wait(collisionWait)

        local found, groundZ = GetGroundZFor_3dCoord(x, y, probeZ, false)
        if found then
            return vector3(x, y, groundZ + 0.35)
        end
    end

    return nil
end

local function SpawnAuthorizedPrey(data)
    local generation = Beast.generation
    local spawn = GetSpawnConfig()
    local hash = LoadModel(data.model, spawn.ModelTimeout)

    if not hash then
        TriggerServerEvent('lb-vampire:server:beastSpawnFailed', data.token, 'model_load_failed')
        ResetState()
        return
    end

    local coords = FindSpawnCoords()
    if not coords then
        SetModelAsNoLongerNeeded(hash)
        TriggerServerEvent('lb-vampire:server:beastSpawnFailed', data.token, 'ground_not_found')
        ResetState()
        return
    end

    if generation ~= Beast.generation or Beast.active ~= true then
        SetModelAsNoLongerNeeded(hash)
        return
    end

    local heading = math.random() * 360.0
    local ped = CreatePed(28, hash, coords.x, coords.y, coords.z, heading, true, true)
    SetModelAsNoLongerNeeded(hash)

    if not ped or ped == 0 or not DoesEntityExist(ped) then
        TriggerServerEvent('lb-vampire:server:beastSpawnFailed', data.token, 'create_ped_failed')
        ResetState()
        return
    end

    SetEntityAsMissionEntity(ped, true, true)
    SetPedKeepTask(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, false)

    if not NetworkGetEntityIsNetworked(ped) then
        NetworkRegisterEntityAsNetworked(ped)
    end

    local expires = GetGameTimer() + 1500
    while not NetworkGetEntityIsNetworked(ped) and GetGameTimer() < expires do
        Wait(20)
    end

    local netId = NetworkGetNetworkIdFromEntity(ped)
    if not netId or netId <= 0 then
        DeletePed(ped)
        TriggerServerEvent('lb-vampire:server:beastSpawnFailed', data.token, 'netid_failed')
        ResetState()
        return
    end

    SetNetworkIdCanMigrate(netId, true)

    local wanderRadius = tonumber(spawn.WanderRadius) or 28.0
    TaskWanderInArea(ped, coords.x, coords.y, coords.z, wanderRadius, 2.0, 10.0)

    Beast.preyPed = ped
    Beast.netId = netId
    Beast.phase = 'WAITING_SERVER'

    TriggerServerEvent('lb-vampire:server:registerBeastPrey', data.token, netId)

    if Config.Debug then
        print(('^2[LB-VAMPIRE]^7 Beast prey spawned | Animal:%s | NetID:%s | Coords:%.2f %.2f %.2f'):format(
            tostring(data.animalKey), tostring(netId), coords.x, coords.y, coords.z
        ))
    end
end

function Beast.CanFeed(entity, targetDistance)
    if GetConfig().Enabled ~= true or Beast.active ~= true then return false end
    if Beast.phase ~= 'TRACKING' and Beast.phase ~= 'PREY_FOUND' then return false end
    if Beast.feeding == true then return false end
    if not entity or entity == 0 or entity ~= Beast.preyPed or not DoesEntityExist(entity) then return false end
    if IsEntityDead(entity) then return false end
    if LBVampire.ClientState.isVampire ~= true then return false end
    if (LBVampire.ClientState.interactionState or 'IDLE') ~= 'IDLE' then return false end

    local vampireBlood = tonumber(LBVampire.ClientState.blood) or 0
    local vampireMax = tonumber(LBVampire.ClientState.maxBlood) or tonumber(Config.Blood and Config.Blood.Max) or 100
    if vampireBlood >= vampireMax - 0.001 then return false end

    local playerPed = PlayerPedId()
    if IsEntityDead(playerPed) or IsPedInAnyVehicle(playerPed, false) then return false end

    local maximum = tonumber(GetFeedingConfig().Interaction and GetFeedingConfig().Interaction.Distance) or 2.5
    if targetDistance and tonumber(targetDistance) and tonumber(targetDistance) > maximum then return false end

    return Distance(GetEntityCoords(playerPed), GetEntityCoords(entity)) <= maximum + 0.25
end

function Beast.RequestFeed(entity)
    if not Beast.CanFeed(entity) then
        Notify('Bu avdan şu anda beslenemezsin.', 'error')
        return false
    end

    Beast.phase = 'WAITING_FEED'
    TriggerServerEvent('lb-vampire:server:requestBeastFeeding', Beast.token, Beast.netId)
    return true
end

function Beast.Use()
    local config = GetConfig()
    if config.Enabled ~= true then
        Notify('Beast Call şu anda devre dışı.', 'error')
        return false
    end

    if LBVampire.ClientState.isVampire ~= true then
        Notify('Bu yeteneği yalnız vampirler kullanabilir.', 'error')
        return false
    end

    if Beast.active == true then
        Notify('Zaten aktif bir Beast Call avın var.', 'error')
        return false
    end

    if (LBVampire.ClientState.interactionState or 'IDLE') ~= 'IDLE' then
        Notify('Başka bir etkileşim sürerken Beast Call kullanamazsın.', 'error')
        return false
    end

    local playerPed = PlayerPedId()
    if IsEntityDead(playerPed) or IsPedInAnyVehicle(playerPed, false) then
        Notify('Şu anda Beast Call kullanamazsın.', 'error')
        return false
    end

    TriggerServerEvent('lb-vampire:server:requestBeastCall')
    return true
end

local function GetGroundedPlayerRootZ(playerPed, x, y, probeZ, extraOffset)
    if not playerPed or playerPed == 0 or not DoesEntityExist(playerPed) then return nil end

    local playerCoords = GetEntityCoords(playerPed)
    local foundGround, groundZ = GetGroundZFor_3dCoord(
        x,
        y,
        tonumber(probeZ) or (playerCoords.z + 3.0),
        false
    )

    if not foundGround then
        return playerCoords.z
    end

    -- Ped entity coord'u ayak tabanı değildir; freemode pedlerde root/origin
    -- pelvis civarındadır. GroundZ'yi doğrudan SetEntityCoords'a verirsek
    -- karakterin alt yarısı zemine gömülür. Model bounding box'un alt
    -- noktasını kullanarak root'un zeminden gerçek yüksekliğini koruyoruz.
    local minDim = GetModelDimensions(GetEntityModel(playerPed))
    local rootToFeet = 1.0

    if minDim and tonumber(minDim.z) then
        local modelOffset = math.abs(tonumber(minDim.z))
        if modelOffset >= 0.35 and modelOffset <= 1.50 then
            rootToFeet = modelOffset
        end
    end

    return groundZ + rootToFeet + (tonumber(extraOffset) or 0.0)
end

local function GetAnimalFeedingTransform(prey, playerPed, profile)
    if not prey or prey == 0 or not DoesEntityExist(prey) then return nil, nil end
    if not playerPed or playerPed == 0 or not DoesEntityExist(playerPed) then return nil, nil end

    profile = profile or {}

    local boneId = math.floor(tonumber(profile.AnchorBone) or 31086)
    local anchor = GetPedBoneCoords(prey, boneId, 0.0, 0.0, 0.0)
    local preyCoords = GetEntityCoords(prey)

    -- Bazı custom animal modellerinde head bone bulunmazsa entity
    -- merkezinden öne doğru güvenli bir fallback kullan.
    if not anchor or (math.abs(anchor.x) < 0.001 and math.abs(anchor.y) < 0.001) then
        anchor = GetOffsetFromEntityInWorldCoords(prey, 0.0, 0.75, 0.55)
    end

    local heading = GetEntityHeading(prey)
    local radians = math.rad(heading)

    -- GTA heading: 0 = +Y. Bu vektörler hayvanın local right/forward
    -- eksenlerini world-space'e çevirir.
    local forwardX = -math.sin(radians)
    local forwardY = math.cos(radians)
    local rightX = math.cos(radians)
    local rightY = math.sin(radians)

    local side = tonumber(profile.SideOffset) or 0.45
    local forwardOffset = tonumber(profile.ForwardOffset) or -0.25

    local x = anchor.x + (rightX * side) + (forwardX * forwardOffset)
    local y = anchor.y + (rightY * side) + (forwardY * forwardOffset)

    -- X/Y boyun/baş anchor'ından gelir. Z ise oyuncu pedinin ROOT yüksekliği
    -- korunarak zeminden hesaplanır. GroundZ'yi doğrudan entity Z yapmak
    -- pedin pelvis/root noktasını zemine koyup karakteri yarıya kadar gömer.
    local z = GetGroundedPlayerRootZ(
        playerPed,
        x,
        y,
        math.max(anchor.z + 2.5, preyCoords.z + 3.0),
        tonumber(profile.GroundOffsetZ) or 0.0
    )

    if not z then
        z = GetEntityCoords(playerPed).z
    end

    local faceHeading = heading + (tonumber(profile.HeadingOffset) or 90.0)
    if profile.FaceAnchor ~= false then
        faceHeading = GetHeadingFromVector_2d(anchor.x - x, anchor.y - y)
    end

    -- Ped animasyonu oynarken full SetEntityRotation kullanmak anim task'ını
    -- görsel olarak ezebiliyor. Beast feeding için ihtiyacımız olan ince ayar
    -- yatay yön (RotZ); bunu heading'e ekleyip animasyondan önce uygularız.
    local feedHeading = (faceHeading + (tonumber(profile.RotZ) or 0.0)) % 360.0

    return vector3(x, y, z), feedHeading
end

local function ApplyAnimalFeedingTransform(playerPed, coords, heading)
    SetEntityCoordsNoOffset(
        playerPed,
        coords.x,
        coords.y,
        coords.z,
        false,
        false,
        false
    )

    SetEntityHeading(playerPed, tonumber(heading) or GetEntityHeading(playerPed))
end

local function StartAnimalFeedingAnimation(generation)
    local prey = Beast.preyPed
    local playerPed = PlayerPedId()
    if not prey or prey == 0 or not DoesEntityExist(prey) then return end

    local profiles = GetFeedingConfig().AnimationProfiles or {}
    local profile = profiles[Beast.animationProfile] or profiles.deer or profiles.boar
    if not profile then
        TriggerServerEvent('lb-vampire:server:cancelBeastFeeding', 'animation_profile_missing')
        return
    end

    if not RequestControl(prey, 1500) then
        TriggerServerEvent('lb-vampire:server:cancelBeastFeeding', 'prey_control_failed')
        return
    end

    local dictionary = tostring(profile.Dictionary or '')
    local animation = tostring(profile.Animation or '')
    if not LoadAnimDict(dictionary) then
        TriggerServerEvent('lb-vampire:server:cancelBeastFeeding', 'animation_dictionary')
        return
    end

    if Beast.active ~= true or Beast.feeding ~= true or generation ~= Beast.generation then return end

    ClearPedTasksImmediately(prey)
    ClearPedSecondaryTask(prey)
    SetEntityVelocity(prey, 0.0, 0.0, 0.0)
    SetBlockingOfNonTemporaryEvents(prey, true)
    SetPedCanRagdoll(prey, false)
    FreezeEntityPosition(prey, true)

    ClearPedTasks(playerPed)
    ClearPedSecondaryTask(playerPed)
    SetEntityVelocity(playerPed, 0.0, 0.0, 0.0)

    local feedCoords, feedHeading = GetAnimalFeedingTransform(prey, playerPed, profile)
    if not feedCoords or feedHeading == nil then
        TriggerServerEvent('lb-vampire:server:cancelBeastFeeding', 'feeding_transform_failed')
        return
    end

    ApplyAnimalFeedingTransform(playerPed, feedCoords, feedHeading)

    -- Oyuncu ile hayvan collision/root-motion nedeniyle birbirini itmesin.
    -- Beslenme bittiğinde ClearPlayerAnimation bunu geri açar.
    FreezeEntityPosition(playerPed, true)

    Wait(60)
    if Beast.active ~= true or Beast.feeding ~= true or generation ~= Beast.generation then
        FreezeEntityPosition(playerPed, false)
        return
    end

    -- Anim başlamadan hemen önce ikinci kez snap: eğimli arazide veya
    -- önceki task'tan kalan root motion'da ilk frame kaymasını temizler.
    ApplyAnimalFeedingTransform(playerPed, feedCoords, feedHeading)

    TaskPlayAnim(
        playerPed,
        dictionary,
        animation,
        8.0,
        -8.0,
        -1,
        tonumber(profile.Flag) or 1,
        0.0,
        false,
        false,
        false
    )

    StartAnimalBloodEffects(generation)
end

local function CancelFeeding(reason)
    if Beast.active ~= true or Beast.feeding ~= true or Beast.interruptSent == true then return end
    Beast.interruptSent = true
    TriggerServerEvent('lb-vampire:server:cancelBeastFeeding', tostring(reason or 'client_interrupt'))
end

local function StartInterruptMonitor(generation)
    local config = GetFeedingConfig().Interrupts or {}
    if config.Enabled ~= true then return end

    local interval = math.max(tonumber(config.ClientCheckInterval) or 100, 50)
    local playerPed = PlayerPedId()

    Beast.startHealth = GetEntityHealth(playerPed)
    Beast.startArmor = GetPedArmour(playerPed)
    Beast.lastCoords = GetEntityCoords(playerPed)

    while Beast.active == true and Beast.feeding == true and generation == Beast.generation do
        Wait(interval)

        if Beast.active ~= true or Beast.feeding ~= true or generation ~= Beast.generation then break end

        playerPed = PlayerPedId()
        local prey = Beast.preyPed

        if not playerPed or playerPed == 0 or IsEntityDead(playerPed) then
            CancelFeeding('death')
            break
        end

        if not prey or prey == 0 or not DoesEntityExist(prey) or IsEntityDead(prey) then
            CancelFeeding('prey_unavailable')
            break
        end

        if config.CancelInVehicle == true and IsPedInAnyVehicle(playerPed, false) then
            CancelFeeding('vehicle')
            break
        end

        if config.CancelOnRagdoll == true and IsPedRagdoll(playerPed) then
            CancelFeeding('ragdoll')
            break
        end

        if config.CancelOnDamage == true then
            local health = GetEntityHealth(playerPed)
            local armor = GetPedArmour(playerPed)

            if health < (Beast.startHealth or health) or armor < (Beast.startArmor or armor) then
                CancelFeeding('damage')
                break
            end

            Beast.startHealth = health
            Beast.startArmor = armor
        end

        local currentCoords = GetEntityCoords(playerPed)
        local preyCoords = GetEntityCoords(prey)
        local maxDistance = tonumber(config.MaxDistance) or 3.5

        if Distance(currentCoords, preyCoords) > maxDistance then
            CancelFeeding('distance')
            break
        end

        if Beast.lastCoords then
            local teleportDistance = tonumber(config.TeleportDistance) or 5.0
            if Distance(currentCoords, Beast.lastCoords) > teleportDistance then
                CancelFeeding('teleport')
                break
            end
        end

        Beast.lastCoords = currentCoords
    end
end

local function HandleStoppedPrey(data)
    local ped = Beast.preyPed
    if (not ped or ped == 0 or not DoesEntityExist(ped)) and data.netId then
        ped = GetNetworkPed(data.netId, 500)
    end

    ClearPlayerAnimation()

    if not ped or ped == 0 or not DoesEntityExist(ped) then return end

    RemovePreyTarget(ped)
    RestorePrey(ped)

    local outcome = tostring(data.outcome or 'lost')

    if outcome == 'released' then
        local playerPed = PlayerPedId()
        ClearPedTasksImmediately(ped)
        SetPedKeepTask(ped, true)
        TaskSmartFleePed(
            ped,
            playerPed,
            tonumber(GetConfig().Cleanup and GetConfig().Cleanup.FleeDistance) or 180.0,
            -1,
            false,
            false
        )
        DeletePreyLater(ped, data.releaseDespawnDelay or (GetConfig().Cleanup and GetConfig().Cleanup.ReleaseDespawnDelay))

    elseif outcome == 'drained' then
        ClearPedTasksImmediately(ped)
        SetEntityHealth(ped, 0)
        DeletePreyLater(ped, data.drainedDespawnDelay or (GetConfig().Cleanup and GetConfig().Cleanup.DrainedDespawnDelay))

    else
        DeletePreyLater(ped, data.lostDespawnDelay or (GetConfig().Cleanup and GetConfig().Cleanup.LostDespawnDelay))
    end
end

CreateThread(function()
    while true do
        if Beast.active == true and (Beast.phase == 'TRACKING' or Beast.phase == 'PREY_FOUND') then
            local prey = Beast.preyPed
            local playerPed = PlayerPedId()

            if not prey or prey == 0 or not DoesEntityExist(prey) or IsEntityDead(prey) then
                TriggerServerEvent('lb-vampire:server:beastPreyLost', Beast.token, 'prey_unavailable')
                ResetState()
                Wait(500)
            else
                local playerCoords = GetEntityCoords(playerPed)
                local preyCoords = GetEntityCoords(prey)
                local distance = Distance(playerCoords, preyCoords)
                local spawn = GetSpawnConfig()

                if distance > (tonumber(spawn.MaximumTrackingDistance) or 450.0) then
                    TriggerServerEvent('lb-vampire:server:beastPreyLost', Beast.token, 'tracking_distance')
                    local lostPed = Beast.preyPed
                    ResetState()
                    DeletePreyLater(lostPed, tonumber(GetConfig().Cleanup and GetConfig().Cleanup.LostDespawnDelay) or 1500)
                    Wait(500)
                else
                    local tracking = GetTrackingConfig()
                    local foundDistance = tonumber(tracking.FoundDistance) or 20.0
                    Beast.phase = distance <= foundDistance and 'PREY_FOUND' or 'TRACKING'

                    local now = GetGameTimer()
                    if now >= Beast.nextPulseAt then
                        local strength, strengthKey = Beast.GetScentStrength(distance)
                        local direction = GetDirectionLabel(playerPed, playerCoords, preyCoords)
                        local pulseDuration = tonumber(tracking.PulseDuration) or 450

                        PulseScentUI(
                            strengthKey,
                            strength.Label or 'KOKU',
                            direction,
                            pulseDuration
                        )

                        Beast.nextPulseAt = now + math.max(tonumber(strength.Interval) or 1000, 250)
                    end

                    Wait(50)
                end
            end

        elseif Beast.active == true and Beast.feeding == true then
            Wait(100)
        else
            Wait(300)
        end
    end
end)

CreateThread(function()
    while true do
        if Beast.active == true and Beast.feeding == true then
            DisableControlAction(0, 30, true)
            DisableControlAction(0, 31, true)
            DisableControlAction(0, 21, true)
            DisableControlAction(0, 22, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 37, true)
            DisableControlAction(0, 44, true)
            Wait(0)
        else
            Wait(250)
        end
    end
end)

RegisterNetEvent('lb-vampire:client:beastCallAuthorized', function(data)
    data = data or {}

    if Beast.active == true then return end

    Beast.generation = Beast.generation + 1
    Beast.active = true
    Beast.token = tostring(data.token or '')
    Beast.phase = 'SPAWNING'
    Beast.animalKey = tostring(data.animalKey or '')
    Beast.label = tostring(data.label or Beast.animalKey)
    Beast.model = tostring(data.model or '')
    Beast.animationProfile = tostring(data.animationProfile or 'deer')
    Beast.maxBlood = tonumber(data.maxBlood) or 1.0
    Beast.interruptSent = false

    CreateThread(function()
        SpawnAuthorizedPrey(data)
    end)
end)

RegisterNetEvent('lb-vampire:client:beastTrackingStarted', function(data)
    data = data or {}
    if Beast.active ~= true or tostring(data.token or '') ~= Beast.token then return end

    local ped = Beast.preyPed
    if not ped or ped == 0 or not DoesEntityExist(ped) then
        ped = GetNetworkPed(data.netId, 2000)
    end

    if not ped then
        TriggerServerEvent('lb-vampire:server:beastPreyLost', Beast.token, 'client_stream_failed')
        ResetState()
        return
    end

    Beast.preyPed = ped
    Beast.netId = tonumber(data.netId)
    Beast.label = tostring(data.label or Beast.label or 'Hayvan')
    Beast.animationProfile = tostring(data.animationProfile or Beast.animationProfile or 'deer')
    Beast.maxBlood = tonumber(data.maxBlood) or Beast.maxBlood
    Beast.phase = 'TRACKING'
    Beast.nextPulseAt = 0
    ShowScentUI()

    RegisterPreyTarget(ped)
end)

RegisterNetEvent('lb-vampire:client:beastFeedingStarted', function(data)
    data = data or {}
    if Beast.active ~= true or tostring(data.token or '') ~= Beast.token then return end

    Beast.phase = 'FEEDING'
    Beast.feeding = true
    HideScentUI()
    Beast.interruptSent = false
    Beast.label = tostring(data.label or Beast.label or 'Hayvan')
    Beast.animationProfile = tostring(data.animationProfile or Beast.animationProfile or 'deer')
    RemovePreyTarget(Beast.preyPed)

    local generation = Beast.generation
    CreateThread(function()
        StartAnimalFeedingAnimation(generation)
    end)

    CreateThread(function()
        StartInterruptMonitor(generation)
    end)
end)

RegisterNetEvent('lb-vampire:client:beastFeedingStopped', function(data)
    data = data or {}
    if Beast.active ~= true then return end
    if data.token and tostring(data.token) ~= Beast.token then return end

    HandleStoppedPrey(data)
    ResetState(true)
end)

RegisterNetEvent('lb-vampire:client:useBeastCall', function()
    Beast.Use()
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    local ped = Beast.preyPed
    ClearPlayerAnimation()
    if ped and ped ~= 0 then
        RemovePreyTarget(ped)
        RestorePrey(ped)
        DeletePreyLater(ped, 0)
    end
    ResetState(true)
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    HideScentUI()
    StopAnimalBloodEffects()
    local ped = Beast.preyPed
    ClearPlayerAnimation()

    if ped and ped ~= 0 and DoesEntityExist(ped) then
        RemovePreyTarget(ped)
        RequestControl(ped, 300)
        SetEntityAsMissionEntity(ped, true, true)
        DeletePed(ped)
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end
end)

if Config.Debug then
    RegisterCommand('vambeastcall', function()
        Beast.Use()
    end, false)
end

exports('UseBeastCall', function()
    return Beast.Use()
end)

exports('CanFeedBeastPrey', function(entity, distance)
    return Beast.CanFeed(entity, distance)
end)

exports('FeedBeastPrey', function(entity)
    return Beast.RequestFeed(entity)
end)

if LBVampire.Abilities and LBVampire.Abilities.Register then
    LBVampire.Abilities.Register('beast_call', {
        getMetadata = function()
            return {
                bloodCost = tonumber(Config.BeastCall and Config.BeastCall.BloodCost) or 10
            }
        end,
        execute = function()
            return Beast.Use()
        end
    })
end

