LBVampire = LBVampire or {}

LBVampire.Spawn =
    LBVampire.Spawn or {}


local Spawn =
    LBVampire.Spawn


---------------------------------------------------------
-- STATE
---------------------------------------------------------

Spawn.ready =
    false

Spawn.selectionActive =
    true

Spawn.selectionReason =
    'resource_start'

Spawn.generation =
    0

Spawn.lastReadyReason =
    nil


---------------------------------------------------------
-- SETTINGS
---------------------------------------------------------

local FALLBACK_CHECK_INTERVAL =
    500

local FALLBACK_STABLE_CHECKS =
    3

local QB_READY_DELAY =
    900


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
-- PLAYER DATA
---------------------------------------------------------

local function HasLoadedCharacter()
    local QBCore =
        GetQBCore()


    if not QBCore
        or not QBCore.Functions then

        return false
    end


    local PlayerData =
        QBCore.Functions
            .GetPlayerData()


    if not PlayerData then
        return false
    end


    if not PlayerData.citizenid
        or PlayerData.citizenid == '' then

        return false
    end


    return true
end


---------------------------------------------------------
-- GENERIC READY CHECK
---------------------------------------------------------

local function IsProbablySpawnReady()
    if not NetworkIsPlayerActive(
        PlayerId()
    ) then

        return false
    end


    if not HasLoadedCharacter() then
        return false
    end


    local ped =
        PlayerPedId()


    if not ped
        or ped == 0
        or not DoesEntityExist(
            ped
        ) then

        return false
    end


    -----------------------------------------------------
    -- Stock qb-spawn selection sırasında ped invisible.
    -----------------------------------------------------

    if not IsEntityVisible(
        ped
    ) then

        return false
    end


    -----------------------------------------------------
    -- Fade tamamlanmadan HUD açılmasın.
    -----------------------------------------------------

    if IsScreenFadedOut() then
        return false
    end


    return true
end


---------------------------------------------------------
-- SELECTION START
---------------------------------------------------------

local function MarkSelectionStarted(
    reason
)
    Spawn.generation =
        Spawn.generation + 1


    Spawn.ready =
        false


    Spawn.selectionActive =
        true


    Spawn.selectionReason =
        reason
        or 'unknown'


    if Config.Debug then

        print(
            (
                '^5[LB-VAMPIRE]^7 Spawn selection STARTED | Reason: %s'
            ):format(
                tostring(
                    Spawn.selectionReason
                )
            )
        )
    end


    TriggerEvent(
        'lb-vampire:client:spawnSelectionStarted',
        Spawn.selectionReason
    )
end


---------------------------------------------------------
-- READY
---------------------------------------------------------

local function MarkSpawnReady(
    reason
)
    if Spawn.ready == true
        and Spawn.selectionActive ~= true then

        return
    end


    Spawn.generation =
        Spawn.generation + 1


    Spawn.ready =
        true


    Spawn.selectionActive =
        false


    Spawn.lastReadyReason =
        reason
        or 'unknown'


    Spawn.selectionReason =
        nil


    if Config.Debug then

        print(
            (
                '^2[LB-VAMPIRE]^7 Spawn READY | Reason: %s'
            ):format(
                tostring(
                    Spawn.lastReadyReason
                )
            )
        )
    end


    TriggerEvent(
        'lb-vampire:client:spawnReady',
        Spawn.lastReadyReason
    )
end


---------------------------------------------------------
-- PUBLIC API
---------------------------------------------------------

function Spawn.SetSelectionActive(
    active,
    reason
)
    if active == true then

        MarkSelectionStarted(
            reason
            or 'external'
        )

    else

        MarkSpawnReady(
            reason
            or 'external'
        )
    end
end


function Spawn.MarkReady(
    reason
)
    MarkSpawnReady(
        reason
        or 'external'
    )
end


function Spawn.IsReady()
    return Spawn.ready == true
        and Spawn.selectionActive ~= true
end


function Spawn.IsSelectionActive()
    return Spawn.selectionActive == true
end


---------------------------------------------------------
-- EXPORTS
---------------------------------------------------------

exports(
    'SetSpawnSelectionActive',
    function(
        active,
        reason
    )

        Spawn.SetSelectionActive(
            active,
            reason
        )
    end
)


exports(
    'MarkSpawnReady',
    function(
        reason
    )

        Spawn.MarkReady(
            reason
        )
    end
)


exports(
    'IsSpawnReady',
    function()

        return Spawn.IsReady()
    end
)


---------------------------------------------------------
-- GENERIC EVENTS
---------------------------------------------------------

RegisterNetEvent(
    'lb-vampire:client:setSpawnSelectionActive',
    function(
        active,
        reason
    )

        Spawn.SetSelectionActive(
            active,
            reason
        )
    end
)


