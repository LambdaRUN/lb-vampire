LBVampire = LBVampire or {}

LBVampire.DispatchProviders =
    LBVampire.DispatchProviders or {}


local Provider = {}


---------------------------------------------------------
-- QBCORE
---------------------------------------------------------

local QBCore =
    exports['qb-core']:GetCoreObject()


---------------------------------------------------------
-- CONFIG
---------------------------------------------------------

local function GetConfig()

    return Config.Dispatch
        and Config.Dispatch.QB
        or {}
end


---------------------------------------------------------
-- IS AVAILABLE
---------------------------------------------------------

function Provider.IsAvailable()

    local config =
        GetConfig()


    local policeResource =
        tostring(
            config.PoliceResource
            or 'qb-policejob'
        )


    return GetResourceState(
        policeResource
    ) == 'started'
end


---------------------------------------------------------
-- SEND
---------------------------------------------------------

function Provider.Send(
    data
)
    data =
        data or {}


    local coords =
        data.coords


    if not coords then

        return false,
            'missing_coords'
    end


    local config =
        GetConfig()


    local policeResource =
        tostring(
            config.PoliceResource
            or 'qb-policejob'
        )


    local phoneResource =
        tostring(
            config.PhoneResource
            or 'qb-phone'
        )


    -----------------------------------------------------
    -- MESSAGE
    -----------------------------------------------------

    local title =
        tostring(
            data.title
            or 'Yeni İhbar'
        )


    local description =
        tostring(
            data.description
            or 'Şüpheli bir olay bildirildi.'
        )


    local alertCoords = {

        x =
            tonumber(coords.x)
            or 0.0,

        y =
            tonumber(coords.y)
            or 0.0,

        z =
            tonumber(coords.z)
            or 0.0
    }


    -----------------------------------------------------
    -- PLAYERS
    -----------------------------------------------------

    local players =
        QBCore.Functions.GetQBPlayers()


    local sent =
        0


    for _,
        player in pairs(
            players
        ) do


        if player
            and player.PlayerData
            and player.PlayerData.job then


            local job =
                player.PlayerData.job


            -------------------------------------------------
            -- Stock QBCore:
            -- job.type == 'leo'
            -------------------------------------------------

            if job.type == 'leo'
                and job.onduty == true then


                local policeSource =
                    tonumber(
                        player.PlayerData.source
                    )


                if policeSource then


                    -----------------------------------------
                    -- QB PHONE
                    -----------------------------------------

                    if GetResourceState(
                        phoneResource
                    ) == 'started' then


                        TriggerClientEvent(
                            'qb-phone:client:addPoliceAlert',

                            policeSource,

                            {
                                title =
                                    title,

                                coords =
                                    alertCoords,

                                description =
                                    description
                            }
                        )
                    end


                    -----------------------------------------
                    -- QB POLICEJOB
                    -----------------------------------------

                    if GetResourceState(
                        policeResource
                    ) == 'started' then


                        TriggerClientEvent(
                            'police:client:policeAlert',

                            policeSource,

                            alertCoords,

                            description
                        )
                    end


                    sent =
                        sent + 1
                end
            end
        end
    end


    if Config.Debug then

        print(
            (
                '^2[LB-VAMPIRE]^7 QB dispatch sent | Officers: %s | %s'
            ):format(

                tostring(sent),

                description
            )
        )
    end


    return true,
        {
            provider =
                'qb',

            recipients =
                sent
        }
end


---------------------------------------------------------
-- REGISTER PROVIDER
---------------------------------------------------------

LBVampire.DispatchProviders.QB =
    Provider