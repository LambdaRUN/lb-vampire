LBVampire = LBVampire or {}
LBVampire.Damage = LBVampire.Damage or {}

local Damage = LBVampire.Damage

local VALID_TYPES = {
    BULLET = true,
    MELEE = true,
    FALL = true,
    VEHICLE = true,
    EXPLOSION = true,
    FIRE = true,
    DROWNING = true,
    SUNLIGHT = true,
    UNKNOWN = true
}

local LETHAL_RECONCILE_TYPES = {
    FALL = true,
    VEHICLE = true,
    EXPLOSION = true,
    FIRE = true,
    DROWNING = true
}


local function GetConfig()
    return Config.VampireDamage or {}
end

local function NormalizeHash(value)
    value = tonumber(value)
    if not value then return nil end
    if value < 0 then value = value + 4294967296 end
    return math.floor(value)
end

local function NormalizeType(value)
    value = string.upper(tostring(value or 'UNKNOWN'))
    if not VALID_TYPES[value] then return 'UNKNOWN' end
    return value
end

local function Clamp(value, minimum, maximum)
    value = tonumber(value) or minimum
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

local function GetMultiplier(damageType, attackerSource, weaponHash)
    local config = GetConfig()
    local types = config.Types or {}
    damageType = NormalizeType(damageType)

    if damageType == 'BULLET' then
        local variant = nil
        if attackerSource and LBVampire.Ammo and LBVampire.Ammo.GetDamageVariant then
            variant = LBVampire.Ammo.GetDamageVariant(attackerSource, weaponHash)
        end

        if variant then
            local profile = (config.AmmoVariants or {})[variant]
            if profile then
                return math.max(tonumber(profile.VampireMultiplier) or 1.0, 0), variant
            end
        end

        return math.max(tonumber((types.BULLET or {}).NormalMultiplier) or 0.25, 0), 'normal'
    end

    return math.max(tonumber((types[damageType] or types.UNKNOWN or {}).Multiplier) or 1.0, 0), nil
end

local function ApplyBlood(source, remainingBlood)
    local current = LBVampire.Blood.Get(source)
    if current == nil then return false end
    if math.abs(current - remainingBlood) < 0.001 then return true end

    local success = LBVampire.Blood.Set(source, remainingBlood, false)
    return success == true
end

