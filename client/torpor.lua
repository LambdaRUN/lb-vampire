LBVampire = LBVampire or {}
LBVampire.ClientState = LBVampire.ClientState or {}
LBVampire.TorporClient = LBVampire.TorporClient or {}

local Torpor = LBVampire.TorporClient
local QBCore = exports['qb-core']:GetCoreObject()

local STAGE_NORMAL = 0
local STAGE_ACTIVE = 1
local STAGE_PARTIAL = 2

LBVampire.ClientState.torporStage = tonumber(LBVampire.ClientState.torporStage) or STAGE_NORMAL

Torpor.stage = STAGE_NORMAL
Torpor.kinCalls = 0
Torpor.maxKinCalls = 1
Torpor.recoveryBlood = 15
Torpor.lastEffectStage = -1
Torpor.lastUISend = 0
Torpor.nextDrainAt = nil

local function GetConfig()
    return Config.Torpor or {}
end

local function GetActiveConfig()
    return GetConfig().Active or {}
end

local function GetBaseHealth()
    return tonumber(Config.VampireDamage and Config.VampireDamage.BaseHealth) or 100
end

local function GetEffectiveHealth(ped)
    ped = ped or PlayerPedId()
    if not ped or ped == 0 then return 0 end
    return math.max((tonumber(GetEntityHealth(ped)) or GetBaseHealth()) - GetBaseHealth(), 0)
end

local function LoadClipset(name)
    if not name or name == '' then return false end
    RequestAnimSet(name)
    local timeout = GetGameTimer() + 3000
    while not HasAnimSetLoaded(name) and GetGameTimer() < timeout do
        Wait(10)
    end
    return HasAnimSetLoaded(name)
end

local function SetTorporEffect(stage)
    local effect = GetConfig().ScreenEffect or {}
    if Torpor.lastEffectStage == stage then return end
    Torpor.lastEffectStage = stage

    ClearTimecycleModifier()
    if stage <= STAGE_NORMAL or effect.Enabled ~= true then return end

    SetTimecycleModifier(tostring(effect.Timecycle or 'NG_filmic04'))
    SetTimecycleModifierStrength(
        stage == STAGE_ACTIVE
            and (tonumber(effect.ActiveStrength) or 0.18)
            or (tonumber(effect.PartialStrength) or 0.12)
    )
end

local function ResetMovement()
    local ped = PlayerPedId()
    if ped and ped ~= 0 then
        ResetPedMovementClipset(ped, 0.25)
    end
end

local function GetSecondsRemaining()
    if Torpor.stage ~= STAGE_ACTIVE then return 0 end

    local ped = PlayerPedId()
    local active = GetActiveConfig()
    local untilNext = nil
    if Torpor.nextDrainAt then
        untilNext = math.max(Torpor.nextDrainAt - GetGameTimer(), 0)
    end

    return LBVampire.TorporMath.GetScheduledSecondsRemaining(
        GetEffectiveHealth(ped),
        tonumber(active.FullHealthDuration) or (5 * 60),
        tonumber(active.ReferenceHealth) or 100,
        untilNext
    )
end

local function GetDrainIntervalMs()
    local active = GetActiveConfig()
    return LBVampire.TorporMath.GetDrainIntervalMs(
        tonumber(active.FullHealthDuration) or (5 * 60),
        tonumber(active.ReferenceHealth) or 100
    )
end

local function SendUI(force)
    local now = GetGameTimer()
    if force ~= true and now - (Torpor.lastUISend or 0) < 200 then return end
    Torpor.lastUISend = now

    SendNUIMessage({
        action = 'torpor:update',
        stage = Torpor.stage,
        remaining = math.max(math.ceil(GetSecondsRemaining()), 0),
        recoveryBlood = Torpor.recoveryBlood,
        kinAvailable = Torpor.stage > STAGE_NORMAL and Torpor.kinCalls < Torpor.maxKinCalls
    })
end

