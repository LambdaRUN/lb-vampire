LBVampire = LBVampire or {}

LBVampire.NPCWitness =
    LBVampire.NPCWitness or {}


local NPCWitness =
    LBVampire.NPCWitness


---------------------------------------------------------
-- CONFIG
---------------------------------------------------------

local function GetNPCConfig()

    return Config.NPCFeeding
        or {}
end


local function GetWitnessConfig()

    return GetNPCConfig().Witness
        or {}
end


local function GetDispatchConfig()

    return GetNPCConfig().Dispatch
        or {}
end


---------------------------------------------------------
-- UTILS
---------------------------------------------------------

local function Distance(
    first,
    second
)
    if not first
        or not second then

        return math.huge
    end


    local x =
        first.x
        - second.x


    local y =
        first.y
        - second.y


    local z =
        first.z
        - second.z


    return math.sqrt(
        (x * x)
        +
        (y * y)
        +
        (z * z)
    )
end


local function Clamp(
    value,
    minimum,
    maximum
)
    value =
        tonumber(
            value
        )
        or minimum


    if value <
        minimum then


        return minimum
    end


    if value >
        maximum then


        return maximum
    end


    return value
end


local function RandomBetween(
    minimum,
    maximum
)
    minimum =
        tonumber(
            minimum
        )
        or 0


    maximum =
        tonumber(
            maximum
        )
        or minimum


    if maximum <
        minimum then


        minimum,
        maximum =
            maximum,
            minimum
    end


    return math.random(
        math.floor(
            minimum
        ),

        math.floor(
            maximum
        )
    )
end


---------------------------------------------------------
-- PLAYER PED LOOKUP
---------------------------------------------------------

local function BuildPlayerPedLookup()

    local lookup =
        {}


    local players =
        GetPlayers()


    for i = 1,
        #players do


        local playerSource =
            tonumber(
                players[i]
            )


        if playerSource then


            local ped =
                GetPlayerPed(
                    playerSource
                )


            if ped
                and ped ~= 0 then


                lookup[
                    ped
                ] =
                    true
            end
        end
    end


    return lookup
end


---------------------------------------------------------
-- HUMAN PED CHECK
---------------------------------------------------------

local function IsHumanPed(
    ped
)
    local config =
        GetWitnessConfig()


    if config.HumanOnly ==
        false then


        return true
    end


    -----------------------------------------------------
    -- Native server build'de mevcutsa kullan.
    -----------------------------------------------------

    if type(
        IsPedHuman
    ) == 'function' then


        local success,
            result =
            pcall(
                IsPedHuman,
                ped
            )


        if success then

            return result ==
                true
        end
    end


    -----------------------------------------------------
    -- Fallback:
    -- GTA ped type 28 = animal.
    -----------------------------------------------------

    if type(
        GetPedType
    ) == 'function' then


        local success,
            pedType =
            pcall(
                GetPedType,
                ped
            )


        if success
            and tonumber(
                pedType
            ) == 28 then


            return false
        end
    end


    -----------------------------------------------------
    -- Native yoksa yanlışlıkla sistemi tamamen
    -- bozmak yerine ped'i kabul ediyoruz.
    -----------------------------------------------------

    return true
end


---------------------------------------------------------
-- VALID AMBIENT PED
---------------------------------------------------------

local function IsValidAmbientPed(
    ped,
    victim,
    playerPeds
)
    if not ped
        or ped == 0
        or ped == victim then


        return false
    end


    if not DoesEntityExist(
        ped
    ) then


        return false
    end


    if GetEntityType(
        ped
    ) ~= 1 then


        return false
    end


    -----------------------------------------------------
    -- Gerçek player witness havuzuna girmez.
    -----------------------------------------------------

    if playerPeds[
        ped
    ] == true then


        return false
    end


    if GetEntityHealth(
        ped
    ) <= 0 then


        return false
    end


    if not IsHumanPed(
        ped
    ) then


        return false
    end


    return true
end


---------------------------------------------------------
-- WORLD HOUR
---------------------------------------------------------

