LBVampire = LBVampire or {}
LBVampire.ClientState = LBVampire.ClientState or {}
LBVampire.DamageClient = LBVampire.DamageClient or {}

local Damage = LBVampire.DamageClient

Damage.lastHealth = nil
Damage.lastArmor = nil
Damage.sequence = 0
Damage.applying = false
Damage.exemptions = Damage.exemptions or {}
Damage.pending = Damage.pending or {}
Damage.lastAppliedSequence = tonumber(Damage.lastAppliedSequence) or 0
Damage.criticalHitsSuppressed = false
Damage.criticalGuardPed = nil
Damage.nextCriticalGuardAt = 0
Damage.fallContextUntil = 0
Damage.recentFallback = nil
Damage.lethalReconcileReported = false
Damage.deathHandoffUntil = 0
Damage.deathHandoffReason = nil

local FALL_CONTEXT_MS = 1800
local CRITICAL_GUARD_INTERVAL = 750
local DEATH_HANDOFF_MS = 1600
local FALL_DEDUP_MS = 350

local ENVIRONMENT_WEAPONS = {
    [GetHashKey('WEAPON_FALL')] = 'FALL',
    [GetHashKey('WEAPON_RAMMED_BY_CAR')] = 'VEHICLE',
    [GetHashKey('WEAPON_RUN_OVER_BY_CAR')] = 'VEHICLE',
    [GetHashKey('WEAPON_FIRE')] = 'FIRE',
    [GetHashKey('WEAPON_DROWNING')] = 'DROWNING',
    [GetHashKey('WEAPON_DROWNING_IN_VEHICLE')] = 'DROWNING',
    [GetHashKey('WEAPON_EXPLOSION')] = 'EXPLOSION'
}

local EXPLOSIVES = {
    [GetHashKey('WEAPON_GRENADE')] = true,
    [GetHashKey('WEAPON_RPG')] = true,
    [GetHashKey('WEAPON_HOMINGLAUNCHER')] = true,
    [GetHashKey('WEAPON_GRENADELAUNCHER')] = true,
    [GetHashKey('WEAPON_STICKYBOMB')] = true,
    [GetHashKey('WEAPON_PIPEBOMB')] = true,
    [GetHashKey('WEAPON_PROXMINE')] = true
}

local BULLET_GROUPS = {
    [GetHashKey('GROUP_PISTOL')] = true,
    [GetHashKey('GROUP_SMG')] = true,
    [GetHashKey('GROUP_RIFLE')] = true,
    [GetHashKey('GROUP_MG')] = true,
    [GetHashKey('GROUP_SHOTGUN')] = true,
    [GetHashKey('GROUP_SNIPER')] = true
}

local MELEE_GROUP = GetHashKey('GROUP_MELEE')

local function NormalizeHash(value)
    value = tonumber(value)
    if not value then return 0 end
    if value < 0 then value = value + 4294967296 end
    return math.floor(value)
end

local function GetBaseHealth()
    return tonumber(Config.VampireDamage and Config.VampireDamage.BaseHealth) or 100
end

local function DamageEnabled()
    return Config.VampireDamage and Config.VampireDamage.Enabled == true
end

local function GetFallbackTimeout()
    return math.max(math.floor(tonumber(Config.VampireDamage and Config.VampireDamage.ClientFallbackTimeout) or 2000), 500)
end

local function ClassifyDamage(weaponHash, culprit)
    local env = ENVIRONMENT_WEAPONS[weaponHash]
    if env then return env end
    if EXPLOSIVES[weaponHash] then return 'EXPLOSION' end
    if weaponHash == GetHashKey('WEAPON_UNARMED') then return 'MELEE' end

    if weaponHash and weaponHash ~= 0 then
        local group = GetWeapontypeGroup(weaponHash)
        if group == MELEE_GROUP then return 'MELEE' end
        if BULLET_GROUPS[group] then return 'BULLET' end
    end

    if culprit and culprit ~= 0 and IsEntityAVehicle(culprit) then return 'VEHICLE' end
    return 'UNKNOWN'
end

local function GetAttackerSource(culprit)
    if not culprit or culprit == 0 or not IsEntityAPed(culprit) then return nil end
    local playerIndex = NetworkGetPlayerIndexFromPed(culprit)
    if playerIndex == -1 then return nil end
    return GetPlayerServerId(playerIndex)
end

local function CleanupExemptions()
    local now = GetGameTimer()
    for id, exemption in pairs(Damage.exemptions) do
        if exemption.expiresAt and exemption.expiresAt <= now then
            Damage.exemptions[id] = nil
        end
    end
end

local function IsExempt(damageType)
    CleanupExemptions()
    for _, exemption in pairs(Damage.exemptions) do
        if exemption.types and exemption.types[damageType] == true then return true end
    end
    return false
