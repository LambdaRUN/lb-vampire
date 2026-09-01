LBVampire = LBVampire or {}
LBVampire.Ammo = LBVampire.Ammo or {}

local Ammo = LBVampire.Ammo
local QBCore = exports['qb-core']:GetCoreObject()

Ammo.LastShot = Ammo.LastShot or {}

local function GetConfig()
    return Config.DeadBloodAmmo or {}
end

local function GetDeadbloodLabel()
    return tostring(GetConfig().Label or 'Ölü Adamın Kanından Mermi')
end

local function NormalizeHash(value)
    value = tonumber(value)
    if not value then return nil end
    if value < 0 then value = value + 4294967296 end
    return math.floor(value)
end

local function HashName(name)
    if type(joaat) == 'function' then
        return NormalizeHash(joaat(name))
    end
    if type(GetHashKey) == 'function' then
        return NormalizeHash(GetHashKey(name))
    end
    return nil
end

local function GetPlayer(source)
    return QBCore.Functions.GetPlayer(tonumber(source))
end

local function FindWeaponItem(source, weaponHash)
    local Player = GetPlayer(source)
    if not Player or not Player.PlayerData then return nil, nil end

    weaponHash = NormalizeHash(weaponHash)
    for slot, item in pairs(Player.PlayerData.items or {}) do
        if item and item.type == 'weapon' and HashName(item.name) == weaponHash then
            return item, tonumber(item.slot) or tonumber(slot)
        end
    end

    return nil, nil
end

local function SetWeaponInfo(source, item, slot, info)
    if GetResourceState('qb-inventory') ~= 'started' then return false end

    local ok, result = pcall(function()
        return exports['qb-inventory']:SetItemData(source, item.name, 'info', info, slot)
    end)

    return ok and result ~= false
end

local function MigrateLegacyAmmoInfo(info)
    info = type(info) == 'table' and info or {}
    local changed = false

    local legacy = info.lbAmmo
    local legacyType = nil
    if type(legacy) == 'table' then
        legacyType = tostring(legacy.type or '')
    elseif type(legacy) == 'string' then
        legacyType = legacy
    end

    if legacy ~= nil then
        if legacyType == 'deadblood' then
            info['Mermi Türü'] = GetDeadbloodLabel()
        end
        info.lbAmmo = nil
        changed = true
    end

    local ammo = math.max(math.floor(tonumber(info.ammo) or 0), 0)
    if ammo <= 0 and info['Mermi Türü'] ~= nil then
        info['Mermi Türü'] = nil
        changed = true
    end

    return info, changed
end

local function ResolveAmmoVariant(info)
    local changed
    info, changed = MigrateLegacyAmmoInfo(info)
    local ammo = math.max(math.floor(tonumber(info.ammo) or 0), 0)
    if ammo <= 0 then return nil, info, changed end

    local display = tostring(info['Mermi Türü'] or '')
    if display == GetDeadbloodLabel()
        or display == 'Ölü Adamın Kanından Mermi'
        or string.lower(display) == 'deadblood' then
        return 'deadblood', info, changed
    end

    return nil, info, changed
end

local function MigratePlayerWeapons(source)
    local Player = GetPlayer(source)
    if not Player or not Player.PlayerData then return end

    for slot, item in pairs(Player.PlayerData.items or {}) do
        if item and item.type == 'weapon' then
            local info, changed = MigrateLegacyAmmoInfo(item.info)
            if changed then
                SetWeaponInfo(source, item, tonumber(item.slot) or tonumber(slot), info)
            end
        end
    end
end

local function RemoveAmmoItem(source, slot)
    local config = GetConfig()
    if GetResourceState('qb-inventory') ~= 'started' then return false end

    local ok, result = pcall(function()
        return exports['qb-inventory']:RemoveItem(
            source,
            tostring(config.ItemName or 'ammo_deadblood'),
            1,
            tonumber(slot),
            'lb-vampire deadblood load'
        )
    end)

    return ok and result == true
end

local function Notify(source, message, notifyType)
    TriggerClientEvent('QBCore:Notify', source, message, notifyType or 'primary', 4500)
end

local function RegisterItem()
    local config = GetConfig()
    if config.Enabled ~= true then return end

    local itemName = tostring(config.ItemName or 'ammo_deadblood')
    if not QBCore.Shared.Items[itemName] then
        local itemDefinition = {
            name = itemName,
            label = tostring(config.Label or 'Ölü Adamın Kanından Mermi'),
            weight = math.max(math.floor(tonumber(config.Weight) or 250), 0),
            type = 'item',
            image = tostring(config.Image or 'pistol_ammo.png'),
            unique = false,
            useable = true,
            shouldClose = true,
            combinable = nil,
            description = tostring(config.Description or 'Vampir dokusuna karşı hazırlanmış özel mühimmat.')
        }

        local ok, added, reason = pcall(function()
            return exports['qb-core']:AddItem(itemName, itemDefinition)
        end)

        if not ok or added == false then
            print(('^3[LB-VAMPIRE]^7 Dynamic item registration failed for %s | %s'):format(
                itemName, tostring(reason or added)
            ))
        end
    end

    QBCore.Functions.CreateUseableItem(itemName, function(source, item)
        TriggerClientEvent('lb-vampire:client:ammo:beginLoad', source, {
            itemSlot = item and item.slot or nil
        })
    end)
