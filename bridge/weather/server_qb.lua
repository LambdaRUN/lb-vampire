LBVampire = LBVampire or {}

LBVampire.Weather =
    LBVampire.Weather or {}


local Weather =
    LBVampire.Weather


---------------------------------------------------------
-- RESOURCE
---------------------------------------------------------

local RESOURCE_NAME =
    'qb-weathersync'


---------------------------------------------------------
-- AVAILABLE
---------------------------------------------------------

function Weather.IsAvailable()

    return GetResourceState(
        RESOURCE_NAME
    ) == 'started'
end


---------------------------------------------------------
-- GET TIME
---------------------------------------------------------

function Weather.GetTime()

    if not Weather.IsAvailable() then

        return nil,
            nil
    end


    -----------------------------------------------------
    -- Güncel qb-weathersync:
    --
    -- exports['qb-weathersync']:getTime()
    -- -> hour, minute
    -----------------------------------------------------

    local success,
        hour,
        minute =
        pcall(
            function()

                return exports[
                    RESOURCE_NAME
                ]:getTime()
            end
        )


    if not success then

        if Config.Debug then

            print(
                '^3[LB-VAMPIRE]^7 Weather server bridge: getTime export unavailable.'
            )
        end


        return nil,
            nil
    end


    -----------------------------------------------------
    -- Bazı custom forklar table döndürürse de
    -- tolere ediyoruz.
    -----------------------------------------------------

    if type(hour) ==
        'table' then


        local data =
            hour


        minute =
            data.minute
            or data.min


        hour =
            data.hour
            or data.hours
    end


    hour =
        tonumber(
            hour
        )


    minute =
        tonumber(
            minute
        )
        or 0


    if not hour
        or hour < 0
        or hour > 23 then


        return nil,
            nil
    end


    return math.floor(
        hour
    ),
    math.floor(
        minute
    )
end


---------------------------------------------------------
-- GET HOUR
---------------------------------------------------------

function Weather.GetHour()

    local hour =
        Weather.GetTime()


    return hour
end