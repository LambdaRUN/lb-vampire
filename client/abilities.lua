LBVampire = LBVampire or {}
LBVampire.Abilities = LBVampire.Abilities or {}

local Abilities = LBVampire.Abilities
Abilities.ClientProviders = Abilities.ClientProviders or {}

local function NormalizeId(id)
    id = tostring(id or '')
    if id == '' then return nil end
    return id
end

function Abilities.Register(id, provider)
    id = NormalizeId(id)
    if not id or type(provider) ~= 'table' then return false end

    Abilities.ClientProviders[id] = provider
    return true
end

function Abilities.Get(id)
    id = NormalizeId(id)
    if not id then return nil end
    return Abilities.ClientProviders[id]
end

function Abilities.Execute(id)
    if tonumber(LBVampire.ClientState and LBVampire.ClientState.torporStage) and tonumber(LBVampire.ClientState.torporStage) > 0 then
        return false, 'torpor'
    end

    local provider = Abilities.Get(id)
    if not provider or type(provider.execute) ~= 'function' then
        return false, 'missing_client_provider'
    end

    local ok, result, reason = pcall(provider.execute)
    if not ok then
        if Config.Debug then
            print(('^1[LB-VAMPIRE]^7 Ability execute failed | %s | %s'):format(
                tostring(id), tostring(result)
            ))
        end
        return false, 'client_provider_error'
    end

    if result == false then
        return false, reason or 'ability_rejected'
    end

    return true, result
end

function Abilities.BuildMenuEntries()
    local menu = Config.AbilityMenu or {}
    local configured = menu.Abilities or {}
    local entries = {}

    for id, definition in pairs(configured) do
        if type(definition) == 'table' and definition.Enabled ~= false then
            local provider = Abilities.Get(id)
            local metadata = {}

            if provider and type(provider.getMetadata) == 'function' then
                local ok, value = pcall(provider.getMetadata)
                if ok and type(value) == 'table' then
                    metadata = value
                end
            end

            entries[#entries + 1] = {
                id = tostring(id),
                label = tostring(definition.Label or metadata.label or id),
                description = tostring(definition.Description or metadata.description or ''),
                icon = tostring(definition.Icon or metadata.icon or 'sigil'),
                order = tonumber(definition.Order or metadata.order) or 999,
                bloodCost = tonumber(metadata.bloodCost or definition.BloodCost),
                hasProvider = provider ~= nil
            }
        end
    end

    table.sort(entries, function(a, b)
        if a.order == b.order then
            return a.id < b.id
        end
        return a.order < b.order
    end)

    return entries
end

exports('RegisterAbility', function(id, provider)
    return Abilities.Register(id, provider)
end)