local function GetWorldHour()

    if LBVampire.Weather
        and LBVampire.Weather.GetHour then


        local success,
            hour =
            pcall(
                LBVampire.Weather.GetHour
            )


        hour =
            tonumber(
                hour
            )


        if success
            and hour
            and hour >= 0
            and hour <= 23 then


            return math.floor(
                hour
            )
        end
    end


    return nil
end


---------------------------------------------------------
-- NIGHT CHECK
---------------------------------------------------------

local function IsNight(
    hour
)
    if hour ==
        nil then


        return false
    end


    local config =
        GetDispatchConfig().Night
        or {}


    if config.Enabled ~=
        true then


        return false
    end


    local startHour =
        tonumber(
            config.StartHour
        )
        or 22


    local endHour =
        tonumber(
            config.EndHour
        )
        or 5


    -----------------------------------------------------
    -- Örn 22 -> 05
    -----------------------------------------------------

    if startHour >
        endHour then


        return hour >=
            startHour
            or hour <
                endHour
    end


    return hour >=
        startHour
        and hour <
            endHour
end


---------------------------------------------------------
-- WORLD SCAN
---------------------------------------------------------

local function ScanWorld(
    victimEntity,
    victimCoords
)
    local witnessConfig =
        GetWitnessConfig()


    local dispatchConfig =
        GetDispatchConfig()


    local playerPeds =
        BuildPlayerPedLookup()


    local witnessRadius =
        tonumber(
            witnessConfig.Radius
        )
        or 25.0


    local busyConfig =
        dispatchConfig.BusyArea
        or {}


    local busyRadius =
        tonumber(
            busyConfig.Radius
        )
        or 40.0


    local secludedConfig =
        dispatchConfig.Secluded
        or {}


    local secludedRadius =
        tonumber(
            secludedConfig.Radius
        )
        or 45.0


    -----------------------------------------------------
    -- RESULTS
    -----------------------------------------------------

    local witnesses =
        {}


    local busyPeds =
        0


    local secludedPeds =
        0


    local secludedVehicles =
        0


    -----------------------------------------------------
    -- PEDS
    -----------------------------------------------------

    local success,
        peds =
        pcall(
            GetAllPeds
        )


    if success
        and type(peds)
            == 'table' then


        for i = 1,
            #peds do


            local ped =
                peds[i]


            if IsValidAmbientPed(
                ped,
                victimEntity,
                playerPeds
            ) then


                local coords =
                    GetEntityCoords(
                        ped
                    )


                local distance =
                    Distance(
                        coords,
                        victimCoords
                    )


                -------------------------------------------------
                -- BUSY AREA COUNT
                -------------------------------------------------

                if distance <=
                    busyRadius then


                    busyPeds =
                        busyPeds + 1
                end


                -------------------------------------------------
                -- SECLUDED COUNT
                -------------------------------------------------

                if distance <=
                    secludedRadius then


                    secludedPeds =
                        secludedPeds + 1
                end


                -------------------------------------------------
                -- WITNESS
                -------------------------------------------------

                if witnessConfig.Enabled ==
                    true
                    and distance <=
                        witnessRadius then


                    local netId =
                        NetworkGetNetworkIdFromEntity(
                            ped
                        )


                    if netId
                        and netId > 0 then


                        witnesses[
                            #witnesses + 1
                        ] = {
                            entity =
                                ped,

                            netId =
                                netId,

                            distance =
                                distance
                        }
                    end
                end
            end
        end
    end


    -----------------------------------------------------
    -- CLOSEST FIRST
    -----------------------------------------------------

    table.sort(
        witnesses,

        function(
            first,
            second
        )

            return first.distance <
                second.distance
        end
    )


    -----------------------------------------------------
    -- MAX WITNESSES
    -----------------------------------------------------

    local maximumWitnesses =
        math.max(
            tonumber(
                witnessConfig.MaximumWitnesses
            )
            or 8,

            0
        )


    while #witnesses >
        maximumWitnesses do


        table.remove(
            witnesses
        )
    end


    -----------------------------------------------------
    -- VEHICLES
    -----------------------------------------------------

    local vehicleSuccess,
        vehicles =
        pcall(
            GetAllVehicles
        )


    if vehicleSuccess
        and type(vehicles)
            == 'table' then


        for i = 1,
            #vehicles do


            local vehicle =
                vehicles[i]


            if vehicle
                and vehicle ~= 0
                and DoesEntityExist(
                    vehicle
                ) then


                local coords =
                    GetEntityCoords(
                        vehicle
                    )


                if Distance(
                    coords,
                    victimCoords
                ) <= secludedRadius then


                    secludedVehicles =
                        secludedVehicles + 1
                end
            end
        end
    end


    return {
        witnesses =
            witnesses,

        busyPeds =
            busyPeds,

        secludedPeds =
            secludedPeds,

        secludedVehicles =
            secludedVehicles
    }
