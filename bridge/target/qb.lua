LBVampire = LBVampire or {}

LBVampire.TargetBridge =
    LBVampire.TargetBridge or {}


local TargetBridge =
    LBVampire.TargetBridge


---------------------------------------------------------
-- STATE
---------------------------------------------------------

TargetBridge.Registered =
    false

TargetBridge.NPCDebugRegistered =
    false

TargetBridge.NPCFeedingRegistered =
    false

TargetBridge.BeastPreyTargets =
    TargetBridge.BeastPreyTargets or {}


local TARGET_RESOURCE =
    'qb-target'


---------------------------------------------------------
-- CONFIG
---------------------------------------------------------

local function GetTargetConfig()
    return Config.Interactions
        and Config.Interactions.Target
        or {}
end


local function GetFeedingConfig()
    local targetConfig =
        GetTargetConfig()


    return targetConfig.Feeding
        or {}
end

local function GetNPCDebugTargetConfig()

    return Config.NPCFeeding
        and Config.NPCFeeding.Debug
        and Config.NPCFeeding.Debug.Target
        or {}
end

local function GetNPCFeedingTargetConfig()

    return Config.NPCFeeding
        and Config.NPCFeeding.Interaction
        or {}
end

local function GetBeastFeedingTargetConfig()

    return Config.BeastCall
        and Config.BeastCall.Feeding
        and Config.BeastCall.Feeding.Interaction
        or {}
end

---------------------------------------------------------
-- PROVIDER CHECK
---------------------------------------------------------

local function ShouldUseQBTarget()
    local config =
        GetTargetConfig()


    if config.Enabled ~= true then
        return false
    end


    local provider =
        string.lower(
            tostring(
                config.Provider
                or 'auto'
            )
        )


    if provider ~= 'auto'
        and provider ~= 'qb-target'
        and provider ~= 'qb' then


        return false
    end


    return GetResourceState(
        TARGET_RESOURCE
    ) == 'started'
end


---------------------------------------------------------
-- LABEL
---------------------------------------------------------

local function GetFeedingLabel()
    local config =
        GetFeedingConfig()


    return tostring(
        config.Label
        or 'Beslenme İsteği Gönder'
    )
end


---------------------------------------------------------
-- REGISTER
---------------------------------------------------------

local function RegisterQBTarget()
    if TargetBridge.Registered
        == true then


        return true
    end


    if not ShouldUseQBTarget() then

        if Config.Debug then

            print(
                '^3[LB-VAMPIRE]^7 qb-target bridge inactive.'
            )
        end


        return false
    end


    local config =
        GetFeedingConfig()


    local label =
        GetFeedingLabel()


    local icon =
        tostring(
            config.Icon
            or 'fas fa-tint'
        )


    local distance =
        tonumber(
            config.Distance
        )
        or tonumber(
            Config.Feeding
                and Config.Feeding.RequestDistance
        )
        or 2.5


    -----------------------------------------------------
    -- GLOBAL PLAYER OPTION
    -----------------------------------------------------

    exports[
        TARGET_RESOURCE
    ]:AddGlobalPlayer({

        options = {

            {
                num =
                    1,

                icon =
                    icon,

                label =
                    label,


                -------------------------------------------------
                -- Visibility
                -------------------------------------------------

                canInteract =
                    function(
                        entity,
                        targetDistance
                    )

                        if not LBVampire.Interactions
                            or not LBVampire.Interactions.CanRequestFeeding then


                            return false
                        end


                        return LBVampire.Interactions
                            .CanRequestFeeding(
                                entity,
                                targetDistance
                            )
                    end,


                -------------------------------------------------
                -- Click
                -------------------------------------------------

                action =
                    function(entity)

                        if not LBVampire.Interactions
                            or not LBVampire.Interactions.RequestFeeding then


                            return
                        end


                        LBVampire.Interactions
                            .RequestFeeding(
                                entity
                            )
                    end
            }
        },


        distance =
            distance
    })


    TargetBridge.Registered =
        true


    if Config.Debug then

        print(
            (
                '^2[LB-VAMPIRE]^7 qb-target feeding interaction registered | Label: %s | Distance: %.1f'
            ):format(
                label,
                distance
            )
        )
    end


    return true
