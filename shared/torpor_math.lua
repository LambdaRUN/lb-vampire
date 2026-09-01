LBVampire = LBVampire or {}
LBVampire.TorporMath = LBVampire.TorporMath or {}

local TorporMath = LBVampire.TorporMath

local function Positive(value, fallback)
    value = tonumber(value)
    if not value or value <= 0 then return fallback end
    return value
end

function TorporMath.GetDrainRate(fullHealthDuration, referenceHealth)
    local duration = Positive(fullHealthDuration, 300.0)
    local reference = Positive(referenceHealth, 100.0)
    return reference / duration
end

function TorporMath.GetSecondsRemaining(effectiveHealth, fullHealthDuration, referenceHealth)
    local health = math.max(tonumber(effectiveHealth) or 0, 0)
    if health <= 0 then return 0 end

    local rate = TorporMath.GetDrainRate(fullHealthDuration, referenceHealth)
    if rate <= 0 then return 0 end
    return health / rate
end

function TorporMath.GetDrainIntervalMs(fullHealthDuration, referenceHealth)
    local rate = TorporMath.GetDrainRate(fullHealthDuration, referenceHealth)
    if rate <= 0 then return 1000 end
    return math.max(math.floor((1000.0 / rate) + 0.5), 50)
end

function TorporMath.GetScheduledSecondsRemaining(effectiveHealth, fullHealthDuration, referenceHealth, millisecondsUntilNextDrain)
    local health = math.max(tonumber(effectiveHealth) or 0, 0)
    if health <= 0 then return 0 end

    local intervalMs = TorporMath.GetDrainIntervalMs(fullHealthDuration, referenceHealth)
    local untilNextMs = tonumber(millisecondsUntilNextDrain)
    if untilNextMs == nil then
        untilNextMs = intervalMs
    else
        untilNextMs = math.max(math.min(untilNextMs, intervalMs), 0)
    end

    return (untilNextMs / 1000.0) + (math.max(health - 1, 0) * intervalMs / 1000.0)
end
