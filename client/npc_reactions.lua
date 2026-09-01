LBVampire = LBVampire or {}


---------------------------------------------------------
-- CONFIG
---------------------------------------------------------

local function GetNPCConfig()

    return Config.NPCFeeding
        or {}
end


local function GetBehaviorConfig()

    return GetNPCConfig().Behavior
        or {}
end


local function GetWitnessConfig()

    return GetNPCConfig().Witness
        or {}
end


---------------------------------------------------------
-- CONTROL
---------------------------------------------------------

local function RequestControl(
    entity,
    timeout
)
    if not entity
        or entity == 0
        or not DoesEntityExist(
            entity
        ) then


        return false
    end


    if NetworkHasControlOfEntity(
        entity
    ) then


        return true
    end


    timeout =
        tonumber(
            timeout
        )
        or 1500


    local expires =
        GetGameTimer()
        + timeout


    repeat


        NetworkRequestControlOfEntity(
            entity
        )


        Wait(
            20
        )


        if NetworkHasControlOfEntity(
            entity
        ) then


            return true
        end


    until GetGameTimer() >=
        expires


    return NetworkHasControlOfEntity(
        entity
    )
end


---------------------------------------------------------
-- NETWORK PED
---------------------------------------------------------

local function GetNetworkPed(
    netId,
    timeout
)
    netId =
        tonumber(
            netId
        )


    if not netId
        or netId <= 0 then


        return nil
    end


    timeout =
        tonumber(
            timeout
        )
        or 1500


    local expires =
        GetGameTimer()
        + timeout


    repeat


        if NetworkDoesEntityExistWithNetworkId(
            netId
        ) then


            local ped =
                NetToPed(
                    netId
                )


            if ped
                and ped ~= 0
                and DoesEntityExist(
                    ped
                ) then


                return ped
            end
        end


        Wait(
            25
        )


    until GetGameTimer() >=
        expires


    return nil
end


---------------------------------------------------------
-- ANIM DICT
---------------------------------------------------------

local function LoadAnimDict(
    dictionary
)
    dictionary =
        tostring(
            dictionary
            or ''
        )


    if dictionary ==
        '' then


        return false
    end


    if HasAnimDictLoaded(
        dictionary
    ) then


        return true
    end


    RequestAnimDict(
        dictionary
    )


    local expires =
        GetGameTimer()
        + 3000


    while not HasAnimDictLoaded(
        dictionary
    ) do


        Wait(
            10
        )


        if GetGameTimer() >=
            expires then


            return false
        end
    end


    return true
end


---------------------------------------------------------
-- KILL VICTIM
---------------------------------------------------------

local function KillVictim(
    victim
)
    local behavior =
        GetBehaviorConfig()


    local emptyConfig =
        behavior.BloodEmpty
        or {}


    if emptyConfig.KillNPC ~=
        true then


        return
    end


    RequestControl(
        victim,
        1500
    )


    ClearPedTasksImmediately(
        victim
    )


    SetPedCanRagdoll(
        victim,
        true
    )


    SetPedDiesWhenInjured(
        victim,
        true
    )


    SetEntityHealth(
        victim,
        0
    )
end


---------------------------------------------------------
-- PANIC
---------------------------------------------------------

local function RunPanicReaction(
    witness,
    victim
)
    local panic =
        GetWitnessConfig().Panic
        or {}


    if panic.Enabled ~=
        true then


        return
    end


    if not witness
        or witness == 0
        or IsEntityDead(
            witness
        ) then


        return
    end


    RequestControl(
        witness,
        1000
    )


    TaskSmartFleePed(
        witness,
        victim,

        tonumber(
            panic.FleeDistance
        )
        or 0.0,

        tonumber(
            panic.FleeDuration
        )
        or -1,

        false,
        false
    )
end


---------------------------------------------------------
-- CALLER
---------------------------------------------------------

local function RunCallerReaction(
    caller,
    victim
)
    local config =
        GetWitnessConfig().Caller
        or {}


    if config.Enabled ~=
        true then


        return
    end


    if not caller
        or caller == 0
        or IsEntityDead(
            caller
        ) then


        return
    end


    RequestControl(
        caller,
        1500
    )


    -----------------------------------------------------
    -- MOVE AWAY
    -----------------------------------------------------

    TaskSmartFleePed(
        caller,
        victim,

        tonumber(
            config.MoveAwayDistance
        )
        or 0.0,

        tonumber(
            config.MoveAwayDuration
        )
        or 0,

        false,
        false
    )


    Wait(
        tonumber(
            config.MoveAwayDuration
        )
        or 0
    )


    if not DoesEntityExist(
        caller
    )
        or IsEntityDead(
            caller
        ) then


        return
    end


    ClearPedTasks(
        caller
    )


    -----------------------------------------------------
    -- PHONE
    -----------------------------------------------------

    local phone =
        config.Phone
        or {}


    local dictionary =
        tostring(
            phone.Dictionary
            or ''
        )


    local animation =
        tostring(
            phone.Animation
            or ''
        )


    local duration =
        tonumber(
            phone.Duration
        )
        or 0


    if dictionary ~=
        ''
        and animation ~=
            ''
        and LoadAnimDict(
            dictionary
        ) then


        TaskPlayAnim(
            caller,

            dictionary,

            animation,

            3.0,
            -3.0,

            duration,

            tonumber(
                phone.Flag
            )
            or 49,

            0.0,

            false,
            false,
            false
        )


        Wait(
            duration
        )
    end


    -----------------------------------------------------
    -- FLEE
    -----------------------------------------------------

    if config.FleeAfterCall ==
        true
        and DoesEntityExist(
            caller
        )
        and not IsEntityDead(
            caller
        ) then


        ClearPedTasks(
            caller
        )


        TaskSmartFleePed(
            caller,
            victim,

            tonumber(
                config.FleeDistance
            )
            or 0.0,

            tonumber(
                config.FleeDuration
            )
            or -1,

            false,
            false
        )
    end
