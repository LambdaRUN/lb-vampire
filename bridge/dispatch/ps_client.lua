LBVampire = LBVampire or {}


---------------------------------------------------------
-- CONFIG
---------------------------------------------------------

local function GetConfig()

    return Config.Dispatch
        and Config.Dispatch.PS
        or {}
end


---------------------------------------------------------
-- RESOURCE
---------------------------------------------------------

local function GetResourceName()

    return tostring(
        GetConfig().Resource
        or 'ps-dispatch'
    )
end


---------------------------------------------------------
-- STREET
---------------------------------------------------------

local function GetStreetLabel(
    coords
)
    if not coords then

        return 'Bilinmeyen Bölge'
    end


    local streetHash,
        crossingHash =
        GetStreetNameAtCoord(

            coords.x,
            coords.y,
            coords.z
        )


    local street =
        ''


    local crossing =
        ''


    if streetHash
        and streetHash ~= 0 then


        street =
            GetStreetNameFromHashKey(
                streetHash
            )
            or ''
    end


    if crossingHash
        and crossingHash ~= 0 then


        crossing =
            GetStreetNameFromHashKey(
                crossingHash
            )
            or ''
    end


    -----------------------------------------------------
    -- STREET + CROSSING
    -----------------------------------------------------

    if street ~= ''
        and crossing ~= '' then


        return (
            '%s / %s'
        ):format(
            street,
            crossing
        )
    end


    -----------------------------------------------------
    -- STREET ONLY
    -----------------------------------------------------

    if street ~= '' then

        return street
    end


    return 'Bilinmeyen Bölge'
end


---------------------------------------------------------
-- PS DISPATCH RELAY
---------------------------------------------------------

RegisterNetEvent(
    'lb-vampire:client:psDispatchRelay',

    function(
        data
    )
        data =
            data or {}


        -------------------------------------------------
        -- RESOURCE
        -------------------------------------------------

        local resourceName =
            GetResourceName()


        if GetResourceState(
            resourceName
        ) ~= 'started' then


            if Config.Debug then

                print(
                    '^1[LB-VAMPIRE]^7 PS relay failed: ps-dispatch not started.'
                )
            end


            return
        end


        -------------------------------------------------
        -- COORDS
        -------------------------------------------------

        local rawCoords =
            data.coords


        if not rawCoords then


            if Config.Debug then

                print(
                    '^1[LB-VAMPIRE]^7 PS relay failed: missing coords.'
                )
            end


            return
        end


        local coords =
            vector3(

                tonumber(
                    rawCoords.x
                )
                or 0.0,

                tonumber(
                    rawCoords.y
                )
                or 0.0,

                tonumber(
                    rawCoords.z
                )
                or 0.0
            )


        data.coords =
            coords


        -------------------------------------------------
        -- STREET
        -------------------------------------------------

        if not data.street
            or data.street == ''
            or data.street ==
                'Bilinmeyen Bölge' then


            data.street =
                GetStreetLabel(
                    coords
                )
        end


        -------------------------------------------------
        -- OFFICIAL PS-DISPATCH FLOW
        --
        -- Client -> TriggerServerEvent
        -------------------------------------------------

        TriggerServerEvent(
            'ps-dispatch:server:notify',
            data
        )


        -------------------------------------------------
        -- DEBUG ACK
        -------------------------------------------------

        if Config.Debug then


            print(
                (
                    '^2[LB-VAMPIRE]^7 PS dispatch relayed | CodeName: %s | Code: %s'
                ):format(

                    tostring(
                        data.codeName
                    ),

                    tostring(
                        data.code
                    )
                )
            )


            TriggerServerEvent(
                'lb-vampire:server:psDispatchRelayComplete',
                data.codeName
            )
        end
    end
)