RegisterNetEvent(
    'lb-vampire:client:markSpawnReady',
    function(
        reason
    )

        Spawn.MarkReady(
            reason
        )
    end
)


---------------------------------------------------------
-- QB-MULTICHARACTER
---------------------------------------------------------

RegisterNetEvent(
    'qb-multicharacter:client:chooseChar',
    function()

        MarkSelectionStarted(
            'qb-multicharacter'
        )
    end
)


---------------------------------------------------------
-- QB-SPAWN
---------------------------------------------------------

RegisterNetEvent(
    'qb-spawn:client:openUI',
    function(value)

        if value == false then
            return
        end


        MarkSelectionStarted(
            'qb-spawn'
        )
    end
)


---------------------------------------------------------
-- APARTMENTS
---------------------------------------------------------

RegisterNetEvent(
    'apartments:client:setupSpawnUI',
    function()

        MarkSelectionStarted(
            'apartments'
        )
    end
)


---------------------------------------------------------
-- PLAYER UNLOAD
---------------------------------------------------------

RegisterNetEvent(
    'QBCore:Client:OnPlayerUnload',
    function()

        MarkSelectionStarted(
            'player_unload'
        )
    end
)


---------------------------------------------------------
-- PLAYER LOADED
---------------------------------------------------------

RegisterNetEvent(
    'QBCore:Client:OnPlayerLoaded',
    function()

        local generation =
            Spawn.generation


        CreateThread(function()

            Wait(
                QB_READY_DELAY
            )


            if generation ~=
                Spawn.generation then

                return
            end


            if not IsProbablySpawnReady() then
                return
            end


            MarkSpawnReady(
                'qbcore_player_loaded'
            )
        end)
    end
)


---------------------------------------------------------
-- GENERIC FALLBACK
---------------------------------------------------------

CreateThread(function()

    Wait(
        750
    )


    local stableChecks =
        0


    while true do

        Wait(
            FALLBACK_CHECK_INTERVAL
        )


        local probablyReady =
            IsProbablySpawnReady()


        -------------------------------------------------
        -- Player definitely not ready.
        -------------------------------------------------

        if not probablyReady then

            stableChecks =
                0


        -------------------------------------------------
        -- Already ready.
        -------------------------------------------------

        elseif Spawn.ready == true then

            stableChecks =
                0


        -------------------------------------------------
        -- IMPORTANT:
        --
        -- Resource restart while player is already
        -- ingame.
        --
        -- Previously resource_start was stuck forever
        -- because selectionActive started as true.
        -------------------------------------------------

        elseif Spawn.selectionReason ==
            'resource_start' then


            stableChecks =
                stableChecks + 1


            if stableChecks >=
                FALLBACK_STABLE_CHECKS then


                stableChecks =
                    0


                MarkSpawnReady(
                    'resource_restart_fallback'
                )
            end


        -------------------------------------------------
        -- Generic system with no active selector.
        -------------------------------------------------

        elseif Spawn.selectionActive ~= true then


            stableChecks =
                stableChecks + 1


            if stableChecks >=
                FALLBACK_STABLE_CHECKS then


                stableChecks =
                    0


                MarkSpawnReady(
                    'generic_fallback'
                )
            end


        -------------------------------------------------
        -- Known spawn selectors.
        --
        -- Once ped becomes visible and gameplay has
        -- stabilized we can safely recover.
        -------------------------------------------------

        elseif Spawn.selectionReason ==
            'qb-spawn'
            or Spawn.selectionReason ==
                'apartments' then


            stableChecks =
                stableChecks + 1


            if stableChecks >=
                FALLBACK_STABLE_CHECKS then


                stableChecks =
                    0


                MarkSpawnReady(
                    'known_spawn_visual_fallback'
                )
            end


        -------------------------------------------------
        -- Explicit/custom selector.
        --
        -- Do NOT auto-ready these solely because ped is
        -- visible. Adapter should call MarkSpawnReady.
        -------------------------------------------------

        else

            stableChecks =
                0
        end
    end
end)


---------------------------------------------------------
-- DEBUG
---------------------------------------------------------

if Config.Debug then

    RegisterCommand(
        'vamspawnstate',
        function()

            print(
                (
                    '^5[LB-VAMPIRE]^7 Spawn State | Ready: %s | Selection: %s | Reason: %s | LastReady: %s'
                ):format(

                    tostring(
                        Spawn.ready
                    ),

                    tostring(
                        Spawn.selectionActive
                    ),

                    tostring(
                        Spawn.selectionReason
                    ),

                    tostring(
                        Spawn.lastReadyReason
                    )
                )
            )
        end,
        false
    )


    RegisterCommand(
        'vamspawnstart',
        function()

            MarkSelectionStarted(
                'debug'
            )
        end,
        false
    )


    RegisterCommand(
        'vamspawnready',
        function()

            MarkSpawnReady(
                'debug'
            )
        end,
        false
    )
end