end


---------------------------------------------------------
-- DISPATCH CHANCE
---------------------------------------------------------

local function CalculateDispatchChance(
    scan,
    baseChanceOverride,
    modifierOverrides
)
    local config =
        GetDispatchConfig()


    modifierOverrides =
        modifierOverrides
        or {}


    local chance =
        tonumber(
            baseChanceOverride
        )
        or tonumber(
            config.BaseChance
        )
        or 35


    local breakdown = {
        base =
            chance,

        witness =
            0,

        busy =
            0,

        night =
            0,

        secluded =
            0
    }


    -----------------------------------------------------
    -- WITNESSES
    -----------------------------------------------------

    local witnessCount =
        #scan.witnesses


    if witnessCount >
        0 then


        local firstBonus =
            tonumber(
                modifierOverrides.WitnessBonus
            )
            or tonumber(
                config.WitnessBonus
            )
            or 25


        local additionalBonus =
            tonumber(
                modifierOverrides.AdditionalWitnessBonus
            )
            or tonumber(
                config.AdditionalWitnessBonus
            )
            or 5


        local maximumBonus =
            tonumber(
                modifierOverrides.MaxWitnessBonus
            )
            or tonumber(
                config.MaxWitnessBonus
            )
            or 40


        local totalBonus =
            firstBonus
            +
            (
                math.max(
                    witnessCount - 1,
                    0
                )
                *
                additionalBonus
            )


        totalBonus =
            math.min(
                totalBonus,
                maximumBonus
            )


        chance =
            chance + totalBonus


        breakdown.witness =
            totalBonus
    end


    -----------------------------------------------------
    -- BUSY
    -----------------------------------------------------

    local busy =
        config.BusyArea
        or {}


    if busy.Enabled ~=
        false then


        local minimumPeds =
            tonumber(
                busy.MinimumPeds
            )
            or 4


        if scan.busyPeds >=
            minimumPeds then


            local bonus =
                tonumber(
                    modifierOverrides.BusyBonus
                )
                or tonumber(
                    busy.Bonus
                )
                or 15


            chance =
                chance + bonus


            breakdown.busy =
                bonus
        end
    end


    -----------------------------------------------------
    -- NIGHT
    -----------------------------------------------------

    local hour =
        GetWorldHour()


    if IsNight(
        hour
    ) then


        local night =
            config.Night
            or {}


        local modifier =
            tonumber(
                modifierOverrides.NightModifier
            )
            or tonumber(
                night.Modifier
            )
            or -15


        chance =
            chance + modifier


        breakdown.night =
            modifier
    end


    -----------------------------------------------------
    -- SECLUDED
    -----------------------------------------------------

    local secluded =
        config.Secluded
        or {}


    if secluded.Enabled ==
        true then


        local maximumPeds =
            tonumber(
                secluded.MaximumPeds
            )
            or 1


        local maximumVehicles =
            tonumber(
                secluded.MaximumVehicles
            )
            or 1


        if scan.secludedPeds <=
            maximumPeds
            and scan.secludedVehicles <=
                maximumVehicles then


            local modifier =
                tonumber(
                    modifierOverrides.SecludedModifier
                )
                or tonumber(
                    secluded.Modifier
                )
                or -20


            chance =
                chance + modifier


            breakdown.secluded =
                modifier
        end
    end


    -----------------------------------------------------
    -- CLAMP
    -----------------------------------------------------

    chance =
        Clamp(
            chance,

            tonumber(
                config.MinChance
            )
            or 5,

            tonumber(
                config.MaxChance
            )
            or 95
        )


    return math.floor(
        chance + 0.5
    ),
    breakdown,
    hour