end

---------------------------------------------------------
-- REGISTER NPC FEEDING TARGET
--
-- Intentionally kept separate from the proven 0.4.6
-- debug registration. This avoids changing the working
-- debug target pipeline while 5A is tested.
---------------------------------------------------------

local function RegisterNPCFeedingTarget()

    if TargetBridge.NPCFeedingRegistered == true then
        return true
    end

    if not Config.NPCFeeding
        or Config.NPCFeeding.Enabled ~= true then

        return false
    end

    if not ShouldUseQBTarget() then
        return false
    end

    local config =
        GetNPCFeedingTargetConfig()

    local label =
        tostring(
            config.Label
            or 'Beslen'
        )

    local icon =
        tostring(
            config.Icon
            or 'fas fa-tint'
        )

    local distance =
        tonumber(
            config.Distance
        )
        or 2.5

    exports[
        TARGET_RESOURCE
    ]:AddGlobalPed({

        options = {

            {
                num = 2,

                icon = icon,

                label = label,

                canInteract =
                    function(
                        entity,
                        targetDistance
                    )

                        if not LBVampire.NPCFeedingClient
                            or not LBVampire.NPCFeedingClient.CanFeed then

                            return false
                        end

                        return LBVampire.NPCFeedingClient.CanFeed(
                            entity,
                            targetDistance
                        )
                    end,

                action =
                    function(entity)

                        if Config.Debug then
                            print(
                                (
                                    '^5[LB-VAMPIRE]^7 qb-target Beslen clicked | Entity: %s'
                                ):format(
                                    tostring(entity)
                                )
                            )
                        end

                        if not LBVampire.NPCFeedingClient
                            or not LBVampire.NPCFeedingClient.Request then

                            if Config.Debug then
                                print(
                                    '^1[LB-VAMPIRE]^7 NPC feeding click failed: client/npc_feeding.lua is not loaded.'
                                )
                            end

                            return
                        end

                        LBVampire.NPCFeedingClient.Request(
                            entity
                        )
                    end
            }
        },

        distance = distance
    })

    TargetBridge.NPCFeedingRegistered =
        true

    if Config.Debug then
        print(
            (
                '^2[LB-VAMPIRE]^7 qb-target NPC feeding interaction registered | Label: %s | Distance: %.1f'
            ):format(
                label,
                distance
            )
        )
    end

    return true
end

---------------------------------------------------------
-- UNREGISTER NPC FEEDING TARGET
---------------------------------------------------------

local function UnregisterNPCFeedingTarget()

    if TargetBridge.NPCFeedingRegistered ~= true then
        return
    end

    if GetResourceState(
        TARGET_RESOURCE
    ) == 'started' then

        local config =
            GetNPCFeedingTargetConfig()

        local label =
            tostring(
                config.Label
                or 'Beslen'
            )

        pcall(
            function()

                exports[
                    TARGET_RESOURCE
                ]:RemoveGlobalPed(
                    label
                )
            end
        )
    end

    TargetBridge.NPCFeedingRegistered =
        false

    if Config.Debug then
        print(
            '^5[LB-VAMPIRE]^7 qb-target NPC feeding interaction unregistered.'
        )
    end
end

---------------------------------------------------------
-- DYNAMIC BEAST PREY TARGET
---------------------------------------------------------

