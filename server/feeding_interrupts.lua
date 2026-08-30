LBVampire = LBVampire or {}

LBVampire.FeedingInterrupts =
    LBVampire.FeedingInterrupts or {}


local Interrupts =
    LBVampire.FeedingInterrupts


---------------------------------------------------------
-- MOTION CACHE
---------------------------------------------------------

local Motion =
    {}


---------------------------------------------------------
-- CONFIG
---------------------------------------------------------

local function GetConfig()
    return Config.Feeding
        and Config.Feeding.Interrupts
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
-- PLAYER UNAVAILABLE
---------------------------------------------------------

local function GetUnavailableReason(
    source
)
    local config =
        GetConfig()


    if not LBVampire.Framework
        or not LBVampire.Framework.GetPlayer then

        return nil
    end


    local Player =
        LBVampire.Framework.GetPlayer(
            source
        )


    if not Player
        or not Player.PlayerData then

        return 'player_unavailable'
    end


    local metadata =
        Player.PlayerData.metadata
        or {}


    if config.CancelOnDeath == true
        and metadata.isdead == true then

        return 'death'
    end


    if config.CancelOnLastStand == true
        and metadata.inlaststand == true then

        return 'laststand'
    end


    return nil
end


---------------------------------------------------------
-- COORD DISTANCE
---------------------------------------------------------

local function DistanceBetweenCoords(
    first,
    second
)
    if not first
        or not second then

        return 0.0
    end


    local x =
        first.x -
        second.x

    local y =
        first.y -
        second.y

    local z =
        first.z -
        second.z


    return math.sqrt(
        (x * x)
        +
        (y * y)
        +
        (z * z)
    )
end


---------------------------------------------------------
-- PLAYER COORDS
---------------------------------------------------------

local function GetPlayerCoords(
    source
)
    local ped =
        GetPlayerPed(
            source
        )


    if not ped
        or ped == 0 then

        return nil,
            nil
    end


    return GetEntityCoords(
        ped
    ),
        ped
end


---------------------------------------------------------
-- SERVER VALIDATION
---------------------------------------------------------

local function ValidateSession(
    token,
    session
)
    local config =
        GetConfig()


    if not session
        or session.state ~=
            'FEEDING' then

        return nil
    end


    -----------------------------------------------------
    -- ONLINE
    -----------------------------------------------------

    if not IsPlayerOnline(
        session.requesterSource
    )
        or not IsPlayerOnline(
            session.targetSource
        ) then


        return 'player_disconnected'
    end


    -----------------------------------------------------
    -- DEATH / LASTSTAND
    -----------------------------------------------------

    local requesterUnavailable =
        GetUnavailableReason(
            session.requesterSource
        )


    if requesterUnavailable then
        return requesterUnavailable
    end


    local targetUnavailable =
        GetUnavailableReason(
            session.targetSource
        )


    if targetUnavailable then
        return targetUnavailable
    end


    -----------------------------------------------------
    -- COORDS
    -----------------------------------------------------

    local requesterCoords,
        requesterPed =
        GetPlayerCoords(
            session.requesterSource
        )


    local targetCoords,
        targetPed =
        GetPlayerCoords(
            session.targetSource
        )


    if not requesterCoords
        or not targetCoords then


        return 'ped_missing'
    end


    -----------------------------------------------------
    -- VEHICLE
    -----------------------------------------------------

    if config.CancelInVehicle ==
        true then


        if GetVehiclePedIsIn(
            requesterPed,
            false
        ) ~= 0 then


            return 'vehicle'
        end


        if GetVehiclePedIsIn(
            targetPed,
            false
        ) ~= 0 then


            return 'vehicle'
        end
    end


    -----------------------------------------------------
    -- PLAYER DISTANCE
    -----------------------------------------------------

    local distance =
        DistanceBetweenCoords(
            requesterCoords,
            targetCoords
        )


    local maxDistance =
        tonumber(
            config.MaxDistance
        )
        or 3.5


    if distance >
        maxDistance then


        return 'distance'
    end


    -----------------------------------------------------
    -- TELEPORT DETECTION
    -----------------------------------------------------

    local previous =
        Motion[
            token
        ]


    local teleportDistance =
        tonumber(
            config.TeleportDistance
        )
        or 5.0


    if previous then

        local requesterMoved =
            DistanceBetweenCoords(
                requesterCoords,
                previous.requester
            )


        local targetMoved =
            DistanceBetweenCoords(
                targetCoords,
                previous.target
            )


        if requesterMoved >
            teleportDistance
            or targetMoved >
                teleportDistance then


            return 'teleport'
        end
    end


    Motion[
        token
    ] = {
        requester =
            requesterCoords,

        target =
            targetCoords
    }


    return nil
