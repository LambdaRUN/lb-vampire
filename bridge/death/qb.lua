LBVampire = LBVampire or {}
LBVampire.DeathBridge = LBVampire.DeathBridge or {}

local DeathBridge = LBVampire.DeathBridge
local QBCore = exports['qb-core']:GetCoreObject()

DeathBridge.reviveGeneration = tonumber(DeathBridge.reviveGeneration) or 0
DeathBridge.deathGeneration = tonumber(DeathBridge.deathGeneration) or 0

local LASTSTAND_FALLBACK_AFTER_MS = 2500
local LASTSTAND_FALLBACK_TIMEOUT_MS = 5000
local REVIVE_WATCHDOG_DELAY_MS = 900

local function ResourceStarted(name)
    return GetResourceState(name) == 'started'
end

local function GetQBMetadata()
    local data = QBCore.Functions.GetPlayerData()
    return data and data.metadata or {}
end

local function IsQBDowned()
    local metadata = GetQBMetadata()
    return metadata.isdead == true or metadata.inlaststand == true
end

local function RestoreLivingPedState(ped)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return false end

    local wasDead = IsEntityDead(ped) or IsPedDeadOrDying(ped, true)
    local wasRagdoll = IsPedRagdoll(ped)

    if wasDead then
        local coords = GetEntityCoords(ped)
        local heading = GetEntityHeading(ped)
        NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z + 0.05, heading, true, false)
        ped = PlayerPedId()
        if not ped or ped == 0 or not DoesEntityExist(ped) then return false end
        SetEntityMaxHealth(ped, 200)
        SetEntityHealth(ped, 200)
    end

    -- The successful qb-ambulancejob revive may intentionally leave a bed
    -- animation. Only clear tasks when the orphan state was actually dead or
    -- still ragdolled after QB had time to finish its own revive handler.
    if wasDead or wasRagdoll or IsPedRagdoll(ped) then
        ClearPedTasksImmediately(ped)
    else
        ClearPedSecondaryTask(ped)
    end

    SetEntityInvincible(ped, false)
    FreezeEntityPosition(ped, false)
    SetPedCanRagdoll(ped, true)
    SetPlayerControl(PlayerId(), true, 0)
    SetPlayerSprint(PlayerId(), true)
    ResetPedMovementClipset(ped, 0.0)
    ResetPedStrafeClipset(ped)
    ResetPedWeaponMovementClipset(ped)
    ClearPedBloodDamage(ped)

    return true
end

local function TriggerQBLaststandFallback(generation)
    CreateThread(function()
        local startedAt = GetGameTimer()
        local fallbackAt = startedAt + LASTSTAND_FALLBACK_AFTER_MS
        local expiresAt = startedAt + LASTSTAND_FALLBACK_TIMEOUT_MS

        while generation == DeathBridge.deathGeneration and GetGameTimer() < expiresAt do
            Wait(50)

            if IsQBDowned() then return end

            local ped = PlayerPedId()
            if not ped or ped == 0 or not DoesEntityExist(ped) then return end

            -- SetLaststand(true) resurrects the native ped before setting the
            -- server metadata. If that already happened, do not fire a second
            -- damage event while QB's first Laststand thread is still running.
            if not IsEntityDead(ped) and not IsPedDeadOrDying(ped, true) then
                return
            end

            if GetGameTimer() >= fallbackAt then
                -- Stock qb-ambulancejob listens for this exact local game event
                -- and then owns SetLaststand(true). This is only a delayed safety
                -- net for script-kill cases where SetEntityHealth(0) produced no
                -- CEventNetworkEntityDamage on this client.
                local eventData = {
                    ped,
                    ped,
                    0,
                    true,
                    0,
                    0,
                    GetHashKey('WEAPON_UNARMED')
                }
                TriggerEvent('gameEventTriggered', 'CEventNetworkEntityDamage', eventData)
                return
            end
        end
    end)
end

function DeathBridge.RequestDeath(reason)
    local ped = PlayerPedId()
    if not ped or ped == 0 or not DoesEntityExist(ped) then return false end
    if IsQBDowned() then return true end

    DeathBridge.deathGeneration = DeathBridge.deathGeneration + 1
    local generation = DeathBridge.deathGeneration

    -- Use qb-ambulancejob's own public kill event. Its normal native death
    -- event feeds client/dead.lua and starts Laststand. A delayed fallback above
    -- covers the rare script-kill case where that game event is not emitted.
    if ResourceStarted('qb-ambulancejob') then
        TriggerEvent('hospital:client:KillPlayer')
        TriggerQBLaststandFallback(generation)
    else
        SetEntityHealth(ped, 0)
    end

    return true
end

RegisterNetEvent('hospital:client:Revive', function()
    DeathBridge.reviveGeneration = DeathBridge.reviveGeneration + 1
    DeathBridge.deathGeneration = DeathBridge.deathGeneration + 1
    local generation = DeathBridge.reviveGeneration

    CreateThread(function()
        -- qb-ambulancejob runs its own handler for this same event. Give it time
        -- to clear InLaststand/isDead and resurrect the ped first.
        Wait(REVIVE_WATCHDOG_DELAY_MS)
        if generation ~= DeathBridge.reviveGeneration then return end

        local ped = PlayerPedId()
        if not ped or ped == 0 or not DoesEntityExist(ped) then return end

        RestoreLivingPedState(ped)
        TriggerEvent('lb-vampire:client:deathBridge:revived')
    end)
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    DeathBridge.deathGeneration = DeathBridge.deathGeneration + 1
    DeathBridge.reviveGeneration = DeathBridge.reviveGeneration + 1
end)

exports('RequestVampireDeath', function(reason)
    return DeathBridge.RequestDeath(reason)
end)