function Damage.Route(source, payload)
    source = tonumber(source)
    payload = payload or {}
    if not source or GetConfig().Enabled ~= true then return false, 'disabled' end

    local state = LBVampire.Vampires.GetState(source)
    if not state then return false, 'not_vampire' end

    local rawMaximum = tonumber(GetConfig().MaxObservedDamagePerEvent) or 250.0
    local rawDamage = Clamp(payload.rawDamage, 0, rawMaximum)
    if rawDamage <= 0 then return false, 'no_damage' end

    local damageType = NormalizeType(payload.damageType)
    local attackerSource = tonumber(payload.attackerSource)
    if attackerSource and (attackerSource <= 0 or not GetPlayerName(attackerSource)) then
        attackerSource = nil
    end

    local weaponHash = NormalizeHash(payload.weaponHash)
    local multiplier, ammoVariant = GetMultiplier(damageType, attackerSource, weaponHash)

    local armorBefore = Clamp(payload.armorBefore, 0, 100)
    local effectiveBefore = Clamp(payload.effectiveHealthBefore, 0, 500)
    local bloodBefore = tonumber(state.blood) or 0

    -- Automatic fire can submit a second hit before the first result reaches
    -- the owning client. Reuse the previous routed armor/HP for a short,
    -- contiguous sequence so burst damage cannot repeatedly consume the same
    -- armor snapshot.
    local sequence = tonumber(payload.sequence)
    local runtime = state.damageRuntime
    local nowMs = GetGameTimer()
    if runtime and sequence and runtime.lastSequence
        and sequence == runtime.lastSequence + 1
        and nowMs - (runtime.lastAt or 0) <= 1500 then
        armorBefore = tonumber(runtime.armor) or armorBefore
        effectiveBefore = tonumber(runtime.effectiveHealth) or effectiveBefore
    end

    local result = LBVampire.DamageMath.Calculate(
        rawDamage,
        armorBefore,
        bloodBefore,
        effectiveBefore,
        multiplier
    )

    if not ApplyBlood(source, result.remainingBlood) then
        return false, 'blood_update_failed'
    end

    local torporStage = LBVampire.Torpor and LBVampire.Torpor.GetStage(source) or 0
    local kill = false
    local effectiveAfter = result.remainingHealth

    if result.remainingBlood <= 0 and result.remainingHealth <= 0 then
        -- Blood depletion is still the Torpor origin marker, but there is no
        -- custom LB downed stage anymore. Lethal overflow goes straight to
        -- native/QB death while Torpor stage remains persisted for revive.
        if Config.Torpor and Config.Torpor.Enabled == true
            and LBVampire.Torpor and LBVampire.Torpor.EnterActive
            and torporStage == 0 then
            LBVampire.Torpor.EnterActive(source, 'damage_lethal_overflow')
        end

        torporStage = LBVampire.Torpor and LBVampire.Torpor.GetStage(source) or torporStage
        kill = true
        effectiveAfter = 0
    else
        torporStage = LBVampire.Torpor and LBVampire.Torpor.GetStage(source) or torporStage
    end

    state.damageRuntime = {
        lastSequence = sequence,
        lastAt = nowMs,
        armor = math.max(math.floor(result.remainingArmor + 0.5), 0),
        effectiveHealth = math.max(math.floor(effectiveAfter + 0.5), 0)
    }

    local response = {
        sequence = sequence,
        damageType = damageType,
        ammoVariant = ammoVariant,
        rawDamage = result.rawDamage,
        multiplier = result.multiplier,
        finalDamage = result.finalDamage,
        armorDamage = result.armorDamage,
        bloodDamage = result.bloodDamage,
        healthDamage = result.healthDamage,
        armor = math.max(math.floor(result.remainingArmor + 0.5), 0),
        blood = result.remainingBlood,
        effectiveHealth = math.max(math.floor(effectiveAfter + 0.5), 0),
        torporStage = torporStage,
        kill = kill
    }

    TriggerClientEvent('lb-vampire:client:damage:result', source, response)

    if GetConfig().Debug == true then
        print(('^5[LB-VAMPIRE]^7 Damage | %s | %s raw=%.2f x%.2f final=%.2f armor=%.2f blood=%.2f hp=%.2f ammo=%s'):format(
            tostring(state.citizenId), damageType, result.rawDamage, result.multiplier,
            result.finalDamage, result.armorDamage, result.bloodDamage, result.healthDamage,
            tostring(ammoVariant or '-')
        ))
    end

    return true, response
end

RegisterNetEvent('lb-vampire:server:damage:reconcileLethal', function(payload)
    local src = tonumber(source)
    if not src or GetConfig().Enabled ~= true then return end

    local state = LBVampire.Vampires.GetState(src)
    if not state then return end

    local damageType = NormalizeType(payload and payload.damageType)
    -- Player combat (BULLET/MELEE) is authoritative through Damage.Route.
    -- Reconciliation is only the last-resort guard for environmental native
    -- lethals that can bypass the client observer in a single frame.
    if LETHAL_RECONCILE_TYPES[damageType] ~= true then return end

    local stage = LBVampire.Torpor and LBVampire.Torpor.GetStage
        and LBVampire.Torpor.GetStage(src) or tonumber(state.torporStage) or 0
    if stage ~= 0 then return end

    local currentBlood = tonumber(LBVampire.Blood.Get(src)) or tonumber(state.blood) or 0
    if currentBlood <= 0 then return end

    local success = LBVampire.Blood.Set(src, 0, false)
    if success ~= true then return end

    if GetConfig().Debug == true then
        print(('^5[LB-VAMPIRE]^7 Lethal reconciliation | %s | %s | Blood %.2f -> 0'):format(
            tostring(state.citizenId), damageType, currentBlood
        ))
    end
end)

-- PVP weapon hits are intentionally NOT canceled here. Cancelling
-- weaponDamageEvent after the shooter's client has already predicted the hit
-- can leave only the shooter seeing the victim dead/ragdolled. The victim
-- client observes accepted native damage via entityDamaged, immediately
-- restores the snapshot, and routes the authoritative result through LB.

RegisterNetEvent('lb-vampire:server:damage:route', function(payload)
    local src = tonumber(source)
    local success = Damage.Route(src, payload)
    if not success and src then
        TriggerClientEvent('lb-vampire:client:damage:reject', src, {
            sequence = payload and payload.sequence or nil
        })
    end
end)

exports('RouteVampireDamage', function(source, payload)
    return Damage.Route(source, payload)
end)