end

function Damage.SetExemption(id, damageTypes, durationMs)
    id = tostring(id or '')
    if id == '' then return false end

    local types = {}
    if type(damageTypes) == 'string' then
        types[string.upper(damageTypes)] = true
    elseif type(damageTypes) == 'table' then
        for _, value in ipairs(damageTypes) do types[string.upper(tostring(value))] = true end
        for key, value in pairs(damageTypes) do
            if type(key) == 'string' and value == true then types[string.upper(key)] = true end
        end
    end

    Damage.exemptions[id] = {
        types = types,
        expiresAt = durationMs and (GetGameTimer() + math.max(tonumber(durationMs) or 0, 0)) or nil
    }
    return true
end

function Damage.ClearExemption(id)
    Damage.exemptions[tostring(id or '')] = nil
end

local function RestoreSnapshot(ped, health, armor)
    Damage.applying = true
    if tonumber(health) then SetEntityHealth(ped, math.max(math.floor(health + 0.5), 0)) end
    if tonumber(armor) then SetPedArmour(ped, math.max(math.floor(armor + 0.5), 0)) end
    Damage.lastHealth = GetEntityHealth(ped)
    Damage.lastArmor = GetPedArmour(ped)
    Damage.applying = false
end

local function IsDeathHandoffActive()
    return GetGameTimer() <= (tonumber(Damage.deathHandoffUntil) or 0)
end

function Damage.RequestDeathHandoff(reason)
    local ped = PlayerPedId()
    if not ped or ped == 0 or not DoesEntityExist(ped) then return false end
    if IsDeathHandoffActive() then return true end

    Damage.deathHandoffReason = tostring(reason or 'lb_lethal')
    Damage.deathHandoffUntil = GetGameTimer() + DEATH_HANDOFF_MS
    Damage.lethalReconcileReported = true
    Damage.pending = {}

    if LBVampire.DeathBridge and LBVampire.DeathBridge.RequestDeath then
        return LBVampire.DeathBridge.RequestDeath(Damage.deathHandoffReason)
    end

    -- Generic fallback only when the qb-ambulancejob bridge is unavailable.
    SetEntityHealth(ped, 0)
    return true
end

local function UpdateFallContext(ped)
    local now = GetGameTimer()
    if IsPedFalling(ped) or IsPedInParachuteFreeFall(ped) then
        Damage.fallContextUntil = now + FALL_CONTEXT_MS
    end
    return now <= (tonumber(Damage.fallContextUntil) or 0)
end

local function IsRecentFallFallback(damageType, culprit)
    local recent = Damage.recentFallback
    if not recent then return false end

    local age = GetGameTimer() - (tonumber(recent.at) or 0)
    if age < 0 or age > FALL_DEDUP_MS then
        Damage.recentFallback = nil
        return false
    end

    if damageType == 'FALL' or (damageType == 'UNKNOWN' and (not culprit or culprit == 0)) then
        Damage.recentFallback = nil
        return true
    end

    return false
end

local function ReportUnexpectedLethal(ped)
    if IsDeathHandoffActive() then return false end
    if Damage.lethalReconcileReported then return false end
    if (tonumber(LBVampire.ClientState.torporStage) or 0) ~= 0 then return false end
    if (tonumber(LBVampire.ClientState.blood) or 0) <= 0 then return false end
    if not ped or ped == 0 or not DoesEntityExist(ped) then return false end

    local effectiveHealth = math.max(GetEntityHealth(ped) - GetBaseHealth(), 0)
    if not IsEntityDead(ped) and effectiveHealth > 0 then return false end

    Damage.lethalReconcileReported = true

    local cause = GetPedCauseOfDeath(ped)
    local culprit = GetPedSourceOfDeath(ped)
    TriggerServerEvent('lb-vampire:server:damage:reconcileLethal', {
        damageType = ClassifyDamage(cause, culprit),
        weaponHash = NormalizeHash(cause)
    })

    return true
end

local function ApplyNativeFallback(sequence)
    sequence = tonumber(sequence)
    if not sequence then return end

    local pending = Damage.pending[sequence]
    Damage.pending[sequence] = nil
    if not pending or sequence <= (Damage.lastAppliedSequence or 0) then return end

    local ped = PlayerPedId()
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end

    -- If the authoritative router cannot answer, never leave the restored
    -- snapshot as free invulnerability. Reapply the observed native damage
    -- once, against the player's current armor/health state.
    local remaining = math.max(tonumber(pending.rawDamage) or 0, 0)
    local armor = math.max(GetPedArmour(ped), 0)
    local armorDamage = math.min(armor, remaining)
    remaining = remaining - armorDamage

    Damage.applying = true
    SetPedArmour(ped, math.max(math.floor(armor - armorDamage + 0.5), 0))
    if remaining > 0 then
        SetEntityHealth(ped, math.max(math.floor(GetEntityHealth(ped) - remaining + 0.5), 0))
    end
    Damage.lastHealth = GetEntityHealth(ped)
    Damage.lastArmor = GetPedArmour(ped)
    Damage.lastAppliedSequence = sequence
    Damage.applying = false