end


---------------------------------------------------------
-- ENTITY OWNER
---------------------------------------------------------

local function GetReactionSource(
    entity,
    fallbackSource
)
    if entity
        and entity ~= 0
        and DoesEntityExist(
            entity
        )
        and type(
            NetworkGetEntityOwner
        ) == 'function' then


        local success,
            owner =
            pcall(
                NetworkGetEntityOwner,
                entity
            )


        owner =
            tonumber(
                owner
            )


        if success
            and owner
            and owner > 0
            and GetPlayerName(
                owner
            ) then


            return owner
        end
    end


    return tonumber(
        fallbackSource
    )
end


---------------------------------------------------------
-- SEND REACTIONS
---------------------------------------------------------

local function SendReactions(
    vampireSource,
    victimEntity,
    victimNetId,
    scan,
    callerNetId
)
    -----------------------------------------------------
    -- VICTIM
    -----------------------------------------------------

    local victimSource =
        GetReactionSource(
            victimEntity,
            vampireSource
        )


    if victimSource then


        TriggerClientEvent(
            'lb-vampire:client:npcVictimDepleted',

            victimSource,

            {
                victimNetId =
                    victimNetId
            }
        )
    end


    -----------------------------------------------------
    -- WITNESSES
    -----------------------------------------------------

    local witnessConfig =
        GetWitnessConfig()


    local panicConfig =
        witnessConfig.Panic
        or {}


    local callerConfig =
        witnessConfig.Caller
        or {}


    for i = 1,
        #scan.witnesses do


        local witnessData =
            scan.witnesses[i]


        local mode =
            'PANIC'


        if callerNetId
            and witnessData.netId ==
                callerNetId then


            mode =
                'CALLER'
        end


        local shouldSend =
            false


        if mode ==
            'CALLER' then


            shouldSend =
                callerConfig.Enabled
                == true


        elseif mode ==
            'PANIC' then


            shouldSend =
                panicConfig.Enabled
                == true
        end


        if shouldSend then


            local reactionSource =
                GetReactionSource(
                    witnessData.entity,
                    vampireSource
                )


            if reactionSource then


                TriggerClientEvent(
                    'lb-vampire:client:npcWitnessReaction',

                    reactionSource,

                    {
                        victimNetId =
                            victimNetId,

                        witnessNetId =
                            witnessData.netId,

                        mode =
                            mode
                    }
                )
            end
        end
    end
end


---------------------------------------------------------
-- CALLER VALID
---------------------------------------------------------

local function IsCallerStillValid(
    callerNetId
)
    callerNetId =
        tonumber(
            callerNetId
        )


    if not callerNetId
        or callerNetId <= 0 then


        return false
    end


    local entity =
        NetworkGetEntityFromNetworkId(
            callerNetId
        )


    if not entity
        or entity == 0
        or not DoesEntityExist(
            entity
        ) then


        return false
    end


    return GetEntityHealth(
        entity
    ) > 0
end


---------------------------------------------------------
-- DISPATCH
---------------------------------------------------------

local function SendDispatch(
    vampireSource,
    victimCoords,
    kind
)
    if not LBVampire.Dispatch
        or not LBVampire.Dispatch.Send then


        if Config.Debug then

            print(
                '^1[LB-VAMPIRE]^7 NPC dispatch skipped: dispatch manager unavailable.'
            )
        end


        return false
    end


    return LBVampire.Dispatch.Send({
        source =
            vampireSource,

        kind =
            tostring(
                kind
                or 'npc_death'
            ),

        coords = {
            x =
                victimCoords.x,

            y =
                victimCoords.y,

            z =
                victimCoords.z
        }
    })
end


---------------------------------------------------------
-- PARTIAL INCIDENT CONFIG
---------------------------------------------------------

local function GetPartialIncidentConfig()

    return GetDispatchConfig()
        .PartialIncident
        or {}
end


---------------------------------------------------------
-- PARTIAL INCIDENT SEVERITY
---------------------------------------------------------