end


---------------------------------------------------------
-- VICTIM DEPLETED
---------------------------------------------------------

RegisterNetEvent(
    'lb-vampire:client:npcVictimDepleted',

    function(
        data
    )
        data =
            data or {}


        local victim =
            GetNetworkPed(
                data.victimNetId
            )


        if not victim then


            if Config.Debug then

                print(
                    '^1[LB-VAMPIRE]^7 NPC depleted reaction: victim not available.'
                )
            end


            return
        end


        KillVictim(
            victim
        )
    end
)


---------------------------------------------------------
-- WITNESS REACTION
---------------------------------------------------------

RegisterNetEvent(
    'lb-vampire:client:npcWitnessReaction',

    function(
        data
    )
        data =
            data or {}


        local witness =
            GetNetworkPed(
                data.witnessNetId
            )


        if not witness then


            return
        end


        local victim =
            GetNetworkPed(
                data.victimNetId
            )


        if not victim then


            return
        end


        local mode =
            string.upper(
                tostring(
                    data.mode
                    or 'PANIC'
                )
            )


        if mode ==
            'CALLER' then


            CreateThread(
                function()

                    RunCallerReaction(
                        witness,
                        victim
                    )
                end
            )


        else


            RunPanicReaction(
                witness,
                victim
            )
        end
    end
)


---------------------------------------------------------
-- VICTIM CALLER PHONE
---------------------------------------------------------

local function RunVictimCallerPhone(
    victim
)
    if not victim
        or victim == 0
        or not DoesEntityExist(
            victim
        )
        or IsEntityDead(
            victim
        ) then


        return
    end


    local config =
        GetWitnessConfig().Caller
        or {}


    if config.Enabled ~=
        true then


        return
    end


    local phone =
        config.Phone
        or {}


    local dictionary =
        tostring(
            phone.Dictionary
            or ''
        )


    local animation =
        tostring(
            phone.Animation
            or ''
        )


    local duration =
        tonumber(
            phone.Duration
        )
        or 0


    if dictionary ==
        ''
        or animation ==
            ''
        or duration <= 0 then


        return
    end


    if not LoadAnimDict(
        dictionary
    ) then


        return
    end


    RequestControl(
        victim,
        1500
    )


    if not DoesEntityExist(
        victim
    )
        or IsEntityDead(
            victim
        ) then


        return
    end


    ClearPedTasks(
        victim
    )


    TaskPlayAnim(
        victim,

        dictionary,
        animation,

        3.0,
        -3.0,

        duration,

        tonumber(
            phone.Flag
        )
        or 49,

        0.0,

        false,
        false,
        false
    )


    Wait(
        duration
    )
end


---------------------------------------------------------
-- FEEDING RELEASED ALIVE
---------------------------------------------------------

RegisterNetEvent(
    'lb-vampire:client:npcFeedingReleased',

    function(
        data
    )
        data =
            data or {}


        local victim =
            GetNetworkPed(
                data.netId
            )


        if not victim
            or IsEntityDead(
                victim
            ) then


            return
        end


        local config =
            GetBehaviorConfig()
                .AfterFeeding
            or {}


        local remainingBlood =
            tonumber(
                data.remainingBlood
            )
            or 0


        local threshold =
            tonumber(
                config.HealthyThreshold
            )
            or 0


        local ragdoll


        if remainingBlood >
            threshold then


            ragdoll =
                config.HealthyRagdoll
                or {}


        else


            ragdoll =
                config.WeakRagdoll
                or {}
        end


        local minimum =
            tonumber(
                ragdoll.Min
            )
            or 0


        local maximum =
            tonumber(
                ragdoll.Max
            )
            or minimum


        if maximum <
            minimum then


            minimum,
            maximum =
                maximum,
                minimum
        end


        local duration =
            math.random(
                math.floor(
                    minimum
                ),

                math.floor(
                    maximum
                )
            )


        RequestControl(
            victim,
            1500
        )


        ClearPedTasksImmediately(
            victim
        )


        if duration >
            0 then


            SetPedToRagdoll(
                victim,

                duration,
                duration,

                0,

                false,
                false,
                false
            )


            Wait(
                duration + 250
            )
        end


        -------------------------------------------------
        -- VICTIM CALLER
        --
        -- Dispatch roll başarılı olup kurban caller seçildiyse
        -- toparlandıktan sonra telefon davranışına girer.
        -------------------------------------------------

        if data.caller ==
            true
            and DoesEntityExist(
                victim
            )
            and not IsEntityDead(
                victim
            ) then


            RunVictimCallerPhone(
                victim
            )
        end


        -------------------------------------------------
        -- FLEE
        -------------------------------------------------

        if config.FleeAfterRecovery ==
            true
            and DoesEntityExist(
                victim
            )
            and not IsEntityDead(
                victim
            ) then


            TaskSmartFleePed(
                victim,

                PlayerPedId(),

                tonumber(
                    config.FleeDistance
                )
                or 0.0,

                tonumber(
                    config.FleeDuration
                )
                or -1,

                false,
                false
            )
        end
    end
)