print('^2[LB-VAMPIRE]^7 Dispatch manager.lua LOADED')

LBVampire = LBVampire or {}



LBVampire.Dispatch =
    LBVampire.Dispatch or {}

LBVampire.DispatchProviders =
    LBVampire.DispatchProviders or {}


local Dispatch =
    LBVampire.Dispatch


---------------------------------------------------------
-- CONFIG
---------------------------------------------------------

local function GetConfig()

    return Config.Dispatch
        or {}
end


---------------------------------------------------------
-- NORMALIZE PROVIDER
---------------------------------------------------------

local function NormalizeProvider(
    provider
)
    provider =
        string.lower(
            tostring(
                provider
                or 'auto'
            )
        )


    if provider == 'ps-dispatch'
        or provider == 'ps_dispatch'
        or provider == 'psdispatch' then


        return 'ps'
    end


    if provider == 'qb-core'
        or provider == 'qbcore'
        or provider == 'qb-policejob'
        or provider == 'qb_policejob' then


        return 'qb'
    end


    if provider == 'disabled' then

        return 'none'
    end


    return provider
end


---------------------------------------------------------
-- PROVIDER AVAILABLE
---------------------------------------------------------

local function IsProviderAvailable(
    providerName
)
    local provider


    if providerName == 'ps' then

        provider =
            LBVampire.DispatchProviders.PS


    elseif providerName == 'qb' then

        provider =
            LBVampire.DispatchProviders.QB
    end


    if not provider then

        return false
    end


    if type(
        provider.IsAvailable
    ) ~= 'function' then


        return false
    end


    local success,
        available =
        pcall(
            provider.IsAvailable
        )


    return success
        and available == true
end


---------------------------------------------------------
-- RESOLVE PROVIDER
---------------------------------------------------------

function Dispatch.GetProvider()

    local config =
        GetConfig()


    if config.Enabled ==
        false then


        return 'none'
    end


    local configured =
        NormalizeProvider(
            config.Provider
        )


    -----------------------------------------------------
    -- EXPLICIT NONE
    -----------------------------------------------------

    if configured ==
        'none' then


        return 'none'
    end


    -----------------------------------------------------
    -- EXPLICIT PS
    -----------------------------------------------------

    if configured ==
        'ps' then


        if IsProviderAvailable(
            'ps'
        ) then


            return 'ps'
        end


        return 'none'
    end


    -----------------------------------------------------
    -- EXPLICIT QB
    -----------------------------------------------------

    if configured ==
        'qb' then


        if IsProviderAvailable(
            'qb'
        ) then


            return 'qb'
        end


        return 'none'
    end


    -----------------------------------------------------
    -- AUTO
    -----------------------------------------------------

    local auto =
        config.Auto
        or {}


    -----------------------------------------------------
    -- PS FIRST
    -----------------------------------------------------

    if auto.PreferPS ~=
        false then


        if IsProviderAvailable(
            'ps'
        ) then


            return 'ps'
        end


        if IsProviderAvailable(
            'qb'
        ) then


            return 'qb'
        end


    else


        if IsProviderAvailable(
            'qb'
        ) then


            return 'qb'
        end


        if IsProviderAvailable(
            'ps'
        ) then


            return 'ps'
        end
    end


    return 'none'
end


---------------------------------------------------------
-- GET PROVIDER OBJECT
---------------------------------------------------------

local function GetProviderObject(
    providerName
)
    if providerName ==
        'ps' then


        return LBVampire
            .DispatchProviders
            .PS
    end


    if providerName ==
        'qb' then


        return LBVampire
            .DispatchProviders
            .QB
    end


    return nil
end


local function GetAlertConfig(
    kind
)
    local alerts =
        GetConfig().Alerts
        or {}


    kind =
        string.lower(
            tostring(
                kind
                or 'suspicious'
            )
        )


    if kind == 'npc_death'
        or kind == 'npcdeath' then


        return alerts.NPCDeath
            or {}
    end


    if kind == 'beast_call'
        or kind == 'beastcall'
        or kind == 'animal' then


        return alerts.BeastCall
            or {}
    end


    return alerts.Suspicious
        or {}
end


---------------------------------------------------------
-- SEND
---------------------------------------------------------

