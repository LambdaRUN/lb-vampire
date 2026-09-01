LBVampire = LBVampire or {}
LBVampire.Abilities = LBVampire.Abilities or {}

local Abilities = LBVampire.Abilities
Abilities.StatusProviders = Abilities.StatusProviders or {}

local function NormalizeId(id)
    id = tostring(id or '')
    if id == '' then return nil end
    return id
end

function Abilities.RegisterStatusProvider(id, provider)
    id = NormalizeId(id)
    if not id or type(provider) ~= 'function' then return false end

    Abilities.StatusProviders[id] = provider
    return true
end

function Abilities.GetStatusProvider(id)
    id = NormalizeId(id)
    if not id then return nil end
    return Abilities.StatusProviders[id]
end

local function SafeStatus(src, id)
    local provider = Abilities.GetStatusProvider(id)
    if not provider then
        return {
            available = false,
            locked = true,
            reason = 'Mühürlü',
            cooldownRemaining = 0,
            cooldownDuration = 0
        }
    end

    local ok, status = pcall(provider, src)
    if not ok or type(status) ~= 'table' then
        if Config.Debug then
            print(('^1[LB-VAMPIRE]^7 Ability status provider failed | %s | %s'):format(
                tostring(id), tostring(status)
            ))
        end

        return {
            available = false,
            locked = true,
            reason = 'Durum okunamadı',
            cooldownRemaining = 0,
            cooldownDuration = 0
        }
    end

    status.available = status.available == true
    status.locked = status.locked == true
    status.cooldownRemaining = math.max(tonumber(status.cooldownRemaining) or 0, 0)
    status.cooldownDuration = math.max(tonumber(status.cooldownDuration) or 0, 0)
    status.bloodCost = tonumber(status.bloodCost)
    status.blood = tonumber(status.blood)
    status.maxBlood = tonumber(status.maxBlood)

    return status
end

RegisterNetEvent('lb-vampire:server:abilityMenu:requestStates', function(requestId, ids)
    local src = tonumber(source)
    requestId = tostring(requestId or '')

    if not src or src <= 0 or requestId == '' or type(ids) ~= 'table' then return end

    local states = {}
    local seen = {}
    local count = 0

    for _, rawId in ipairs(ids) do
        if count >= 16 then break end
        local id = NormalizeId(rawId)
        if id and not seen[id] then
            seen[id] = true
            count = count + 1
            states[id] = SafeStatus(src, id)
        end
    end

    TriggerClientEvent('lb-vampire:client:abilityMenu:states', src, {
        requestId = requestId,
        serverTime = os.time(),
        states = states
    })
end)

exports('RegisterAbilityStatusProvider', function(id, provider)
    return Abilities.RegisterStatusProvider(id, provider)
end)
