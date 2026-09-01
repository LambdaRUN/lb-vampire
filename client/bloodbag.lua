LBVampire = LBVampire or {}
LBVampire.BloodBagClient = LBVampire.BloodBagClient or {}

local BloodBag = LBVampire.BloodBagClient
local QBCore = exports['qb-core']:GetCoreObject()

BloodBag.activeToken = nil
BloodBag.fxGeneration = tonumber(BloodBag.fxGeneration) or 0
BloodBag.propEntity = nil
BloodBag.animationActive = false

local function GetConfig()
    return Config.Items
        and Config.Items.BloodBag
        and Config.Items.BloodBag.Use
        or {}
end

local function LoadModel(modelName, timeout)
    local model = joaat(tostring(modelName or ''))
    if model == 0 or not IsModelInCdimage(model) or not IsModelValid(model) then return nil end
    if HasModelLoaded(model) then return model end

    RequestModel(model)
    local expires = GetGameTimer() + math.max(math.floor(tonumber(timeout) or 3000), 250)
    while not HasModelLoaded(model) do
        Wait(10)
        if GetGameTimer() >= expires then return nil end
    end
    return model
end

local function LoadAnimDict(dict, timeout)
    dict = tostring(dict or '')
    if dict == '' then return false end
    if HasAnimDictLoaded(dict) then return true end

    RequestAnimDict(dict)
    local expires = GetGameTimer() + math.max(math.floor(tonumber(timeout) or 3000), 250)
    while not HasAnimDictLoaded(dict) do
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
        if GetGameTimer() >= expires then return false end
    end
    return true
end

local function DeleteBloodBagProp()
    local prop = BloodBag.propEntity
    BloodBag.propEntity = nil
    if prop and prop ~= 0 and DoesEntityExist(prop) then
        DetachEntity(prop, true, true)
        DeleteEntity(prop)
    end
end

local function StopPresentation()
    BloodBag.fxGeneration = (tonumber(BloodBag.fxGeneration) or 0) + 1

    local ped = PlayerPedId()
    if BloodBag.animationActive and ped and ped ~= 0 and DoesEntityExist(ped) then
        local animation = GetConfig().Animation or {}
        local dict = tostring(animation.Dictionary or 'mp_player_intdrink')
        local anim = tostring(animation.Animation or 'loop_bottle')
        StopAnimTask(ped, dict, anim, 1.0)
    end
    BloodBag.animationActive = false
    DeleteBloodBagProp()
end

local function StartPresentation()
    local useConfig = GetConfig()
    local ped = PlayerPedId()
    if not ped or ped == 0 or not DoesEntityExist(ped) then return false end

    local animation = useConfig.Animation or {}
    local dict = tostring(animation.Dictionary or 'mp_player_intdrink')
    local anim = tostring(animation.Animation or 'loop_bottle')
    local flag = math.floor(tonumber(animation.Flag) or 49)

    if LoadAnimDict(dict, 3000) then
        TaskPlayAnim(ped, dict, anim, 3.0, 3.0, -1, flag, 0.0, false, false, false)
        BloodBag.animationActive = true
    end

    local propConfig = useConfig.Prop or {}
    if propConfig.Enabled == true then
        local model = LoadModel(propConfig.Model or 'prop_energy_drink', 3000)
        if model then
            local coords = GetEntityCoords(ped)
            local prop = CreateObject(model, coords.x, coords.y, coords.z + 0.2, true, true, false)
            if prop and prop ~= 0 and DoesEntityExist(prop) then
                local placement = propConfig.Placement or {}
                local boneIndex = GetPedBoneIndex(ped, math.floor(tonumber(propConfig.Bone) or 60309))
                AttachEntityToEntity(
                    prop,
                    ped,
                    boneIndex,
                    tonumber(placement[1]) or 0.0080,
                    tonumber(placement[2]) or 0.0010,
                    tonumber(placement[3]) or 0.0160,
                    tonumber(placement[4]) or 3.5690,
                    tonumber(placement[5]) or 4.6611,
                    tonumber(placement[6]) or -49.9065,
                    true,
                    true,
                    false,
                    true,
                    1,
                    true
                )
                BloodBag.propEntity = prop
            end
            SetModelAsNoLongerNeeded(model)
        end
    end

    return true
end