local function ApplyStage(stage)
    stage = math.max(STAGE_NORMAL, math.min(math.floor(tonumber(stage) or STAGE_NORMAL), STAGE_PARTIAL))
    local previous = Torpor.stage
    Torpor.stage = stage
    LBVampire.ClientState.torporStage = stage

    if stage == STAGE_NORMAL then
        Torpor.nextDrainAt = nil
        ResetMovement()
        SetTorporEffect(STAGE_NORMAL)
    else
        if previous ~= stage then
            ResetMovement()
            SetTorporEffect(stage)
        end

        if stage == STAGE_ACTIVE and previous ~= STAGE_ACTIVE then
            Torpor.nextDrainAt = GetGameTimer() + GetDrainIntervalMs()
        elseif stage == STAGE_PARTIAL then
            Torpor.nextDrainAt = nil
        end
    end

    if stage > STAGE_NORMAL and LBVampire.AbilityMenu and LBVampire.AbilityMenu.open then
        TriggerEvent('lb-vampire:client:abilityMenu:forceClose')
    end

    SendUI(true)
end

RegisterNetEvent('lb-vampire:client:torporSync', function(data)
    data = data or {}
    Torpor.kinCalls = tonumber(data.kinCalls) or 0
    Torpor.maxKinCalls = tonumber(data.maxKinCalls) or 1
    Torpor.recoveryBlood = tonumber(data.recoveryBlood) or tonumber(GetConfig().RecoveryBlood) or 15
    ApplyStage(data.stage)
end)

RegisterNetEvent('lb-vampire:client:torpor:directHealthDamage', function(amount)
    if LBVampire.ClientState.isVampire ~= true then return end

    local ped = PlayerPedId()
    if not ped or ped == 0 or IsEntityDead(ped) then return end

    amount = math.max(tonumber(amount) or 0, 0)
    if amount <= 0 then return end

    local effective = GetEffectiveHealth(ped)
    local nextEffective = math.max(effective - amount, 0)
    if nextEffective <= 0 then
        if LBVampire.DamageClient and LBVampire.DamageClient.RequestDeathHandoff then
            LBVampire.DamageClient.RequestDeathHandoff('torpor_direct_health')
        else
            ApplyDamageToPed(ped, 1000, true)
        end
        SendNUIMessage({ action = 'torpor:hide' })
    else
        SetEntityHealth(ped, GetBaseHealth() + math.floor(nextEffective + 0.5))
    end
end)

RegisterNetEvent('lb-vampire:client:torpor:kinSignal', function(data)
    data = data or {}
    local coords = data.coords
    if type(coords) ~= 'table' then return end

    local radius = math.max(tonumber(data.radius) or 90.0, 20.0)
    local duration = math.max(math.floor(tonumber(data.duration) or 75000), 5000)
    local blip = AddBlipForRadius(
        tonumber(coords.x) or 0.0,
        tonumber(coords.y) or 0.0,
        tonumber(coords.z) or 0.0,
        radius
    )

    SetBlipColour(blip, tonumber(data.colour) or 1)
    SetBlipAlpha(blip, math.max(20, math.min(tonumber(data.alpha) or 105, 255)))
    SetBlipAsShortRange(blip, false)

    CreateThread(function()
        Wait(duration)
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end)
end)

RegisterNetEvent('lb-vampire:client:abilityMenu:forceClose', function()
    -- ability_menu.lua owns the actual focus release; this event is listened there too.
end)

local function IsQBDeathState()
    local playerData = QBCore.Functions.GetPlayerData()
    local metadata = playerData and playerData.metadata or {}
    return metadata.isdead == true or metadata.inlaststand == true or IsEntityDead(PlayerPedId())
end