local function GetPartialSeverity(
    data
)
    data =
        data or {}


    local config =
        GetPartialIncidentConfig()


    local sessionLoss =
        math.max(
            tonumber(
                data.sessionLoss
            )
            or 0.0,

            0.0
        )


    local recentLoss =
        math.max(
            tonumber(
                data.recentLoss
            )
            or sessionLoss,

            sessionLoss
        )


    local remainingBlood =
        math.max(
            tonumber(
                data.remainingBlood
            )
            or 0.0,

            0.0
        )


    local minimumLoss =
        math.max(
            tonumber(
                config.MinimumBloodLoss
            )
            or 7.0,

            0.0
        )


    -----------------------------------------------------
    -- Çok kısa / kazara temas: dispatch yok.
    -- Ancak tekrar spam yapılırsa recentLoss büyür ve
    -- sonraki bırakmada olay değerlendirmeye girer.
    -----------------------------------------------------

    if recentLoss <
        minimumLoss then


        return nil,
            0,
            recentLoss
    end


    local severity =
        config.Severity
        or {}


    local light =
        severity.Light
        or {}


    local medium =
        severity.Medium
        or {}


    local heavy =
        severity.Heavy
        or {}


    local status =
        GetNPCConfig().StatusUI
        or {}


    local thresholds =
        status.Thresholds
        or {}


    local lowThreshold =
        tonumber(
            thresholds.Low
        )
        or 70


    local criticalThreshold =
        tonumber(
            thresholds.Critical
        )
        or 40


    local heavyLoss =
        tonumber(
            heavy.MinLoss
        )
        or 55


    local mediumLoss =
        tonumber(
            medium.MinLoss
        )
        or 25


    -----------------------------------------------------
    -- Kan kaybı veya kurbanın mevcut durumu hangisi daha
    -- ağırsa onu baz alıyoruz.
    -----------------------------------------------------

    if recentLoss >= heavyLoss
        or remainingBlood <= criticalThreshold then


        return 'HEAVY',
            tonumber(
                heavy.BaseChance
            )
            or 35,
            recentLoss
    end


    if recentLoss >= mediumLoss
        or remainingBlood <= lowThreshold then


        return 'MEDIUM',
            tonumber(
                medium.BaseChance
            )
            or 20,
            recentLoss
    end


    return 'LIGHT',
        tonumber(
            light.BaseChance
        )
        or 10,
        recentLoss
end


---------------------------------------------------------
-- VICTIM CALLER CHANCE
---------------------------------------------------------

local function RollVictimCaller(
    remainingBlood
)
    local config =
        GetPartialIncidentConfig()
            .VictimCaller
        or {}


    if config.Enabled ~=
        true then


        return false,
            nil,
            0
    end


    remainingBlood =
        tonumber(
            remainingBlood
        )
        or 0


    local healthyThreshold =
        tonumber(
            config.HealthyThreshold
        )
        or 60


    local weakThreshold =
        tonumber(
            config.WeakThreshold
        )
        or 30


    local chance


    if remainingBlood >
        healthyThreshold then


        chance =
            tonumber(
                config.HealthyChance
            )
            or 80


    elseif remainingBlood >
        weakThreshold then


        chance =
            tonumber(
                config.WeakChance
            )
            or 50


    else


        chance =
            tonumber(
                config.CriticalChance
            )
            or 20
    end


    chance =
        Clamp(
            chance,
            0,
            100
        )


    local roll =
        math.random(
            1,
            100
        )


    return roll <= chance,
        roll,
        chance
end


---------------------------------------------------------
-- PARTIAL WITNESS REACTIONS
---------------------------------------------------------

local function SendPartialWitnessReactions(
    vampireSource,
    victimNetId,
    scan,
    callerNetId
)
    local witnessConfig =
        GetWitnessConfig()


    local panicConfig =
        witnessConfig.Panic
        or {}


    local callerConfig =
        witnessConfig.Caller
        or {}


    for i = 1,
        #scan.witnesses do


        local witnessData =
            scan.witnesses[i]


        local mode =
            'PANIC'


        if callerNetId
            and witnessData.netId ==
                callerNetId then


            mode =
                'CALLER'
        end


        local shouldSend =
            false


        if mode ==
            'CALLER' then


            shouldSend =
                callerConfig.Enabled
                == true


        elseif mode ==
            'PANIC' then


            shouldSend =
                panicConfig.Enabled
                == true
        end


        if shouldSend then


            local reactionSource =
                GetReactionSource(
                    witnessData.entity,
                    vampireSource
                )


            if reactionSource then


                TriggerClientEvent(
                    'lb-vampire:client:npcWitnessReaction',

                    reactionSource,

                    {
                        victimNetId =
                            victimNetId,

                        witnessNetId =
                            witnessData.netId,

                        mode =
                            mode
                    }
                )
            end
        end
    end
