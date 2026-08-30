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
-- INITIAL REGISTER
---------------------------------------------------------

CreateThread(function()

    Wait(
        1000
    )


    RegisterQBTarget()
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


            return
        end


        if resourceName ==
            GetCurrentResourceName() then


            UnregisterQBTarget()
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
                    '^5[LB-VAMPIRE]^7 Target Bridge | Provider: qb-target | Resource: %s | Registered: %s'
                ):format(

                    tostring(
                        GetResourceState(
                            TARGET_RESOURCE
                        )
                    ),

                    tostring(
                        TargetBridge.Registered
                    )
                )
            )
        end,
        false
    )
end