end

CreateThread(function()
    Wait(500)
    RegisterItem()
end)

RegisterNetEvent('lb-vampire:server:ammo:loadDeadblood', function(payload)
    local src = tonumber(source)
    payload = payload or {}
    local config = GetConfig()
    if not src or config.Enabled ~= true then return end

    local group = string.upper(tostring(payload.group or ''))
    if not (config.AllowedGroups or {})[group] then
        Notify(src, 'Bu silah Deadblood mühimmatını kullanamaz.', 'error')
        return
    end

    local weaponHash = NormalizeHash(payload.weaponHash)
    local currentAmmo = math.max(math.floor(tonumber(payload.currentAmmo) or 0), 0)
    local item, weaponSlot = FindWeaponItem(src, weaponHash)
    if not item or not weaponSlot then
        Notify(src, 'Aktif silah envanterde doğrulanamadı.', 'error')
        return
    end

    local variant, info, migrated = ResolveAmmoVariant(item.info)
    if migrated then SetWeaponInfo(src, item, weaponSlot, info) end

    if currentAmmo > 0 and variant ~= 'deadblood' then
        Notify(src, 'Deadblood yüklemek için normal mühimmatın tamamen bitmiş olmalı.', 'error')
        return
    end

    if variant and variant ~= 'deadblood' then
        Notify(src, 'Silahın içinde farklı bir özel mühimmat var.', 'error')
        return
    end

    local maximum = math.max(math.floor(tonumber(config.MaxRounds) or 60), 1)
    if currentAmmo >= maximum then
        Notify(src, 'Silahın Deadblood mühimmatı zaten dolu.', 'error')
        return
    end

    local ammoItemSlot = tonumber(payload.itemSlot)
    if not ammoItemSlot or not RemoveAmmoItem(src, ammoItemSlot) then
        Notify(src, 'Deadblood mühimmatı envanterden alınamadı.', 'error')
        return
    end

    local add = math.max(math.floor(tonumber(config.RoundsPerItem) or 12), 1)
    maximum = math.max(maximum, add)
    local newAmmo = math.min(currentAmmo + add, maximum)

    info.ammo = newAmmo
    info['Mermi Türü'] = GetDeadbloodLabel()
    info.lbAmmo = nil

    if not SetWeaponInfo(src, item, weaponSlot, info) then
        pcall(function()
            exports['qb-inventory']:AddItem(src, tostring(config.ItemName or 'ammo_deadblood'), 1, ammoItemSlot, {}, 'lb-vampire deadblood rollback')
        end)
        Notify(src, 'Silah metadata güncellenemedi.', 'error')
        return
    end

    TriggerClientEvent('lb-vampire:client:ammo:apply', src, {
        weaponHash = weaponHash,
        totalAmmo = newAmmo,
        variant = 'deadblood'
    })

    Notify(src, ('Deadblood mühimmatı yüklendi: %d'):format(newAmmo), 'success')
end)

RegisterNetEvent('lb-vampire:server:ammo:shotFired', function(payload)
    local src = tonumber(source)
    payload = payload or {}
    if not src then return end

    local weaponHash = NormalizeHash(payload.weaponHash)
    local actualAmmo = math.max(math.floor(tonumber(payload.currentAmmo) or 0), 0)
    local item, slot = FindWeaponItem(src, weaponHash)
    if not item or not slot then return end

    local variant, info = ResolveAmmoVariant(item.info)
    if variant ~= 'deadblood' then return end

    Ammo.LastShot[src] = {
        weaponHash = weaponHash,
        variant = 'deadblood',
        expiresAt = GetGameTimer() + 1200
    }

    info.ammo = actualAmmo
    if actualAmmo <= 0 then
        info['Mermi Türü'] = nil
    else
        info['Mermi Türü'] = GetDeadbloodLabel()
    end
    info.lbAmmo = nil

    SetWeaponInfo(src, item, slot, info)
end)

function Ammo.GetDamageVariant(source, weaponHash)
    source = tonumber(source)
    if not source then return nil end

    weaponHash = NormalizeHash(weaponHash)
    local recent = Ammo.LastShot[source]
    if recent and recent.expiresAt >= GetGameTimer() and recent.weaponHash == weaponHash then
        return recent.variant
    end

    local item, slot = FindWeaponItem(source, weaponHash)
    if not item then return nil end

    local variant, info, migrated = ResolveAmmoVariant(item.info)
    if migrated and slot then SetWeaponInfo(source, item, slot, info) end
    if variant == 'deadblood' then return 'deadblood' end
    return nil
end

exports('GetAmmoVariant', function(source, weaponHash)
    return Ammo.GetDamageVariant(source, weaponHash)
end)


CreateThread(function()
    Wait(1500)
    for _, playerId in ipairs(GetPlayers()) do
        MigratePlayerWeapons(tonumber(playerId))
    end
end)

AddEventHandler('lb-vampire:server:frameworkPlayerLoaded', function(source)
    CreateThread(function()
        Wait(750)
        MigratePlayerWeapons(tonumber(source))
    end)
end)

AddEventHandler('playerDropped', function()
    Ammo.LastShot[tonumber(source)] = nil
end)
