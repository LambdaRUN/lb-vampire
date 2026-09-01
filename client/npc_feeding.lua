LBVampire = LBVampire or {}
LBVampire.ClientState = LBVampire.ClientState or {}
LBVampire.NPCFeedingClient = LBVampire.NPCFeedingClient or {}

local NPC = LBVampire.NPCFeedingClient

NPC.active = false
NPC.token = nil
NPC.netId = nil
NPC.victimPed = nil
NPC.generation = 0
NPC.startHealth = nil
NPC.startArmor = nil
NPC.lastCoords = nil
NPC.interruptSent = false

local function GetConfig()
    return Config.NPCFeeding or {}
end

local function GetAnimationConfig()
    return Config.Feeding and Config.Feeding.Animation or {}
end

local function GetInterruptConfig()
    return Config.Feeding and Config.Feeding.Interrupts or {}
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

local function GetOrCreateNetId(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        return nil
    end

    -- 0.4.6 debug target uses this exact network-registration pattern
    -- successfully on ambient NPCs. Keep the production path identical.
    if not NetworkGetEntityIsNetworked(entity) then
        NetworkRegisterEntityAsNetworked(entity)

        local timeout = GetGameTimer() + 1000
        while not NetworkGetEntityIsNetworked(entity) do
            Wait(20)

            if GetGameTimer() >= timeout then
                return nil
            end
        end
    end

    local netId = tonumber(NetworkGetNetworkIdFromEntity(entity))
    if not netId or netId <= 0 then
        return nil
    end

    return netId
end

local function GetNetworkPed(netId, timeout)
    netId = tonumber(netId)
    if not netId or netId <= 0 then return nil end

    timeout = tonumber(timeout) or 2000
    local expires = GetGameTimer() + timeout

    repeat
        if NetworkDoesEntityExistWithNetworkId(netId) then
            local ped = NetToPed(netId)
            if ped and ped ~= 0 and DoesEntityExist(ped) then return ped end
        end
        Wait(25)
    until GetGameTimer() >= expires

    return nil
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

local function IsValidNPC(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return false end
    if not IsEntityAPed(entity) then return false end
    if IsPedAPlayer(entity) then return false end
    if IsEntityDead(entity) then return false end

    if GetConfig().Witness and GetConfig().Witness.HumanOnly == true then
        if type(IsPedHuman) == 'function' and not IsPedHuman(entity) then
            return false
        end
    end

    return true
end

function NPC.CanFeed(entity, targetDistance)
    local config = GetConfig()
    if config.Enabled ~= true then return false end
    if LBVampire.ClientState.isVampire ~= true then return false end

    local vampireBlood = tonumber(LBVampire.ClientState.blood) or 0
    local vampireMax = tonumber(LBVampire.ClientState.maxBlood) or tonumber(Config.Blood and Config.Blood.Max) or 100
    if vampireBlood >= vampireMax - 0.001 then return false end

    if (LBVampire.ClientState.interactionState or 'IDLE') ~= 'IDLE' then return false end
    if NPC.active == true then return false end

    local playerPed = PlayerPedId()
    if not playerPed or playerPed == 0 or IsEntityDead(playerPed) then return false end
    if IsPedInAnyVehicle(playerPed, false) then return false end

    if not IsValidNPC(entity) then return false end
    if IsPedInAnyVehicle(entity, false) then return false end

    local maximum = tonumber(config.Interaction and config.Interaction.Distance) or 2.5
    if targetDistance and tonumber(targetDistance) and tonumber(targetDistance) > maximum then
        return false
    end

    return true
end

function NPC.Request(entity)
    if Config.Debug then
        print(('^5[LB-VAMPIRE]^7 NPC feeding target clicked | Entity:%s'):format(tostring(entity)))
    end

    if not NPC.CanFeed(entity) then
        Notify('Bu NPC ile şu anda beslenemezsin.', 'error')
        return false
    end

    local netId = GetOrCreateNetId(entity)
    if not netId then
        Notify('NPC ağ kimliği oluşturulamadı.', 'error')
        return false
    end

    TriggerServerEvent('lb-vampire:server:requestNPCFeeding', netId)

    if Config.Debug then
        print(('^5[LB-VAMPIRE]^7 NPC feeding requested | NetID:%s'):format(tostring(netId)))
    end

    return true
end

local function ClearVisuals()
    local playerPed = PlayerPedId()

    if playerPed and playerPed ~= 0 then
        if IsEntityAttached(playerPed) then
            DetachEntity(playerPed, true, true)
        end

        ClearPedTasks(playerPed)
        ClearPedSecondaryTask(playerPed)
    end

    local victim = NPC.victimPed
    if victim and victim ~= 0 and DoesEntityExist(victim) then
        RequestControl(victim, 750)

        if IsEntityAttached(victim) then
            DetachEntity(victim, true, true)
        end

        ClearPedTasks(victim)
        ClearPedSecondaryTask(victim)

        -- Feeding başlangıcında NPC'yi sabit ve düzgün hizalamak için
        -- ragdoll kapatılıyor. Session kapanırken mutlaka geri açıyoruz;
        -- aksi halde yarıda bırakma sonrası düşme/kaçma reaksiyonları bozulur.
        SetPedCanRagdoll(victim, true)
        SetBlockingOfNonTemporaryEvents(victim, false)
    end
end

local function ResetState()
    NPC.generation = NPC.generation + 1
    NPC.active = false
    NPC.token = nil
    NPC.netId = nil
    NPC.victimPed = nil
    NPC.startHealth = nil
    NPC.startArmor = nil
    NPC.lastCoords = nil
    NPC.interruptSent = false
end

local function Cancel(reason)
    if NPC.active ~= true or NPC.interruptSent == true then return end
    NPC.interruptSent = true

    ClearVisuals()
    TriggerServerEvent('lb-vampire:server:cancelNPCFeeding', tostring(reason or 'client_interrupt'))

    if Config.Debug then
        print(('^3[LB-VAMPIRE]^7 NPC feeding interrupt requested: %s'):format(tostring(reason)))
    end
end

local function StartAnimations(generation)
    local victim = NPC.victimPed
    local playerPed = PlayerPedId()
    local config = GetAnimationConfig()

    if config.Enabled ~= true then return end
    if not victim or victim == 0 or not DoesEntityExist(victim) then return end
    if not playerPed or playerPed == 0 then return end

    if not RequestControl(victim, 1500) then
        Cancel('npc_control_failed')
        return
    end

    local vampireDict = tostring(config.VampireDictionary or config.Dictionary or '')
    local humanDict = tostring(config.HumanDictionary or config.Dictionary or '')
    local vampireAnim = tostring(config.Vampire or '')
    local humanAnim = tostring(config.Human or '')

    if not LoadAnimDict(vampireDict) or not LoadAnimDict(humanDict) then
        Cancel('animation_dictionary')
        return
    end

    if NPC.active ~= true or generation ~= NPC.generation then return end

    local attach = config.Attach or {}

    -------------------------------------------------------------------------
    -- NPC ALIGNMENT
    --
    -- Ambient NPC'ler yürüyüş, oturma, sigara içme, scenario vb. task'larda
    -- olabiliyor. Sadece TaskTurnPedToFaceEntity kullanıldığında bu task'lar
    -- animasyona blend olup paired animasyonu birkaç frame yanlış pozisyonda
    -- başlatabiliyor. Önce eski task'ı tamamen kesip NPC'yi paired animasyonun
    -- gerçek attachment noktasına snap ediyoruz.
    -------------------------------------------------------------------------

    if IsEntityAttached(victim) then
        DetachEntity(victim, true, true)
    end

    ClearPedTasksImmediately(victim)
    ClearPedSecondaryTask(victim)
    SetBlockingOfNonTemporaryEvents(victim, true)
    SetPedCanRagdoll(victim, false)
    SetEntityVelocity(victim, 0.0, 0.0, 0.0)

    -- Oyuncu da yürüyüş/sprint blend'inden kalmışsa ilk frame kaymasın.
    ClearPedSecondaryTask(playerPed)
    SetEntityVelocity(playerPed, 0.0, 0.0, 0.0)

    if attach.Enabled == true and string.upper(tostring(attach.Role or 'HUMAN')) == 'HUMAN' then
        local offsetX = tonumber(attach.X) or -0.35
        local offsetY = tonumber(attach.Y) or 0.0
        local offsetZ = tonumber(attach.Z) or 0.0
        local rotZ = tonumber(attach.RotZ) or 0.0

        -- Attachment'ın kullanacağı dünya konumunu önceden uygula. Bu özellikle
        -- oturan veya hareket halindeki NPC'nin önce eski scenario pozunda bir
        -- frame görünmesini ve sonra yana kaymasını engeller.
        local snapCoords = GetOffsetFromEntityInWorldCoords(
            playerPed,
            offsetX,
            offsetY,
            offsetZ
        )

        SetEntityCoordsNoOffset(
            victim,
            snapCoords.x,
            snapCoords.y,
            snapCoords.z,
            false,
            false,
            false
        )

        SetEntityHeading(
            victim,
            GetEntityHeading(playerPed) + rotZ
        )

        Wait(50)

        if NPC.active ~= true or generation ~= NPC.generation then return end

        AttachEntityToEntity(
            victim,
            playerPed,
            tonumber(attach.Bone) or 0,
            offsetX,
            offsetY,
            offsetZ,
            tonumber(attach.RotX) or 0.0,
            tonumber(attach.RotY) or 0.0,
            rotZ,
            false,
            false,
            false,
            false,
            2,
            true
        )

        -- Attachment'ın fizik/streaming tarafında oturması için tek kısa frame.
        Wait(50)
    else
        -- Attachment kapalıysa eski davranışı koruyoruz.
        TaskTurnPedToFaceEntity(victim, playerPed, 250)
        TaskTurnPedToFaceEntity(playerPed, victim, 250)
        Wait(250)
    end

    if NPC.active ~= true or generation ~= NPC.generation then return end

    TaskPlayAnim(
        playerPed,
        vampireDict,
        vampireAnim,
        8.0,
        -8.0,
        -1,
        tonumber(config.Flag) or 1,
        0.0,
        false,
        false,
        false
    )

    TaskPlayAnim(
        victim,
        humanDict,
        humanAnim,
        8.0,
        -8.0,
        -1,
        tonumber(config.Flag) or 1,
        0.0,
        false,
        false,
        false
    )
end

local function StartInterruptMonitor(generation)
    local config = GetInterruptConfig()
    if config.Enabled ~= true then return end

    local interval = math.max(tonumber(config.ClientCheckInterval) or 100, 50)
    local playerPed = PlayerPedId()

    NPC.startHealth = GetEntityHealth(playerPed)
    NPC.startArmor = GetPedArmour(playerPed)
    NPC.lastCoords = GetEntityCoords(playerPed)

    while NPC.active == true and generation == NPC.generation do
        Wait(interval)

        if NPC.active ~= true or generation ~= NPC.generation then break end

        playerPed = PlayerPedId()
        local victim = NPC.victimPed

        if not playerPed or playerPed == 0 or IsEntityDead(playerPed) then
            Cancel('death')
            break
        end

        if not victim or victim == 0 or not DoesEntityExist(victim) or IsEntityDead(victim) then
            Cancel('npc_unavailable')
            break
        end

        if config.CancelInVehicle == true and IsPedInAnyVehicle(playerPed, false) then
            Cancel('vehicle')
            break
        end

        if config.CancelOnRagdoll == true and IsPedRagdoll(playerPed) then
            Cancel('ragdoll')
            break
        end

        if config.CancelOnDamage == true then
            local health = GetEntityHealth(playerPed)
            local armor = GetPedArmour(playerPed)

            if health < (NPC.startHealth or health) or armor < (NPC.startArmor or armor) then
                Cancel('damage')
                break
            end

            NPC.startHealth = health
            NPC.startArmor = armor
        end

        local currentCoords = GetEntityCoords(playerPed)
        local victimCoords = GetEntityCoords(victim)
        local maxDistance = tonumber(config.MaxDistance) or 3.5

        if Distance(currentCoords, victimCoords) > maxDistance then
            Cancel('distance')
            break
        end

        if NPC.lastCoords then
            local teleportDistance = tonumber(config.TeleportDistance) or 5.0
            if Distance(currentCoords, NPC.lastCoords) > teleportDistance then
                Cancel('teleport')
                break
            end
        end

        NPC.lastCoords = currentCoords
    end
end

local function DisableControls()
    DisableControlAction(0, 30, true)
    DisableControlAction(0, 31, true)
    DisableControlAction(0, 21, true)
    DisableControlAction(0, 22, true)
    DisableControlAction(0, 24, true)
    DisableControlAction(0, 25, true)
    DisableControlAction(0, 37, true)
    DisableControlAction(0, 44, true)
end

CreateThread(function()
    while true do
        if NPC.active == true and GetAnimationConfig().DisableControls == true then
            DisableControls()
            Wait(0)
        else
            Wait(250)
        end
    end
end)

RegisterNetEvent('lb-vampire:client:npcFeedingStarted', function(data)
    data = data or {}

    ClearVisuals()
    ResetState()

    local victim = GetNetworkPed(data.netId, 2500)
    if not victim or not IsValidNPC(victim) then
        TriggerServerEvent('lb-vampire:server:cancelNPCFeeding', 'npc_stream_failed')
        return
    end

    NPC.generation = NPC.generation + 1
    local generation = NPC.generation

    NPC.active = true
    NPC.token = data.token
    NPC.netId = tonumber(data.netId)
    NPC.victimPed = victim
    NPC.interruptSent = false

    CreateThread(function()
        StartAnimations(generation)
    end)

    CreateThread(function()
        StartInterruptMonitor(generation)
    end)
end)

RegisterNetEvent('lb-vampire:client:npcFeedingStopped', function()
    ClearVisuals()
    ResetState()
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    ClearVisuals()
    ResetState()
end)

exports('CanFeedNPC', function(entity, distance)
    return NPC.CanFeed(entity, distance)
end)

exports('FeedNPC', function(entity)
    return NPC.Request(entity)
end)
