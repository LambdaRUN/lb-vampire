LBVampire = LBVampire or {}
LBVampire.AmmoClient = LBVampire.AmmoClient or {}

local AmmoClient = LBVampire.AmmoClient

local GROUPS = {
    [GetHashKey('GROUP_PISTOL')] = 'PISTOL',
    [GetHashKey('GROUP_SMG')] = 'SMG',
    [GetHashKey('GROUP_RIFLE')] = 'RIFLE',
    [GetHashKey('GROUP_MG')] = 'MG',
    [GetHashKey('GROUP_SHOTGUN')] = 'SHOTGUN',
    [GetHashKey('GROUP_SNIPER')] = 'SNIPER'
}

local function NormalizeHash(value)
    value = tonumber(value)
    if not value then return nil end
    if value < 0 then value = value + 4294967296 end
    return math.floor(value)
end

local function GetWeaponGroupName(weaponHash)
    local group = GetWeapontypeGroup(weaponHash)
    return GROUPS[group]
end

RegisterNetEvent('lb-vampire:client:ammo:beginLoad', function(data)
    local ped = PlayerPedId()
    if not ped or ped == 0 then return end

    local weaponHash = GetSelectedPedWeapon(ped)
    if not weaponHash or weaponHash == GetHashKey('WEAPON_UNARMED') then
        TriggerEvent('QBCore:Notify', 'Önce bir silah kuşanmalısın.', 'error', 4000)
        return
    end

    local group = GetWeaponGroupName(weaponHash)
    if not group then
        TriggerEvent('QBCore:Notify', 'Bu silah Deadblood mühimmatını kullanamaz.', 'error', 4000)
        return
    end

    TriggerServerEvent('lb-vampire:server:ammo:loadDeadblood', {
        itemSlot = data and data.itemSlot or nil,
        weaponHash = NormalizeHash(weaponHash),
        currentAmmo = GetAmmoInPedWeapon(ped, weaponHash),
        group = group
    })
end)

RegisterNetEvent('lb-vampire:client:ammo:apply', function(data)
    data = data or {}
    local ped = PlayerPedId()
    local current = GetSelectedPedWeapon(ped)
    if NormalizeHash(current) ~= NormalizeHash(data.weaponHash) then return end

    SetPedAmmo(ped, current, math.max(math.floor(tonumber(data.totalAmmo) or 0), 0))
end)

CreateThread(function()
    local lastWeapon = nil
    local lastAmmo = nil

    while true do
        local ped = PlayerPedId()
        if ped and ped ~= 0 and not IsEntityDead(ped) then
            local weaponHash = GetSelectedPedWeapon(ped)

            if weaponHash and weaponHash ~= GetHashKey('WEAPON_UNARMED') then
                local currentAmmo = GetAmmoInPedWeapon(ped, weaponHash)
                local normalized = NormalizeHash(weaponHash)

                if lastWeapon == normalized and lastAmmo and currentAmmo < lastAmmo then
                    TriggerServerEvent('lb-vampire:server:ammo:shotFired', {
                        weaponHash = normalized,
                        currentAmmo = currentAmmo
                    })
                end

                lastWeapon = normalized
                lastAmmo = currentAmmo
                Wait(0)
            else
                lastWeapon = nil
                lastAmmo = nil
                Wait(150)
            end
        else
            lastWeapon = nil
            lastAmmo = nil
            Wait(250)
        end
    end
end)
