LBVampire = LBVampire or {}

LBVampire.HumanBloodConsequencesClient =
    LBVampire.HumanBloodConsequencesClient
    or {}


---------------------------------------------------------
-- QBCORE
---------------------------------------------------------

local function GetQBCore()
    if GetResourceState(
        'qb-core'
    ) ~= 'started' then

        return nil
    end


    return exports[
        'qb-core'
    ]:GetCoreObject()
end


---------------------------------------------------------
-- CURRENT CITIZEN
---------------------------------------------------------

local function GetCurrentCitizenId()
    local QBCore =
        GetQBCore()


    if not QBCore
        or not QBCore.Functions then

        return nil
    end


    local PlayerData =
        QBCore.Functions
            .GetPlayerData()


    return PlayerData
        and PlayerData.citizenid
        or nil
end


---------------------------------------------------------
-- NOTIFY
---------------------------------------------------------

local function Notify(
    message
)
    TriggerEvent(
        'QBCore:Notify',

        message,

        'error',

        7000
    )
end


---------------------------------------------------------
-- WAIT SPAWN
---------------------------------------------------------

local function WaitForSpawnReady()
    local timeout =
        GetGameTimer()
        +
        20000


    while GetGameTimer() <
        timeout do


        if LBVampire.Spawn
            and LBVampire.Spawn.IsReady
            and LBVampire.Spawn.IsReady() then


            return true
        end


        Wait(
            100
        )
    end


    return false
end


---------------------------------------------------------
-- ZERO BLOOD
---------------------------------------------------------

RegisterNetEvent(
    'lb-vampire:client:humanBloodZero',
    function(data)

        data =
            data or {}


        CreateThread(function()

            -------------------------------------------------
            -- Spawn / multicharacter içinde ped öldürülmez.
            -------------------------------------------------

            if not WaitForSpawnReady() then

                if Config.Debug then

                    print(
                        '^1[LB-VAMPIRE]^7 Zero Blood cancelled: spawn not ready.'
                    )
                end


                return
            end


            -------------------------------------------------
            -- Event başka karakterden kaldıysa uygulama.
            -------------------------------------------------

            local currentCitizenId =
                GetCurrentCitizenId()


            if data.citizenId
                and currentCitizenId
                and tostring(
                    data.citizenId
                ) ~= tostring(
                    currentCitizenId
                ) then


                if Config.Debug then

                    print(
                        '^3[LB-VAMPIRE]^7 Zero Blood ignored: citizen mismatch.'
                    )
                end


                return
            end


            local ped =
                PlayerPedId()


            if not ped
                or ped == 0
                or not DoesEntityExist(
                    ped
                ) then

                return
            end


            Notify(
                tostring(
                    data.notification
                    or
                    'Aşırı kan kaybı nedeniyle bilincini kaybettin.'
                )
            )


            -------------------------------------------------
            -- Normal GTA health sistemini kullanıyoruz.
            --
            -- qb-ambulancejob / kullanılan death system
            -- bundan sonrasını devralır.
            -------------------------------------------------

            if data.setHealthToZero ==
                true then


                if GetEntityHealth(
                    ped
                ) > 0 then


                    SetEntityHealth(
                        ped,
                        0
                    )
                end
            end


            if Config.Debug then

                print(
                    '^1[LB-VAMPIRE]^7 Zero Blood consequence executed.'
                )
            end
        end)
    end
)