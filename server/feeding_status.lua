LBVampire = LBVampire or {}

LBVampire.FeedingStatus =
    LBVampire.FeedingStatus or {}


---------------------------------------------------------
-- CONFIG
---------------------------------------------------------

local function GetConfig()
    return Config.Feeding
        and Config.Feeding.StatusUI
        or {}
end


---------------------------------------------------------
-- ONLINE
---------------------------------------------------------

local function IsPlayerOnline(
    source
)
    source =
        tonumber(source)


    if not source then
        return false
    end


    return GetPlayerName(
        source
    ) ~= nil
end


---------------------------------------------------------
-- THRESHOLDS
---------------------------------------------------------

local function GetThresholds()
    local hudConfig =
        Config.HumanBlood
        and Config.HumanBlood.HUD
        or {}


    local thresholds =
        hudConfig.Thresholds
        or {}


    return {
        low =
            tonumber(
                thresholds.Low
            )
            or 70,

        critical =
            tonumber(
                thresholds.Critical
            )
            or 40,

        severe =
            tonumber(
                thresholds.Severe
            )
            or 20
    }
end


---------------------------------------------------------
-- UPDATE LOOP
---------------------------------------------------------

CreateThread(function()

    while true do

        local config =
            GetConfig()


        local interval =
            math.max(
                tonumber(
                    config.UpdateInterval
                )
                or 250,
                100
            )


        Wait(
            interval
        )


        if config.Enabled == true
            and LBVampire.Runtime
            and LBVampire.Runtime.FeedingSessions
            and LBVampire.HumanBlood
            and LBVampire.HumanBlood.Get then


            local thresholds =
                GetThresholds()


            for token,
                session in pairs(
                    LBVampire.Runtime.FeedingSessions
                ) do


                if session
                    and session.state == 'FEEDING'
                    and IsPlayerOnline(
                        session.requesterSource
                    )
                    and IsPlayerOnline(
                        session.targetSource
                    ) then


                    local humanBlood =
                        LBVampire.HumanBlood.Get(
                            session.targetSource
                        )


                    if humanBlood ~= nil then

                        TriggerClientEvent(
                            'lb-vampire:client:feedingStatusUpdate',

                            session.requesterSource,

                            {
                                token =
                                    token,

                                blood =
                                    humanBlood,

                                maxBlood =
                                    tonumber(
                                        Config.HumanBlood.Max
                                    )
                                    or 100,

                                lowThreshold =
                                    thresholds.low,

                                criticalThreshold =
                                    thresholds.critical,

                                severeThreshold =
                                    thresholds.severe
                            }
                        )
                    end
                end
            end
        end
    end
end)