end


---------------------------------------------------------
-- INTERRUPT
---------------------------------------------------------

local function InterruptSession(
    source,
    reason
)
    source =
        tonumber(source)


    if not source then
        return false
    end


    if not LBVampire.Feeding
        or not LBVampire.Feeding.GetInteraction
        or not LBVampire.Feeding.Cancel then

        return false
    end


    local interaction =
        LBVampire.Feeding.GetInteraction(
            source
        )


    if not interaction
        or interaction.state ~=
            'FEEDING'
        or not interaction.token then


        return false
    end


    local token =
        interaction.token


    local session =
        LBVampire.Runtime
            .FeedingSessions[
                token
            ]


    if not session then
        return false
    end


    -----------------------------------------------------
    -- Only session participants can interrupt.
    -----------------------------------------------------

    if session.requesterSource ~=
        source
        and session.targetSource ~=
            source then


        return false
    end


    local success =
        LBVampire.Feeding.Cancel(
            source,
            reason
        )


    if success then

        Motion[
            token
        ] =
            nil


        if Config.Debug then

            print(
                (
                    '^3[LB-VAMPIRE]^7 Feeding interrupted | Token: %s | Reason: %s'
                ):format(
                    tostring(token),
                    tostring(reason)
                )
            )
        end
    end


    return success
end


---------------------------------------------------------
-- CLIENT INTERRUPT WHITELIST
---------------------------------------------------------

local AllowedClientReasons = {
    damage =
        true,

    ragdoll =
        true,

    death =
        true,

    vehicle =
        true,

    teleport =
        true,

    ped_missing =
        true
}


---------------------------------------------------------
-- CLIENT INTERRUPT EVENT
---------------------------------------------------------

RegisterNetEvent(
    'lb-vampire:server:interruptFeeding',
    function(reason)

        local playerSource =
            tonumber(source)


        reason =
            tostring(
                reason
                or 'client_interrupt'
            )


        -------------------------------------------------
        -- Client arbitrary reason yazamaz.
        -------------------------------------------------

        if not AllowedClientReasons[
            reason
        ] then


            reason =
                'client_interrupt'
        end


        InterruptSession(
            playerSource,
            reason
        )
    end
)


---------------------------------------------------------
-- SERVER MONITOR
---------------------------------------------------------

CreateThread(function()

    while true do

        local config =
            GetConfig()


        local interval =
            math.max(
                tonumber(
                    config.ServerCheckInterval
                )
                or 250,

                100
            )


        Wait(
            interval
        )


        if config.Enabled == true then

            local tokens =
                {}


            -------------------------------------------------
            -- Snapshot tokens first.
            -------------------------------------------------

            for token in pairs(
                LBVampire.Runtime
                    .FeedingSessions
            ) do


                tokens[
                    #tokens + 1
                ] =
                    token
            end


            for _,
                token in ipairs(
                    tokens
                ) do


                local session =
                    LBVampire.Runtime
                        .FeedingSessions[
                            token
                        ]


                if session then

                    local reason =
                        ValidateSession(
                            token,
                            session
                        )


                    if reason then

                        -------------------------------------------------
                        -- requesterSource üzerinden Cancel çağırmak
                        -- session'ın tamamını server authoritative
                        -- biçimde kapatır.
                        -------------------------------------------------

                        InterruptSession(
                            session.requesterSource,
                            reason
                        )
                    end
                end
            end


            -------------------------------------------------
            -- Dead cache cleanup
            -------------------------------------------------

            for token in pairs(
                Motion
            ) do


                if not LBVampire.Runtime
                    .FeedingSessions[
                        token
                    ] then


                    Motion[
                        token
                    ] =
                        nil
                end
            end
        end
    end
end)


---------------------------------------------------------
-- RESOURCE STOP
---------------------------------------------------------

AddEventHandler(
    'onResourceStop',
    function(resourceName)

        if resourceName ~=
            GetCurrentResourceName() then

            return
        end


        Motion =
            {}
    end
)