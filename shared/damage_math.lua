LBVampire = LBVampire or {}
LBVampire.DamageMath = LBVampire.DamageMath or {}

local DamageMath = LBVampire.DamageMath

local function NonNegative(value)
    value = tonumber(value) or 0
    if value < 0 then return 0 end
    return value
end

function DamageMath.Calculate(rawDamage, armor, blood, effectiveHealth, multiplier)
    rawDamage = NonNegative(rawDamage)
    armor = NonNegative(armor)
    blood = NonNegative(blood)
    effectiveHealth = NonNegative(effectiveHealth)
    multiplier = NonNegative(multiplier == nil and 1.0 or multiplier)

    local finalDamage = rawDamage * multiplier
    local remainingDamage = finalDamage

    local armorDamage = math.min(armor, remainingDamage)
    remainingDamage = remainingDamage - armorDamage

    local bloodDamage = math.min(blood, remainingDamage)
    remainingDamage = remainingDamage - bloodDamage

    local healthDamage = math.min(effectiveHealth, remainingDamage)

    local remainingArmor = math.max(armor - armorDamage, 0)
    local remainingBlood = math.max(blood - bloodDamage, 0)
    local remainingHealth = math.max(effectiveHealth - healthDamage, 0)

    return {
        rawDamage = rawDamage,
        multiplier = multiplier,
        finalDamage = finalDamage,
        armorDamage = armorDamage,
        bloodDamage = bloodDamage,
        healthDamage = healthDamage,
        overflowDamage = math.max(remainingDamage - healthDamage, 0),
        remainingArmor = remainingArmor,
        remainingBlood = remainingBlood,
        remainingHealth = remainingHealth,
        bloodDepleted = blood > 0 and remainingBlood <= 0,
        lethal = finalDamage > 0 and remainingHealth <= 0 and healthDamage > 0
    }
end