end


---------------------------------------------------------
-- HANDLE DEPLETION
---------------------------------------------------------

function NPCWitness.HandleDepletion(
    vampireSource,
    victimNetId
)
    vampireSource =
        tonumber(
            vampireSource
        )


    victimNetId =
        tonumber(
            victimNetId
        )


    if not vampireSource
        or not victimNetId then


        return false,
            'invalid_arguments'
    end


    local victim =
        NetworkGetEntityFromNetworkId(
            victimNetId
        )


    if not victim
        or victim == 0
        or not DoesEntityExist(
            victim
        ) then


        return false,
            'victim_not_found'
    end


    local victimCoords =
        GetEntityCoords(
            victim
        )


    local scan =
        ScanWorld(
            victim,
            victimCoords
        )


    local dispatchConfig =
        GetDispatchConfig()


    local dispatchSuccessful =
        false


    local chance =
        0


    local roll =
        nil


    local hour =
        GetWorldHour()


    local breakdown = {
        base = 0,
        witness = 0,
        busy = 0,
        night = 0,
        secluded = 0
    }


    if dispatchConfig.Enabled ==
        true then


        chance,
        breakdown,
        hour =
            CalculateDispatchChance(
                scan
            )


        roll =
            math.random(
                1,
                100
            )


        dispatchSuccessful =
            roll <= chance
    end


    local witnessConfig =
        GetWitnessConfig()


    local callerConfig =
        witnessConfig.Caller
        or {}


    local callerNetId =
        nil


    if dispatchSuccessful
        and callerConfig.Enabled ==
            true
        and #scan.witnesses > 0 then


        callerNetId =
            scan.witnesses[1]
                .netId
    end


    SendReactions(
        vampireSource,
        victim,
        victimNetId,
        scan,
        callerNetId
    )


    if Config.Debug then


        print(
            (
                '^5[LB-VAMPIRE]^7 NPC Dispatch Analysis | Witnesses:%s | BusyPeds:%s | SecludedPeds:%s | Vehicles:%s | Hour:%s'
            ):format(

                tostring(
                    #scan.witnesses
                ),

                tostring(
                    scan.busyPeds
                ),

                tostring(
                    scan.secludedPeds
                ),

                tostring(
                    scan.secludedVehicles
                ),

                tostring(
                    hour
                    or 'unknown'
                )
            )
        )


        if dispatchConfig.Enabled ==
            true then


            print(
                (
                    '^5[LB-VAMPIRE]^7 NPC Dispatch Chance | Final:%s%% | Roll:%s | Dispatch:%s | Base:%s Witness:%s Busy:%s Night:%s Secluded:%s'
                ):format(

                    tostring(
                        chance
                    ),

                    tostring(
                        roll
                    ),

                    tostring(
                        dispatchSuccessful
                    ),

                    tostring(
                        breakdown.base
                    ),

                    tostring(
                        breakdown.witness
                    ),

                    tostring(
                        breakdown.busy
                    ),

                    tostring(
                        breakdown.night
                    ),

                    tostring(
                        breakdown.secluded
                    )
                )
            )
        end
    end


    if dispatchSuccessful ~=
        true then


        return true,
            {
                dispatched =
                    false,

                chance =
                    chance,

                roll =
                    roll,

                witnesses =
                    #scan.witnesses
            }
    end


    local delayConfig


    if callerNetId then


        delayConfig =
            callerConfig.DispatchDelay
            or {}


    else


        delayConfig =
            dispatchConfig.AnonymousDelay
            or {}
    end


    local delay =
        RandomBetween(

            delayConfig.Min
            or 0,

            delayConfig.Max
            or delayConfig.Min
            or 0
        )


    SetTimeout(
        delay,

        function()


            if callerNetId
                and not IsCallerStillValid(
                    callerNetId
                ) then


                if Config.Debug then

                    print(
                        '^3[LB-VAMPIRE]^7 NPC dispatch cancelled: caller no longer available.'
                    )
                end


                return
            end


            SendDispatch(
                vampireSource,
                victimCoords,
                'npc_death'
            )
        end
    )


    return true,
        {
            dispatched =
                true,

            chance =
                chance,

            roll =
                roll,

            delay =
                delay,

            callerNetId =
                callerNetId,

            witnesses =
                #scan.witnesses
        }