function Dispatch.Send(
    data
)
    data =
        data or {}


    local alert =
        GetAlertConfig(
            data.kind
        )


    if not data.title then

        data.title =
            alert.Title
            or 'Yeni İhbar'
    end


    if not data.description then

        data.description =
            alert.Description
            or 'Şüpheli bir olay bildirildi.'
    end


    local providerName =
        Dispatch.GetProvider()


    if providerName ==
        'none' then


        if Config.Debug then

            print(
                '^3[LB-VAMPIRE]^7 Dispatch skipped: no provider available.'
            )
        end


        return false,
            'provider_unavailable'
    end


    local provider =
        GetProviderObject(
            providerName
        )


    if not provider
        or type(
            provider.Send
        ) ~= 'function' then


        return false,
            'provider_invalid'
    end


    -----------------------------------------------------
    -- PROVIDER CALL
    -----------------------------------------------------

    local callSuccess,
        sendSuccess,
        result =
        pcall(
            provider.Send,
            data
        )


    if not callSuccess then


        print(
            (
                '^1[LB-VAMPIRE]^7 Dispatch provider error | Provider: %s | Error: %s'
            ):format(

                tostring(
                    providerName
                ),

                tostring(
                    sendSuccess
                )
            )
        )


        return false,
            'provider_error'
    end


    if sendSuccess ~=
        true then


        if Config.Debug then

            print(
                (
                    '^3[LB-VAMPIRE]^7 Dispatch failed | Provider: %s | Reason: %s'
                ):format(

                    tostring(
                        providerName
                    ),

                    tostring(
                        result
                    )
                )
            )
        end


        return false,
            result
    end


    if Config.Debug then

        print(
            (
                '^2[LB-VAMPIRE]^7 Dispatch completed | Provider: %s'
            ):format(
                providerName
            )
        )
    end


    return true,
        result
end





---------------------------------------------------------
-- EXPORT
---------------------------------------------------------

exports(
    'SendVampireDispatch',

    function(
        data
    )

        return Dispatch.Send(
            data
        )
    end
)



---------------------------------------------------------
-- DEBUG STATE
---------------------------------------------------------

if Config.Debug then

    RegisterCommand(
        'vamdispatchstate',

        function(source)


            local provider =
                Dispatch.GetProvider()


            local message =
                (
                    'LB-VAMPIRE Dispatch Provider: %s | PS: %s | QB: %s'
                ):format(

                    tostring(
                        provider
                    ),

                    tostring(
                        IsProviderAvailable(
                            'ps'
                        )
                    ),

                    tostring(
                        IsProviderAvailable(
                            'qb'
                        )
                    )
                )


            print(
                '^5[LB-VAMPIRE]^7 '
                .. message
            )


            if source >
                0 then


                TriggerClientEvent(
                    'QBCore:Notify',

                    source,

                    message,

                    'primary',

                    5000
                )
            end
        end,

        false
    )


    -----------------------------------------------------
    -- DEBUG ALERT
    -----------------------------------------------------

    -----------------------------------------------------
-- DEBUG ALERT
-----------------------------------------------------

RegisterCommand(
        'vamdispatchtest',

        function(
            source,
            args
        )
            print(
                (
                    '^5[LB-VAMPIRE]^7 /vamdispatchtest invoked | Source: %s'
                ):format(
                    tostring(source)
                )
            )


            -------------------------------------------------
            -- PLAYER ONLY
            -------------------------------------------------

            if not source
                or source <= 0 then


                print(
                    '^1[LB-VAMPIRE]^7 Dispatch test failed: command must be used by a player.'
                )


                return
            end


            -------------------------------------------------
            -- PLAYER PED
            -------------------------------------------------

            local ped =
                GetPlayerPed(
                    source
                )


            print(
                (
                    '^5[LB-VAMPIRE]^7 Dispatch test ped: %s'
                ):format(
                    tostring(ped)
                )
            )


            if not ped
                or ped == 0 then


                print(
                    (
                        '^1[LB-VAMPIRE]^7 Dispatch test failed: GetPlayerPed returned %s for source %s.'
                    ):format(
                        tostring(ped),
                        tostring(source)
                    )
                )


                return
            end


            -------------------------------------------------
            -- COORDS
            -------------------------------------------------

            local coords =
                GetEntityCoords(
                    ped
                )


            if not coords then


                print(
                    '^1[LB-VAMPIRE]^7 Dispatch test failed: player coords unavailable.'
                )


                return
            end


            print(
                (
                    '^5[LB-VAMPIRE]^7 Dispatch test coords: %.2f %.2f %.2f'
                ):format(
                    coords.x,
                    coords.y,
                    coords.z
                )
            )


            -------------------------------------------------
            -- KIND
            -------------------------------------------------

            local kind =
                string.lower(
                    tostring(
                        args
                        and args[1]
                        or 'npc'
                    )
                )


            local data


            -------------------------------------------------
            -- BEAST CALL
            -------------------------------------------------

            if kind == 'beast' then


                data = {
                    source =
                        source,

                    kind =
                        'beast_call',

                    coords = {
                        x = coords.x,
                        y = coords.y,
                        z = coords.z
                    }
                }


            -------------------------------------------------
            -- NPC DEATH
            -------------------------------------------------

            else


                data = {
                    source =
                        source,

                    kind =
                        'npc_death',

                    coords = {
                        x = coords.x,
                        y = coords.y,
                        z = coords.z
                    }
                }
            end


            -------------------------------------------------
            -- SEND
            -------------------------------------------------

            local success,
                result =
                Dispatch.Send(
                    data
                )


            print(
                (
                    '^5[LB-VAMPIRE]^7 Dispatch test result | Kind: %s | Success: %s | Result: %s'
                ):format(
                    tostring(kind),
                    tostring(success),
                    tostring(
                        type(result) == 'table'
                        and result.provider
                        or result
                    )
                )
            )
        end,

        false
    )
end