end

local function RouteObservedDamage(ped, observed, damageType, weapon, culprit, beforeHealth, beforeArmor, sourceTag, attackerSourceOverride, interceptId)
    observed = math.max(tonumber(observed) or 0, 0)
    if observed <= 0 then return false end

    -- Undo native GTA damage first. The authoritative server response is the
    -- only routed result that remains, preventing native + LB double damage.
    RestoreSnapshot(ped, beforeHealth, beforeArmor)

    if IsExempt(damageType) then return true end

    Damage.sequence = Damage.sequence + 1
    local sequence = Damage.sequence

    Damage.pending[sequence] = { rawDamage = observed }

    if sourceTag == 'fall_fallback' then
        Damage.recentFallback = {
            at = GetGameTimer(),
            damageType = 'FALL',
            rawDamage = observed
        }
    end

    TriggerServerEvent('lb-vampire:server:damage:route', {
        sequence = sequence,
        rawDamage = observed,
        damageType = damageType,
        weaponHash = NormalizeHash(weapon),
        attackerSource = tonumber(attackerSourceOverride) or GetAttackerSource(culprit),
        interceptId = interceptId,
        armorBefore = beforeArmor,
        effectiveHealthBefore = math.max(beforeHealth - GetBaseHealth(), 0)
    })

    CreateThread(function()
        Wait(GetFallbackTimeout())
        ApplyNativeFallback(sequence)
    end)

    return true
end

AddEventHandler('entityDamaged', function(victim, culprit, weapon, baseDamage)
    if Damage.applying then return end
    if IsDeathHandoffActive() then
        local ped = PlayerPedId()
        if victim == ped then
            Damage.lastHealth = GetEntityHealth(ped)
            Damage.lastArmor = GetPedArmour(ped)
        end
        return
    end
    if LBVampire.ClientState.isVampire ~= true then return end
    if not Config.VampireDamage or Config.VampireDamage.Enabled ~= true then return end

    local ped = PlayerPedId()
    if victim ~= ped or not DoesEntityExist(ped) then return end

    local currentHealth = GetEntityHealth(ped)
    local currentArmor = GetPedArmour(ped)
    local beforeHealth = tonumber(Damage.lastHealth) or currentHealth
    local beforeArmor = tonumber(Damage.lastArmor) or currentArmor
    local damageType = ClassifyDamage(weapon, culprit)

    if (damageType == 'BULLET' or damageType == 'MELEE')
        and Config.VampireDamage.VictimSideRouting == false then
        Damage.lastHealth = currentHealth
        Damage.lastArmor = currentArmor
        return
    end

    -- The polling fallback can see landing HP loss before entityDamaged is
    -- dispatched. Suppress only that same late fall event, not unrelated hits.
    if IsRecentFallFallback(damageType, culprit) then
        Damage.lastHealth = currentHealth
        Damage.lastArmor = currentArmor
        return
    end

    local healthLoss = math.max(beforeHealth - currentHealth, 0)
    local armorLoss = math.max(beforeArmor - currentArmor, 0)
    local observed = healthLoss + armorLoss
    if observed <= 0 then observed = math.max(tonumber(baseDamage) or 0, 0) end
    if observed <= 0 then return end

    RouteObservedDamage(
        ped, observed, damageType, weapon, culprit,
        beforeHealth, beforeArmor, 'entity_event'
    )
end)

AddEventHandler('lb-vampire:client:deathBridge:revived', function()
    local ped = PlayerPedId()
    Damage.deathHandoffUntil = 0
    Damage.deathHandoffReason = nil
    Damage.pending = {}
    Damage.lethalReconcileReported = false

    if ped and ped ~= 0 and DoesEntityExist(ped) then
        Damage.lastHealth = GetEntityHealth(ped)
        Damage.lastArmor = GetPedArmour(ped)
        if LBVampire.ClientState.isVampire == true then
            SetPedSuffersCriticalHits(ped, false)
            Damage.criticalHitsSuppressed = true
            Damage.criticalGuardPed = ped
            Damage.nextCriticalGuardAt = 0
        end
    end

    TriggerServerEvent('lb-vampire:server:torpor:requestSync')
end)

RegisterNetEvent('lb-vampire:client:damage:reject', function(data)
    data = data or {}
    ApplyNativeFallback(data.sequence)
end)