function TargetBridge.RegisterBeastPrey(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        return false
    end

    if not ShouldUseQBTarget() then
        return false
    end

    if TargetBridge.BeastPreyTargets[entity] == true then
        return true
    end

    local config = GetBeastFeedingTargetConfig()
    local label = tostring(config.Label or 'Beslen')
    local icon = tostring(config.Icon or 'fas fa-tint')
    local distance = tonumber(config.Distance) or 2.5

    exports[TARGET_RESOURCE]:AddTargetEntity(entity, {
        options = {
            {
                num = 1,
                icon = icon,
                label = label,

                canInteract = function(targetEntity, targetDistance)
                    if not LBVampire.BeastCallClient
                        or not LBVampire.BeastCallClient.CanFeed then
                        return false
                    end

                    return LBVampire.BeastCallClient.CanFeed(
                        targetEntity,
                        targetDistance
                    )
                end,

                action = function(targetEntity)
                    if not LBVampire.BeastCallClient
                        or not LBVampire.BeastCallClient.RequestFeed then
                        return
                    end

                    LBVampire.BeastCallClient.RequestFeed(targetEntity)
                end
            }
        },
        distance = distance
    })

    TargetBridge.BeastPreyTargets[entity] = true

    if Config.Debug then
        print((
            '^2[LB-VAMPIRE]^7 qb-target Beast prey registered | Entity:%s | Label:%s'
        ):format(tostring(entity), label))
    end

    return true
end

function TargetBridge.UnregisterBeastPrey(entity)
    if not entity or entity == 0 then return end

    if TargetBridge.BeastPreyTargets[entity] ~= true then
        return
    end

    if GetResourceState(TARGET_RESOURCE) == 'started' then
        local config = GetBeastFeedingTargetConfig()
        local label = tostring(config.Label or 'Beslen')

        pcall(function()
            exports[TARGET_RESOURCE]:RemoveTargetEntity(entity, label)
        end)
    end

    TargetBridge.BeastPreyTargets[entity] = nil

    if Config.Debug then
        print((
            '^5[LB-VAMPIRE]^7 qb-target Beast prey unregistered | Entity:%s'
        ):format(tostring(entity)))
    end
end

---------------------------------------------------------
-- REGISTER NPC DEBUG TARGET
---------------------------------------------------------

local function RegisterNPCDebugTarget()

    -----------------------------------------------------
    -- ALREADY REGISTERED
    -----------------------------------------------------

    if TargetBridge.NPCDebugRegistered ==
        true then


        return true
    end


    -----------------------------------------------------
    -- DEBUG ONLY
    -----------------------------------------------------

    if Config.Debug ~=
        true then


        return false
    end


    -----------------------------------------------------
    -- QB TARGET
    -----------------------------------------------------

    if not ShouldUseQBTarget() then

        return false
    end


    -----------------------------------------------------
    -- CONFIG
    -----------------------------------------------------

    local config =
        GetNPCDebugTargetConfig()


    if config.Enabled ~=
        true then


        return false
    end


    local label =
        tostring(
            config.Label
            or 'NPC Debug'
        )


    local icon =
        tostring(
            config.Icon
            or 'fas fa-droplet'
        )


    local distance =
        tonumber(
            config.Distance
        )
        or 2.5


    -----------------------------------------------------
    -- GLOBAL PED
    -----------------------------------------------------

    exports[
        TARGET_RESOURCE
    ]:AddGlobalPed({

        options = {

            {
                num =
                    1,

                icon =
                    icon,

                label =
                    label,


                -------------------------------------------------
                -- VISIBILITY
                -------------------------------------------------

                canInteract =
                    function(
                        entity,
                        targetDistance
                    )

                        if not LBVampire.NPCDebug
                            or not LBVampire.NPCDebug.CanDeplete then


                            return false
                        end


                        return LBVampire.NPCDebug
                            .CanDeplete(
                                entity,
                                targetDistance
                            )
                    end,


                -------------------------------------------------
                -- CLICK
                -------------------------------------------------

                action =
                    function(
                        entity
                    )

                        if not LBVampire.NPCDebug
                            or not LBVampire.NPCDebug.Deplete then


                            return
                        end


                        LBVampire.NPCDebug
                            .Deplete(
                                entity
                            )
                    end
            }
        },

        distance =
            distance
    })


    TargetBridge.NPCDebugRegistered =
        true


    if Config.Debug then

        print(
            (
                '^2[LB-VAMPIRE]^7 qb-target NPC debug interaction registered | Label: %s | Distance: %.1f'
            ):format(
                label,
                distance
            )
        )
    end


    return true
end

---------------------------------------------------------
-- UNREGISTER
---------------------------------------------------------

local function UnregisterQBTarget()
    if TargetBridge.Registered
        ~= true then


        return
    end


    -----------------------------------------------------
    -- qb-target durmuşsa export çağırmayız.
    -----------------------------------------------------

    if GetResourceState(
        TARGET_RESOURCE
    ) == 'started' then


        local label =
            GetFeedingLabel()


        pcall(
            function()

                exports[
                    TARGET_RESOURCE
                ]:RemoveGlobalPlayer(
                    label
                )
            end
        )
    end


    TargetBridge.Registered =
        false


    if Config.Debug then

        print(
            '^5[LB-VAMPIRE]^7 qb-target feeding interaction unregistered.'
        )
    end
end

---------------------------------------------------------
-- UNREGISTER NPC DEBUG TARGET
---------------------------------------------------------

local function UnregisterNPCDebugTarget()

    if TargetBridge.NPCDebugRegistered ~=
        true then


        return
    end


    if GetResourceState(
        TARGET_RESOURCE
    ) == 'started' then


        local config =
            GetNPCDebugTargetConfig()


        local label =
            tostring(
                config.Label
                or 'NPC Debug'
            )


        pcall(
            function()

                exports[
                    TARGET_RESOURCE
                ]:RemoveGlobalPed(
                    label
                )
            end
        )
    end


    TargetBridge.NPCDebugRegistered =
        false


    if Config.Debug then

        print(
            '^5[LB-VAMPIRE]^7 qb-target NPC debug interaction unregistered.'
        )
    end
end

---------------------------------------------------------
-- INITIAL REGISTER
---------------------------------------------------------

CreateThread(function()

    Wait(
        1000
    )


    RegisterQBTarget()


    RegisterNPCFeedingTarget()


    RegisterNPCDebugTarget()
end)


---------------------------------------------------------
-- QB-TARGET STARTED AFTER LB-VAMPIRE
---------------------------------------------------------

AddEventHandler(
    'onClientResourceStart',
    function(resourceName)

        if resourceName ~=
            TARGET_RESOURCE then


            return
        end


        CreateThread(function()

            Wait(
                500
            )


            RegisterQBTarget()

            RegisterNPCFeedingTarget()

            RegisterNPCDebugTarget()
        end)
    end
)


---------------------------------------------------------
-- QB-TARGET STOP
---------------------------------------------------------

AddEventHandler(
    'onClientResourceStop',
    function(resourceName)

        if resourceName ==
            TARGET_RESOURCE then


            TargetBridge.Registered =
                false

            
            TargetBridge.NPCDebugRegistered =
                false

            TargetBridge.NPCFeedingRegistered =
                false

            TargetBridge.BeastPreyTargets =
                {}

            return
        end


        if resourceName ==
            GetCurrentResourceName() then


            UnregisterQBTarget()

            UnregisterNPCFeedingTarget()

            UnregisterNPCDebugTarget()
        end
    end
)


---------------------------------------------------------
-- DEBUG STATE
---------------------------------------------------------

if Config.Debug then

    RegisterCommand(
        'vamtargetstate',
        function()

            print(
                (
                    '^5[LB-VAMPIRE]^7 Target Bridge | Resource: %s | Player: %s | NPC Feeding: %s | NPC Debug: %s'
                ):format(

                    tostring(
                        GetResourceState(
                            TARGET_RESOURCE
                        )
                    ),

                    tostring(
                        TargetBridge.Registered
                    ),

                    tostring(
                        TargetBridge.NPCFeedingRegistered
                    ),

                    tostring(
                        TargetBridge.NPCDebugRegistered
                    )
                )
            )
        end,
        false
    )
end