local function StartBloodEffect(token)
    local useConfig = GetConfig()
    local fx = useConfig.BloodEffect or {}
    if fx.Enabled ~= true then return end

    local assetName = tostring(fx.Asset or 'core')
    if not LoadPtfxAsset(assetName, 3000) then return end

    BloodBag.fxGeneration = (tonumber(BloodBag.fxGeneration) or 0) + 1
    local generation = BloodBag.fxGeneration
    local interval = math.max(math.floor(tonumber(fx.Interval) or 650), 120)
    local effectName = tostring(fx.Effect or 'blood_mist')
    local scale = math.max(tonumber(fx.Scale) or 0.12, 0.01)

    CreateThread(function()
        while BloodBag.activeToken == token and generation == BloodBag.fxGeneration do
            local world = nil
            local heading = 0.0
            local prop = BloodBag.propEntity

            if fx.FollowProp ~= false and prop and prop ~= 0 and DoesEntityExist(prop) then
                world = GetOffsetFromEntityInWorldCoords(
                    prop,
                    tonumber(fx.OffsetX) or 0.015,
                    tonumber(fx.OffsetY) or 0.0,
                    tonumber(fx.OffsetZ) or 0.0
                )
                heading = GetEntityHeading(prop)
            elseif fx.FollowProp == false then
                local ped = PlayerPedId()
                if ped and ped ~= 0 and DoesEntityExist(ped) then
                    local bone = math.floor(tonumber((GetConfig().Prop or {}).Bone) or 60309)
                    world = GetPedBoneCoords(
                        ped,
                        bone,
                        tonumber(fx.OffsetX) or 0.015,
                        tonumber(fx.OffsetY) or 0.0,
                        tonumber(fx.OffsetZ) or 0.0
                    )
                    heading = GetEntityHeading(ped)
                end
            end

            if world then
                UseParticleFxAssetNextCall(assetName)
                StartParticleFxNonLoopedAtCoord(
                    effectName,
                    world.x,
                    world.y,
                    world.z,
                    0.0,
                    0.0,
                    heading,
                    scale,
                    false,
                    false,
                    false
                )
            end
            Wait(interval)
        end
    end)
end

local function FinishUse(token, completed)
    if BloodBag.activeToken ~= token then return end

    BloodBag.activeToken = nil
    StopPresentation()

    if completed then
        TriggerServerEvent('lb-vampire:server:bloodbag:completeUse', token)
    else
        TriggerServerEvent('lb-vampire:server:bloodbag:cancelUse', token)
    end
end

RegisterNetEvent('lb-vampire:client:bloodbag:startUse', function(data)
    data = data or {}
    local token = tostring(data.token or '')
    if token == '' then return end

    if BloodBag.activeToken then
        TriggerServerEvent('lb-vampire:server:bloodbag:cancelUse', token)
        return
    end

    local ped = PlayerPedId()
    if not ped or ped == 0 or IsEntityDead(ped) then
        TriggerServerEvent('lb-vampire:server:bloodbag:cancelUse', token)
        return
    end

    local useConfig = GetConfig()
    local duration = math.max(math.floor(tonumber(data.duration) or tonumber(useConfig.Duration) or 6000), 500)
    local label = tostring(data.label or useConfig.Label or 'Kan torbası kullanılıyor...')
    local disableControls = useConfig.DisableControls or {}

    BloodBag.activeToken = token
    StartPresentation()
    StartBloodEffect(token)

    -- Animation and prop are owned by LB-Vampire so the FX can follow the
    -- actual prop entity. The progressbar only owns timing/control lock.
    QBCore.Functions.Progressbar(
        'lb_vampire_bloodbag_use',
        label,
        duration,
        false,
        useConfig.CanCancel ~= false,
        {
            disableMovement = disableControls.disableMovement == true,
            disableCarMovement = disableControls.disableCarMovement ~= false,
            disableMouse = disableControls.disableMouse == true,
            disableCombat = disableControls.disableCombat ~= false
        },
        {},
        {},
        {},
        function()
            FinishUse(token, true)
        end,
        function()
            FinishUse(token, false)
        end
    )
end)

RegisterNetEvent('lb-vampire:client:bloodbag:forceCancel', function()
    local token = BloodBag.activeToken
    if not token then return end
    FinishUse(token, false)
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    BloodBag.activeToken = nil
    StopPresentation()
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    BloodBag.activeToken = nil
    StopPresentation()
end)