RegisterNetEvent('lb-vampire:client:damage:result', function(data)
    data = data or {}
    local sequence = tonumber(data.sequence)
    if sequence then
        Damage.pending[sequence] = nil
        if sequence <= (Damage.lastAppliedSequence or 0) then return end
        Damage.lastAppliedSequence = sequence
    end

    local ped = PlayerPedId()
    if not ped or ped == 0 then return end

    Damage.applying = true

    if data.kill == true then
        SetPedArmour(ped, 0)
        Damage.lastHealth = GetEntityHealth(ped)
        Damage.lastArmor = 0
        Damage.applying = false
        Damage.RequestDeathHandoff('routed_lethal')
        return
    else
        SetPedArmour(ped, math.max(math.floor(tonumber(data.armor) or 0), 0))
        local effective = math.max(math.floor(tonumber(data.effectiveHealth) or 0), 0)
        SetEntityHealth(ped, GetBaseHealth() + effective)
    end

    Damage.lastHealth = GetEntityHealth(ped)
    Damage.lastArmor = GetPedArmour(ped)
    Damage.applying = false
end)

CreateThread(function()
    while true do
        if LBVampire.ClientState.isVampire == true and DamageEnabled() then
            local ped = PlayerPedId()
            if ped and ped ~= 0 and not Damage.applying then
                if IsDeathHandoffActive() then
                    Damage.lastHealth = GetEntityHealth(ped)
                    Damage.lastArmor = GetPedArmour(ped)
                    Wait(25)
                    goto continue_damage_loop
                end

                local torporStage = tonumber(LBVampire.ClientState.torporStage) or 0
                local effectiveHealth = math.max(GetEntityHealth(ped) - GetBaseHealth(), 0)

                if torporStage == 0 and effectiveHealth > 0 and not IsEntityDead(ped) then
                    Damage.lethalReconcileReported = false
                elseif torporStage == 0 then
                    ReportUnexpectedLethal(ped)
                end

                local currentHealth = GetEntityHealth(ped)
                local currentArmor = GetPedArmour(ped)
                local beforeHealth = tonumber(Damage.lastHealth)
                local beforeArmor = tonumber(Damage.lastArmor)
                local inFallContext = UpdateFallContext(ped)
                local routedFallback = false

                -- A landing's entityDamaged event is not guaranteed to beat this
                -- polling tick. Inspect the delta before replacing the snapshot.
                -- This fallback is restricted to normal-state fall context so the
                -- Torpor system's intentional internal HP drain is never rerouted.
                if beforeHealth and beforeArmor
                    and (tonumber(LBVampire.ClientState.torporStage) or 0) == 0
                    and inFallContext then
                    local healthLoss = math.max(beforeHealth - currentHealth, 0)
                    local armorLoss = math.max(beforeArmor - currentArmor, 0)
                    local observed = healthLoss + armorLoss

                    if healthLoss > 0 or armorLoss > 0 then
                        routedFallback = RouteObservedDamage(
                            ped, observed, 'FALL', GetHashKey('WEAPON_FALL'), 0,
                            beforeHealth, beforeArmor, 'fall_fallback'
                        )
                    end
                end

                if not routedFallback then
                    Damage.lastHealth = currentHealth
                    Damage.lastArmor = currentArmor
                end

                local now = GetGameTimer()
                if Damage.criticalGuardPed ~= ped or now >= (tonumber(Damage.nextCriticalGuardAt) or 0) then
                    SetPedSuffersCriticalHits(ped, false)
                    Damage.criticalHitsSuppressed = true
                    Damage.criticalGuardPed = ped
                    Damage.nextCriticalGuardAt = now + CRITICAL_GUARD_INTERVAL
                end
            end
            Wait(25)
        else
            if Damage.criticalHitsSuppressed then
                local ped = Damage.criticalGuardPed or PlayerPedId()
                if ped and ped ~= 0 and DoesEntityExist(ped) then SetPedSuffersCriticalHits(ped, true) end
                Damage.criticalHitsSuppressed = false
            end
            Damage.criticalGuardPed = nil
            Damage.nextCriticalGuardAt = 0
            Damage.lastHealth = nil
            Damage.lastArmor = nil
            Damage.pending = {}
            Damage.fallContextUntil = 0
            Damage.recentFallback = nil
            Damage.lethalReconcileReported = false
            Damage.lastAppliedSequence = Damage.sequence
            Wait(400)
        end
        ::continue_damage_loop::
    end
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    local ped = Damage.criticalGuardPed or PlayerPedId()
    if ped and ped ~= 0 and DoesEntityExist(ped) then SetPedSuffersCriticalHits(ped, true) end
end)

exports('SetDamageExemption', function(id, damageTypes, durationMs)
    return Damage.SetExemption(id, damageTypes, durationMs)
end)

exports('ClearDamageExemption', function(id)
    Damage.ClearExemption(id)
end)
