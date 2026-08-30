LBVampire = LBVampire or {}
LBVampire.Framework = LBVampire.Framework or {}

local QBCore = exports['qb-core']:GetCoreObject()

function LBVampire.Framework.GetPlayer(source)
    source = tonumber(source)

    if not source then
        return nil
    end

    return QBCore.Functions.GetPlayer(source)
end

function LBVampire.Framework.GetCitizenId(source)
    local Player = LBVampire.Framework.GetPlayer(source)

    if not Player or not Player.PlayerData then
        return nil
    end

    return Player.PlayerData.citizenid
end

function LBVampire.Framework.GetBloodType(source)
    local Player = LBVampire.Framework.GetPlayer(source)

    if not Player
        or not Player.PlayerData
        or not Player.PlayerData.metadata then
        return nil
    end

    return Player.PlayerData.metadata.bloodtype
end

function LBVampire.Framework.GetPlayerName(
    source
)
    local Player =
        QBCore.Functions.GetPlayer(
            source
        )


    if not Player
        or not Player.PlayerData then

        return GetPlayerName(
            source
        )
    end


    local charinfo =
        Player.PlayerData.charinfo
        or {}


    local firstName =
        tostring(
            charinfo.firstname
            or ''
        )


    local lastName =
        tostring(
            charinfo.lastname
            or ''
        )


    local fullName =
        (
            firstName
            .. ' '
            .. lastName
        ):gsub(
            '^%s*(.-)%s*$',
            '%1'
        )


    if fullName ~= '' then
        return fullName
    end


    return GetPlayerName(
        source
    )
end

function LBVampire.Framework.RegisterCommand(
    name,
    help,
    arguments,
    argsRequired,
    callback,
    permission
)
    QBCore.Commands.Add(
        name,
        help,
        arguments or {},
        argsRequired or false,
        callback,
        permission or 'user'
    )
end

AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    if not Player
        or not Player.PlayerData
        or not Player.PlayerData.source then
        return
    end

    TriggerEvent(
        'lb-vampire:server:frameworkPlayerLoaded',
        Player.PlayerData.source
    )
end)

AddEventHandler('QBCore:Server:OnPlayerUnload', function(source)
    TriggerEvent(
        'lb-vampire:server:frameworkPlayerUnloaded',
        tonumber(source)
    )
end)