local function ApplyRestrictions(ped)
    local stateConfig = Torpor.stage == STAGE_PARTIAL
        and (GetConfig().Partial or {})
        or GetActiveConfig()
    local clipset = tostring(stateConfig.MovementClipset or 'move_m@injured')

    if not HasAnimSetLoaded(clipset) then LoadClipset(clipset) end
    if HasAnimSetLoaded(clipset) then SetPedMovementClipset(ped, clipset, 0.45) end

    SetCurrentPedWeapon(ped, GetHashKey('WEAPON_UNARMED'), true)
    DisablePlayerFiring(PlayerId(), true)
    DisableControlAction(0, 21, true) -- sprint
    DisableControlAction(0, 22, true) -- jump
    DisableControlAction(0, 24, true) -- attack
    DisableControlAction(0, 25, true) -- aim
    DisableControlAction(0, 37, true) -- weapon wheel
    DisableControlAction(0, 45, true) -- reload
    DisableControlAction(0, 140, true) -- melee light
    DisableControlAction(0, 141, true) -- melee heavy
    DisableControlAction(0, 142, true) -- melee alternate
    DisableControlAction(0, 143, true) -- melee block

    if IsPedInAnyVehicle(ped, false) then
        local vehicle = GetVehiclePedIsIn(ped, false)
        if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped then
            TaskLeaveVehicle(ped, vehicle, 16)
        end
    end

    local kinConfig = GetConfig().KinCall or {}
    if kinConfig.Enabled == true and IsControlJustPressed(0, tonumber(kinConfig.Key) or 74) then
        TriggerServerEvent('lb-vampire:server:torpor:kinCall')
    end
end

RegisterNetEvent('lb-vampire:client:deathBridge:revived', function()
    if Torpor.stage <= STAGE_NORMAL then return end

    -- qb-ambulancejob's Laststand itself resurrects the native ped to 150 HP.
    -- That transition is NOT an EMS revive. Partial Torpor is entered only from
    -- the real hospital:client:Revive event forwarded by the death bridge.
    ApplyStage(STAGE_PARTIAL)
    TriggerServerEvent('lb-vampire:server:torpor:revivedFromTorpor')
end)

CreateThread(function()
    while true do
        if Torpor.stage > STAGE_NORMAL then
            local ped = PlayerPedId()
            local qbDead = IsQBDeathState()

            if qbDead then
                -- While qb-ambulancejob owns Laststand/Death, LB-Torpor must not
                -- impose movement restrictions, drain or its own UI on top.
                ResetMovement()
                ClearTimecycleModifier()
                Torpor.lastEffectStage = -1
                SendNUIMessage({ action = 'torpor:hide' })
                Wait(250)
            else
                if ped and ped ~= 0 then
                    ApplyRestrictions(ped)
                end

                SendUI()
                Wait(0)
            end
        else
            Wait(300)
        end
    end
end)

CreateThread(function()
    while true do
        if Torpor.stage == STAGE_ACTIVE and not IsQBDeathState() then
            local now = GetGameTimer()
            Torpor.nextDrainAt = Torpor.nextDrainAt or (now + GetDrainIntervalMs())

            if now >= Torpor.nextDrainAt then
                local ped = PlayerPedId()
                if ped and ped ~= 0 and not IsEntityDead(ped) then
                    local effective = GetEffectiveHealth(ped)
                    if effective <= 1 then
                        if LBVampire.DamageClient and LBVampire.DamageClient.RequestDeathHandoff then
                            LBVampire.DamageClient.RequestDeathHandoff('torpor_hp_drain')
                        else
                            ApplyDamageToPed(ped, 1000, true)
                        end
                        Torpor.nextDrainAt = nil
                        SendNUIMessage({ action = 'torpor:hide' })
                    else
                        SetEntityHealth(ped, GetBaseHealth() + effective - 1)
                        Torpor.nextDrainAt = now + GetDrainIntervalMs()
                    end
                end
            end

            Wait(50)
        else
            Torpor.nextDrainAt = nil
            Wait(250)
        end
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    CreateThread(function()
        Wait(1200)
        TriggerServerEvent('lb-vampire:server:torpor:requestSync')
    end)
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    ApplyStage(STAGE_NORMAL)
    SendNUIMessage({ action = 'torpor:hide' })
end)

CreateThread(function()
    Wait(1800)
    TriggerServerEvent('lb-vampire:server:torpor:requestSync')
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    ResetMovement()
    ClearTimecycleModifier()
end)

exports('GetTorporStage', function()
    return Torpor.stage
end)
