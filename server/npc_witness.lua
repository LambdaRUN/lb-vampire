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
        first.x - second.x

    local y =
        first.y - second.y

    local z =
        first.z - second.z


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
        tonumber(value)
        or minimum


    if value < minimum then

        return minimum
    end


    if value > maximum then

        return maximum
    end


    return value
end


local function RandomBetween(
    minimum,
    maximum
)
    minimum =
        tonumber(minimum)
        or 0


    maximum =
        tonumber(maximum)
        or minimum


    if maximum < minimum then

        minimum,
        maximum =
            maximum,
            minimum
    end


    return math.random(
        math.floor(minimum),
        math.floor(maximum)
    )
end


---------------------------------------------------------
-- PLAYER PED LOOKUP
--
-- Ambient NPC taramasında gerçek oyuncuları witness
-- olarak saymamak için.
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
-- WORLD HOUR
---------------------------------------------------------

local function GetWorldHour()

    -----------------------------------------------------
    -- Önce LB-VAMPIRE weather bridge getter'larını
    -- deniyoruz.
    -----------------------------------------------------

    if LBVampire.Weather then

        local getters = {
            'GetHour',
            'GetCurrentHour',
            'GetGameHour'
        }


        for i = 1,
            #getters do


            local getter =
                LBVampire.Weather[
                    getters[i]
                ]


            if type(getter)
                == 'function' then


                local success,
                    hour =
                    pcall(
                        getter
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
        end
    end


    -----------------------------------------------------
    -- Native mevcutsa fallback.
    -----------------------------------------------------

    if type(GetClockHours)
        == 'function' then


        local success,
            hour =
            pcall(
                GetClockHours
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


    -----------------------------------------------------
    -- Saat bulunamazsa night modifier uygulanmaz.
    -----------------------------------------------------

    return nil
end


---------------------------------------------------------
-- NIGHT CHECK
---------------------------------------------------------

local function IsNight(
    hour
)
    if hour == nil then

        return false
    end


    local config =
        GetDispatchConfig().Night
        or {}


    if config.Enabled ~= true then

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
    -- Örnek:
    --
    -- Start = 22
    -- End   = 05
    --
    -- 22:00 -> 04:59 night.
    -----------------------------------------------------

    if startHour >
        endHour then


        return hour >= startHour
            or hour < endHour
    end


    -----------------------------------------------------
    -- Örn:
    --
    -- 18 -> 23
    -----------------------------------------------------

    return hour >= startHour
        and hour < endHour
end


---------------------------------------------------------
-- VALID AMBIENT PED
---------------------------------------------------------

local function IsValidAmbientPed(
    ped,
    victimEntity,
    playerPeds
)
    if not ped
        or ped == 0
        or ped == victimEntity then


        return false
    end


    if not DoesEntityExist(
        ped
    ) then


        return false
    end


    -----------------------------------------------------
    -- Player ped değil.
    -----------------------------------------------------

    if playerPeds[
        ped
    ] == true then


        return false
    end


    -----------------------------------------------------
    -- Ped entity olmalı.
    -----------------------------------------------------

    if GetEntityType(
        ped
    ) ~= 1 then


        return false
    end


    -----------------------------------------------------
    -- Ölü witness sayma.
    -----------------------------------------------------

    if GetEntityHealth(
        ped
    ) <= 0 then


        return false
    end


    return true
end


---------------------------------------------------------
-- WORLD SCAN
--
-- Witness
-- Nearby pedestrian density
-- Nearby vehicle density
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


    -----------------------------------------------------
    -- RADII
    -----------------------------------------------------

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


    local scanRadius =
        math.max(
            witnessRadius,
            busyRadius,
            secludedRadius
        )


    -----------------------------------------------------
    -- RESULTS
    -----------------------------------------------------

    local witnesses =
        {}


    local nearbyPeds =
        0


    local nearbyVehicles =
        0


    -----------------------------------------------------
    -- PED SCAN
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
                -- GENERAL PEDESTRIAN DENSITY
                -------------------------------------------------

                if distance <=
                    scanRadius then


                    nearbyPeds =
                        nearbyPeds + 1
                end


                -------------------------------------------------
                -- WITNESS
                -------------------------------------------------

                if witnessConfig.Enabled == true
                    and distance <= witnessRadius then


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
    -- CLOSEST WITNESS FIRST
    -----------------------------------------------------

    table.sort(
        witnesses,

        function(
            first,
            second
        )

            return first.distance
                < second.distance
        end
    )


    -----------------------------------------------------
    -- WITNESS LIMIT
    -----------------------------------------------------

    local maximumWitnesses =
        tonumber(
            witnessConfig.MaximumWitnesses
        )
        or 8


    maximumWitnesses =
        math.max(
            maximumWitnesses,
            0
        )


    while #witnesses >
        maximumWitnesses do


        table.remove(
            witnesses
        )
    end


    -----------------------------------------------------
    -- VEHICLE SCAN
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


                    nearbyVehicles =
                        nearbyVehicles + 1
                end
            end
        end
    end


    return {

        witnesses =
            witnesses,

        nearbyPeds =
            nearbyPeds,

        nearbyVehicles =
            nearbyVehicles
    }
end


---------------------------------------------------------
-- DISPATCH CHANCE
---------------------------------------------------------

local function CalculateDispatchChance(
    scan
)
    local config =
        GetDispatchConfig()


    local chance =
        tonumber(
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


        local firstWitnessBonus =
            tonumber(
                config.WitnessBonus
            )
            or 25


        local additionalWitnessBonus =
            tonumber(
                config.AdditionalWitnessBonus
            )
            or 5


        local maximumWitnessBonus =
            tonumber(
                config.MaxWitnessBonus
            )
            or 40


        -------------------------------------------------
        -- İlk witness ana bonusu alır.
        --
        -- Diğer witnesslar AdditionalWitnessBonus.
        -------------------------------------------------

        local witnessBonus =
            firstWitnessBonus
            +
            (
                math.max(
                    witnessCount - 1,
                    0
                )
                *
                additionalWitnessBonus
            )


        witnessBonus =
            math.min(
                witnessBonus,
                maximumWitnessBonus
            )


        chance =
            chance
            +
            witnessBonus


        breakdown.witness =
            witnessBonus
    end


    -----------------------------------------------------
    -- BUSY AREA
    -----------------------------------------------------

    local busyConfig =
        config.BusyArea
        or {}


    local minimumPeds =
        tonumber(
            busyConfig.MinimumPeds
        )
        or 4


    if scan.nearbyPeds >=
        minimumPeds then


        local bonus =
            tonumber(
                busyConfig.Bonus
            )
            or 15


        chance =
            chance
            +
            bonus


        breakdown.busy =
            bonus
    end


    -----------------------------------------------------
    -- NIGHT
    -----------------------------------------------------

    local hour =
        GetWorldHour()


    if IsNight(
        hour
    ) then


        local nightConfig =
            config.Night
            or {}


        local modifier =
            tonumber(
                nightConfig.Modifier
            )
            or -15


        chance =
            chance
            +
            modifier


        breakdown.night =
            modifier
    end


    -----------------------------------------------------
    -- SECLUDED
    -----------------------------------------------------

    local secludedConfig =
        config.Secluded
        or {}


    if secludedConfig.Enabled ==
        true then


        local maximumPeds =
            tonumber(
                secludedConfig.MaximumPeds
            )
            or 1


        local maximumVehicles =
            tonumber(
                secludedConfig.MaximumVehicles
            )
            or 1


        if scan.nearbyPeds <=
            maximumPeds
            and scan.nearbyVehicles <=
                maximumVehicles then


            local modifier =
                tonumber(
                    secludedConfig.Modifier
                )
                or -20


            chance =
                chance
                +
                modifier


            breakdown.secluded =
                modifier
        end
    end


    -----------------------------------------------------
    -- FINAL CLAMP
    -----------------------------------------------------

    local minimumChance =
        tonumber(
            config.MinChance
        )
        or 5


    local maximumChance =
        tonumber(
            config.MaxChance
        )
        or 95


    chance =
        Clamp(
            chance,
            minimumChance,
            maximumChance
        )


    return math.floor(
        chance + 0.5
    ),
    breakdown,
    hour
end


---------------------------------------------------------
-- SEND CLIENT REACTIONS
---------------------------------------------------------

local function SendReaction(
    vampireSource,
    victimNetId,
    scan,
    callerNetId
)
    local witnessConfig =
        GetWitnessConfig()


    local witnessNetIds =
        {}


    -----------------------------------------------------
    -- Panic disabled ise witness list client'a
    -- gönderilmez.
    -----------------------------------------------------

    if witnessConfig.Panic ==
        true then


        for i = 1,
            #scan.witnesses do


            witnessNetIds[
                #witnessNetIds + 1
            ] =
                scan.witnesses[i]
                    .netId
        end
    end


    TriggerClientEvent(
        'lb-vampire:client:npcDepletedReaction',

        vampireSource,

        {
            victimNetId =
                victimNetId,

            witnesses =
                witnessNetIds,

            callerNetId =
                callerNetId
        }
    )
end


---------------------------------------------------------
-- DISPATCH
---------------------------------------------------------

local function SendDispatch(
    victimCoords
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


    -----------------------------------------------------
    -- Manager otomatik:
    --
    -- PS available -> PS
    -- otherwise QB
    -----------------------------------------------------

    local success,
        result =
        LBVampire.Dispatch.Send({

            kind =
                'npc_death',

            title =
                'Şüpheli Saldırı',

            description =
                'Olası saldırı sonucu yerde hareketsiz bir şahıs bildirildi.',

            coords = {

                x =
                    victimCoords.x,

                y =
                    victimCoords.y,

                z =
                    victimCoords.z
            }
        })


    return success,
        result
end


---------------------------------------------------------
-- HANDLE NPC BLOOD DEPLETION
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


    -----------------------------------------------------
    -- VICTIM ENTITY
    -----------------------------------------------------

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


    -----------------------------------------------------
    -- WORLD SCAN
    -----------------------------------------------------

    local scan =
        ScanWorld(
            victim,
            victimCoords
        )


    -----------------------------------------------------
    -- DISPATCH ENABLED?
    -----------------------------------------------------

    local dispatchConfig =
        GetDispatchConfig()


    local dispatchEnabled =
        dispatchConfig.Enabled
        == true


    -----------------------------------------------------
    -- CHANCE
    -----------------------------------------------------

    local chance =
        0


    local breakdown = {
        base = 0,
        witness = 0,
        busy = 0,
        night = 0,
        secluded = 0
    }


    local hour =
        GetWorldHour()


    local roll =
        nil


    local dispatchSuccessful =
        false


    if dispatchEnabled then


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


    -----------------------------------------------------
    -- CALLER
    --
    -- Dispatch gerçekten başarılı olacaksa ve
    -- witness mevcutsa caller seçiyoruz.
    -----------------------------------------------------

    local callerNetId =
        nil


    local witnessConfig =
        GetWitnessConfig()


    if dispatchSuccessful
        and witnessConfig.Enabled == true
        and witnessConfig.Caller == true
        and #scan.witnesses > 0 then


        callerNetId =
            scan.witnesses[1]
                .netId
    end


    -----------------------------------------------------
    -- CLIENT REACTIONS
    --
    -- Kurban ölür.
    -- Witness varsa kaçar.
    -- Dispatch başarılı + caller varsa telefon anim.
    -----------------------------------------------------

    SendReaction(
        vampireSource,
        victimNetId,
        scan,
        callerNetId
    )


    -----------------------------------------------------
    -- DEBUG
    -----------------------------------------------------

    if Config.Debug then

        print(
            (
                '^5[LB-VAMPIRE]^7 NPC Dispatch Analysis | Witnesses: %s | Peds: %s | Vehicles: %s | Hour: %s'
            ):format(

                tostring(
                    #scan.witnesses
                ),

                tostring(
                    scan.nearbyPeds
                ),

                tostring(
                    scan.nearbyVehicles
                ),

                tostring(
                    hour
                    or 'unknown'
                )
            )
        )


        if dispatchEnabled then


            print(
                (
                    '^5[LB-VAMPIRE]^7 Chance: %s%% | Roll: %s | Dispatch: %s | Base:%s Witness:%s Busy:%s Night:%s Secluded:%s'
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


        else


            print(
                '^3[LB-VAMPIRE]^7 NPC dispatch disabled by config.'
            )
        end
    end


    -----------------------------------------------------
    -- NO DISPATCH
    -----------------------------------------------------

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
                    #scan.witnesses,

                nearbyPeds =
                    scan.nearbyPeds,

                nearbyVehicles =
                    scan.nearbyVehicles
            }
    end


    -----------------------------------------------------
    -- DELAY
    -----------------------------------------------------

    local delayConfig


    if callerNetId then


        delayConfig =
            witnessConfig.CallerDelay
            or {}


    else


        delayConfig =
            dispatchConfig.AnonymousDelay
            or {}
    end


    local defaultMin =
        callerNetId
        and 4000
        or 12000


    local defaultMax =
        callerNetId
        and 10000
        or 25000


    local delay =
        RandomBetween(

            delayConfig.Min
            or defaultMin,

            delayConfig.Max
            or defaultMax
        )


    -----------------------------------------------------
    -- DELAYED DISPATCH
    -----------------------------------------------------

    SetTimeout(
        delay,

        function()


            SendDispatch(
                victimCoords
            )
        end
    )


    -----------------------------------------------------
    -- RESULT
    -----------------------------------------------------

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
                #scan.witnesses,

            nearbyPeds =
                scan.nearbyPeds,

            nearbyVehicles =
                scan.nearbyVehicles
        }
end


---------------------------------------------------------
-- DEBUG NPC DEPLETION
--
-- client/npc_reactions.lua içindeki
-- /vamnpcdeadtest bunu çağırır.
---------------------------------------------------------

RegisterNetEvent(
    'lb-vampire:server:debugDepleteNPC',

    function(
        netId
    )
        -------------------------------------------------
        -- DEBUG ONLY
        -------------------------------------------------

        if Config.Debug ~= true then

            return
        end


        local src =
            source


        -------------------------------------------------
        -- VAMPIRE VALIDATION
        -------------------------------------------------

        if not LBVampire.Vampires
            or not LBVampire.Vampires
                .IsVampire
            or not LBVampire.Vampires
                .IsVampire(
                    src
                ) then


            return
        end


        netId =
            tonumber(
                netId
            )


        if not netId
            or netId <= 0 then


            return
        end


        -------------------------------------------------
        -- ENTITY
        -------------------------------------------------

        local entity =
            NetworkGetEntityFromNetworkId(
                netId
            )


        if not entity
            or entity == 0
            or not DoesEntityExist(
                entity
            ) then


            return
        end


        -------------------------------------------------
        -- PLAYER PED
        -------------------------------------------------

        local playerPed =
            GetPlayerPed(
                src
            )


        if not playerPed
            or playerPed == 0
            or not DoesEntityExist(
                playerPed
            ) then


            return
        end


        -------------------------------------------------
        -- DISTANCE SECURITY
        -------------------------------------------------

        local playerCoords =
            GetEntityCoords(
                playerPed
            )


        local entityCoords =
            GetEntityCoords(
                entity
            )


        local distance =
            Distance(
                playerCoords,
                entityCoords
            )


        if distance >
            5.0 then


            if Config.Debug then

                print(
                    (
                        '^3[LB-VAMPIRE]^7 NPC depletion debug rejected: too far | %.2fm'
                    ):format(
                        distance
                    )
                )
            end


            return
        end


        -------------------------------------------------
        -- NPC BLOOD MODULE
        -------------------------------------------------

        if not LBVampire.NPCBlood
            or not LBVampire.NPCBlood.Set then


            print(
                '^1[LB-VAMPIRE]^7 NPC Blood module unavailable.'
            )


            return
        end


        -------------------------------------------------
        -- BLOOD -> ZERO
        -------------------------------------------------

        local success,
            result =
            LBVampire.NPCBlood.Set(
                netId,
                0
            )


        if success ~= true then


            if Config.Debug then

                print(
                    (
                        '^1[LB-VAMPIRE]^7 NPC depletion failed | Reason: %s'
                    ):format(
                        tostring(
                            result
                        )
                    )
                )
            end


            return
        end


        -------------------------------------------------
        -- WITNESS / REACTION / DISPATCH
        -------------------------------------------------

        NPCWitness.HandleDepletion(
            src,
            netId
        )
    end
)


---------------------------------------------------------
-- EXPORT
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