end


---------------------------------------------------------
-- HANDLE RELEASE / PARTIAL FEEDING INCIDENT
---------------------------------------------------------

function NPCWitness.HandleRelease(
    vampireSource,
    victimNetId,
    incidentData
)
    vampireSource =
        tonumber(
            vampireSource
        )


    victimNetId =
        tonumber(
            victimNetId
        )


    incidentData =
        incidentData or {}


    if not vampireSource
        or not victimNetId then


        return false,
            'invalid_arguments'
    end


    local partialConfig =
        GetPartialIncidentConfig()


    if partialConfig.Enabled ~=
        true then


        return true,
            {
                eligible = false,
                dispatched = false,
                victimCaller = false
            }
    end


    local victim =
        NetworkGetEntityFromNetworkId(
            victimNetId
        )


    if not victim
        or victim == 0
        or not DoesEntityExist(
            victim
        )
        or GetEntityHealth(
            victim
        ) <= 0 then


        return false,
            'victim_not_found'
    end


    local severity,
        baseChance,
        recentLoss =
        GetPartialSeverity(
            incidentData
        )


    -----------------------------------------------------
    -- Çok kısa temas. Reaksiyon normal release tarafında
    -- devam eder ama suç/dispatch olayı oluşturulmaz.
    -----------------------------------------------------

    if not severity then


        if Config.Debug then

            print(
                (
                    '^5[LB-VAMPIRE]^7 NPC Partial Incident ignored | NetID:%s | SessionLoss:%.2f | RecentLoss:%.2f | Minimum:%.2f'
                ):format(
                    tostring(
                        victimNetId
                    ),

                    tonumber(
                        incidentData.sessionLoss
                    )
                    or 0.0,

                    tonumber(
                        recentLoss
                    )
                    or 0.0,

                    tonumber(
                        partialConfig.MinimumBloodLoss
                    )
                    or 7.0
                )
            )
        end


        return true,
            {
                eligible = false,
                dispatched = false,
                victimCaller = false,
                recentLoss = recentLoss
            }
    end


    local victimCoords =
        GetEntityCoords(
            victim
        )


    local scan =
        ScanWorld(
            victim,
            victimCoords
        )


    local dispatchConfig =
        GetDispatchConfig()


    local dispatchSuccessful =
        false


    local chance =
        0


    local roll =
        nil


    local hour =
        GetWorldHour()


    local breakdown = {
        base = 0,
        witness = 0,
        busy = 0,
        night = 0,
        secluded = 0
    }


    if dispatchConfig.Enabled ==
        true then


        chance,
        breakdown,
        hour =
            CalculateDispatchChance(
                scan,
                baseChance,
                partialConfig.Modifiers
                or {}
            )


        roll =
            math.random(
                1,
                100
            )


        dispatchSuccessful =
            roll <= chance
    end


    local witnessConfig =
        GetWitnessConfig()


    local callerConfig =
        witnessConfig.Caller
        or {}


    local victimCaller =
        false


    local victimCallerRoll =
        nil


    local victimCallerChance =
        0


    local callerNetId =
        nil


    if dispatchSuccessful then


        victimCaller,
        victimCallerRoll,
        victimCallerChance =
            RollVictimCaller(
                incidentData.remainingBlood
            )


        if not victimCaller
            and callerConfig.Enabled ==
                true
            and #scan.witnesses > 0 then


            callerNetId =
                scan.witnesses[1]
                    .netId
        end
    end


    -----------------------------------------------------
    -- Witness'lar olay ciddi ise dispatch çıkmasa bile
    -- paniğe kapılabilir. Kurbanın release reaksiyonu ise
    -- npc_feeding.lua tarafından ayrı gönderilir.
    -----------------------------------------------------

    SendPartialWitnessReactions(
        vampireSource,
        victimNetId,
        scan,
        callerNetId
    )


    if Config.Debug then


        print(
            (
                '^5[LB-VAMPIRE]^7 NPC Partial Dispatch Analysis | Severity:%s | SessionLoss:%.2f | RecentLoss:%.2f | Remaining:%.2f | Witnesses:%s | BusyPeds:%s | SecludedPeds:%s | Vehicles:%s | Hour:%s'
            ):format(
                tostring(
                    severity
                ),

                tonumber(
                    incidentData.sessionLoss
                )
                or 0.0,

                tonumber(
                    recentLoss
                )
                or 0.0,

                tonumber(
                    incidentData.remainingBlood
                )
                or 0.0,

                tostring(
                    #scan.witnesses
                ),

                tostring(
                    scan.busyPeds
                ),

                tostring(
                    scan.secludedPeds
                ),

                tostring(
                    scan.secludedVehicles
                ),

                tostring(
                    hour
                    or 'unknown'
                )
            )
        )


        if dispatchConfig.Enabled ==
            true then


            print(
                (
                    '^5[LB-VAMPIRE]^7 NPC Partial Dispatch Chance | Final:%s%% | Roll:%s | Dispatch:%s | Base:%s Witness:%s Busy:%s Night:%s Secluded:%s | VictimCaller:%s (%s/%s)'
                ):format(
                    tostring(
                        chance
                    ),

                    tostring(
                        roll
                    ),

                    tostring(
                        dispatchSuccessful
                    ),

                    tostring(
                        breakdown.base
                    ),

                    tostring(
                        breakdown.witness
                    ),

                    tostring(
                        breakdown.busy
                    ),

                    tostring(
                        breakdown.night
                    ),

                    tostring(
                        breakdown.secluded
                    ),

                    tostring(
                        victimCaller
                    ),

                    tostring(
                        victimCallerRoll
                        or '-'
                    ),

                    tostring(
                        victimCallerChance
                    )
                )
            )
        end
    end


    if dispatchSuccessful ~=
        true then


        return true,
            {
                eligible = true,
                severity = severity,
                dispatched = false,
                victimCaller = false,
                chance = chance,
                roll = roll,
                witnesses = #scan.witnesses,
                recentLoss = recentLoss
            }
    end


    local delayConfig


    if victimCaller
        or callerNetId then


        delayConfig =
            callerConfig.DispatchDelay
            or {}


    else


        delayConfig =
            dispatchConfig.AnonymousDelay
            or {}
    end


    local delay =
        RandomBetween(

            delayConfig.Min
            or 0,

            delayConfig.Max
            or delayConfig.Min
            or 0
        )


    local callerCheckNetId =
        victimCaller
        and victimNetId
        or callerNetId


    SetTimeout(
        delay,

        function()


            if callerCheckNetId
                and not IsCallerStillValid(
                    callerCheckNetId
                ) then


                if Config.Debug then

                    print(
                        '^3[LB-VAMPIRE]^7 NPC partial dispatch cancelled: caller no longer available.'
                    )
                end


                return
            end


            SendDispatch(
                vampireSource,
                victimCoords,
                'suspicious'
            )
        end
    )


    return true,
        {
            eligible = true,
            severity = severity,
            dispatched = true,
            victimCaller = victimCaller,
            chance = chance,
            roll = roll,
            delay = delay,
            callerNetId = callerNetId,
            witnesses = #scan.witnesses,
            recentLoss = recentLoss
        }
end


---------------------------------------------------------
-- EXPORTS
---------------------------------------------------------

exports(
    'HandleNPCDepletion',

    function(
        vampireSource,
        victimNetId
    )

        return NPCWitness.HandleDepletion(
            vampireSource,
            victimNetId
        )
    end
)


exports(
    'HandleNPCFeedingRelease',

    function(
        vampireSource,
        victimNetId,
        incidentData
    )

        return NPCWitness.HandleRelease(
            vampireSource,
            victimNetId,
            incidentData
        )
    end
)
