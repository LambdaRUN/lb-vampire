LBVampire = LBVampire or {}

LBVampire.NPCBlood =
    LBVampire.NPCBlood or {}

LBVampire.Runtime =
    LBVampire.Runtime or {}

LBVampire.Runtime.NPCBlood =
    LBVampire.Runtime.NPCBlood or {}


local NPCBlood =
    LBVampire.NPCBlood


local Runtime =
    LBVampire.Runtime.NPCBlood


---------------------------------------------------------
-- CONFIG
---------------------------------------------------------

local function GetConfig()
    return Config.NPCFeeding
        or {}
end


local function GetBloodConfig()
    return GetConfig().Blood
        or {}
end


local function GetMaximum()
    return tonumber(
        GetBloodConfig().Max
    )
    or 100
end


local function GetDefault()
    return tonumber(
        GetBloodConfig().Default
    )
    or GetMaximum()
end


local function IsRecoveryEnabled()
    local config =
        GetBloodConfig().Recovery
        or {}


    return config.Enabled
        == true
end


local function GetRecoveryIntervalSeconds()
    local config =
        GetBloodConfig().Recovery
        or {}


    local milliseconds =
        tonumber(
            config.Interval
        )
        or 60000


    return math.max(
        math.floor(
            milliseconds / 1000
        ),
        1
    )
end


local function GetRecoveryAmount()
    local config =
        GetBloodConfig().Recovery
        or {}


    return tonumber(
        config.Amount
    )
    or 5
end


---------------------------------------------------------
-- UTILS
---------------------------------------------------------

local function Clamp(
    value,
    minimum,
    maximum
)
    value =
        tonumber(value)
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


---------------------------------------------------------
-- ENTITY
---------------------------------------------------------

local function GetEntityFromNetId(
    netId
)
    netId =
        tonumber(netId)


    if not netId
        or netId <= 0 then

        return nil
    end


    local entity =
        NetworkGetEntityFromNetworkId(
            netId
        )


    if not entity
        or entity == 0
        or not DoesEntityExist(
            entity
        ) then

        return nil
    end


    return entity
end


local function IsValidNPCEntity(
    entity
)
    if not entity
        or entity == 0
        or not DoesEntityExist(
            entity
        ) then

        return false
    end


    -----------------------------------------------------
    -- Entity type 1 = ped.
    -----------------------------------------------------

    if GetEntityType(
        entity
    ) ~= 1 then

        return false
    end


    -----------------------------------------------------
    -- Player ped kabul edilmez.
    -----------------------------------------------------

    if IsPedAPlayer(
        entity
    ) then

        return false
    end


    return true
end


---------------------------------------------------------
-- BLOOD TYPE
---------------------------------------------------------

local function NormalizeBloodType(
    bloodType
)
    if bloodType == nil then
        return nil
    end


    bloodType =
        string.upper(
            tostring(
                bloodType
            )
        )


    bloodType =
        bloodType:gsub(
            '%s+',
            ''
        )


    if bloodType == '' then
        return nil
    end


    return bloodType
end


local function GetAvailableBloodTypes()
    local configured =
        Config.BloodAffinity
        and Config.BloodAffinity.BloodTypes
        or {}


    local types =
        {}


    for i = 1,
        #configured do


        local value =
            NormalizeBloodType(
                configured[i]
            )


        if value then

            types[
                #types + 1
            ] =
                value
        end
    end


    -----------------------------------------------------
    -- Config bozuksa stock fallback.
    -----------------------------------------------------

    if #types <= 0 then

        types = {
            'O+',
            'O-',
            'A+',
            'A-',
            'B+',
            'B-',
            'AB+',
            'AB-'
        }
    end


    return types
end


local function GenerateBloodType()
    local types =
        GetAvailableBloodTypes()


    return types[
        math.random(
            1,
            #types
        )
    ]
end


---------------------------------------------------------
-- RECOVERY
---------------------------------------------------------

local function ApplyRecovery(
    state
)
    if not state then
        return false
    end


    -----------------------------------------------------
    -- Drained NPC asla recover olmaz.
    -----------------------------------------------------

    if state.drained ==
        true then

        return false
    end


    -----------------------------------------------------
    -- 0'a ulaşmış NPC permanent drained kabul edilir.
    -----------------------------------------------------

    if tonumber(
        state.blood
    ) <= 0 then

        return false
    end


    if not IsRecoveryEnabled() then
        return false
    end


    local maximum =
        GetMaximum()


    if state.blood >=
        maximum then

        return false
    end


    -----------------------------------------------------
    -- Aktif feeding sırasında recovery uygulama.
    -----------------------------------------------------

    if state.feedingToken then
        return false
    end


    local now =
        os.time()


    local lastRecoveryAt =
        tonumber(
            state.lastRecoveryAt
        )
        or now


    local elapsed =
        now -
        lastRecoveryAt


    if elapsed <= 0 then
        return false
    end


    local interval =
        GetRecoveryIntervalSeconds()


    local completedIntervals =
        math.floor(
            elapsed /
            interval
        )


    if completedIntervals <= 0 then
        return false
    end


    local amount =
        completedIntervals
        *
        GetRecoveryAmount()


    local previous =
        state.blood


    state.blood =
        Clamp(
            state.blood +
            amount,

            0,

            maximum
        )


    -----------------------------------------------------
    -- Fractional remainder korunur.
    -----------------------------------------------------

    state.lastRecoveryAt =
        lastRecoveryAt
        +
        (
            completedIntervals
            *
            interval
        )


    if state.blood >=
        maximum then


        state.blood =
            maximum


        state.lastRecoveryAt =
            now
    end


    if previous ~=
        state.blood then


        TriggerEvent(
            'lb-vampire:server:npcBloodChanged',

            state.netId,

            previous,

            state.blood,

            state
        )


        return true
    end


    return false
end


---------------------------------------------------------
-- CREATE STATE
---------------------------------------------------------

local function CreateState(
    netId,
    entity
)
    local now =
        os.time()


    local state = {

        netId =
            netId,

        entity =
            entity,

        model =
            GetEntityModel(
                entity
            ),

        blood =
            GetDefault(),

        maxBlood =
            GetMaximum(),

        bloodType =
            GenerateBloodType(),

        drained =
            false,

        feedingToken =
            nil,

        createdAt =
            now,

        lastRecoveryAt =
            now,

        depletedAt =
            nil
    }


    Runtime[
        netId
    ] =
        state


    if Config.Debug then

        print(
            (
                '^2[LB-VAMPIRE]^7 NPC Blood created | NetID: %s | Type: %s | Blood: %.2f'
            ):format(

                tostring(netId),

                tostring(
                    state.bloodType
                ),

                tonumber(
                    state.blood
                )
                or 0
            )
        )
    end


    return state
end


---------------------------------------------------------
-- GET OR CREATE
---------------------------------------------------------

function NPCBlood.GetOrCreate(
    netId
)
    netId =
        tonumber(netId)


    if not netId
        or netId <= 0 then

        return nil,
            'invalid_net_id'
    end


    local existing =
        Runtime[
            netId
        ]


    if existing then

        local entity =
            GetEntityFromNetId(
                netId
            )


        if entity
            and IsValidNPCEntity(
                entity
            ) then


            existing.entity =
                entity


            ApplyRecovery(
                existing
            )


            return existing
        end


        -------------------------------------------------
        -- NetID artık geçerli değil.
        -------------------------------------------------

        Runtime[
            netId
        ] =
            nil
    end


    local entity =
        GetEntityFromNetId(
            netId
        )


    if not entity then

        return nil,
            'entity_not_found'
    end


    if not IsValidNPCEntity(
        entity
    ) then

        return nil,
            'invalid_npc'
    end


    return CreateState(
        netId,
        entity
    )
end


---------------------------------------------------------
-- GET EXISTING
---------------------------------------------------------

function NPCBlood.GetState(
    netId
)
    netId =
        tonumber(netId)


    if not netId then
        return nil
    end


    local state =
        Runtime[
            netId
        ]


    if not state then
        return nil
    end


    ApplyRecovery(
        state
    )


    return state
end


---------------------------------------------------------
-- GET BLOOD
---------------------------------------------------------

function NPCBlood.Get(
    netId
)
    local state,
        reason =
        NPCBlood.GetOrCreate(
            netId
        )


    if not state then

        return nil,
            reason
    end


    return state.blood,
        state
end


---------------------------------------------------------
-- GET BLOOD TYPE
---------------------------------------------------------

function NPCBlood.GetBloodType(
    netId
)
    local state,
        reason =
        NPCBlood.GetOrCreate(
            netId
        )


    if not state then

        return nil,
            reason
    end


    return state.bloodType
end


---------------------------------------------------------
-- SET FEEDING TOKEN
---------------------------------------------------------

function NPCBlood.SetFeedingToken(
    netId,
    token
)
    local state,
        reason =
        NPCBlood.GetOrCreate(
            netId
        )


    if not state then

        return false,
            reason
    end


    state.feedingToken =
        token


    return true
end


---------------------------------------------------------
-- CLEAR FEEDING TOKEN
---------------------------------------------------------

function NPCBlood.ClearFeedingToken(
    netId,
    token
)
    local state =
        NPCBlood.GetState(
            netId
        )


    if not state then
        return false
    end


    if token
        and state.feedingToken
        and state.feedingToken
            ~= token then


        return false
    end


    state.feedingToken =
        nil


    -----------------------------------------------------
    -- Feeding bittikten sonra recovery timer baştan.
    -----------------------------------------------------

    if state.drained ~=
        true
        and state.blood > 0 then


        state.lastRecoveryAt =
            os.time()
    end


    return true
end


---------------------------------------------------------
-- SET
---------------------------------------------------------

function NPCBlood.Set(
    netId,
    amount
)
    local state,
        reason =
        NPCBlood.GetOrCreate(
            netId
        )


    if not state then

        return false,
            reason
    end


    -----------------------------------------------------
    -- Permanent drained NPC geri getirilemez.
    -----------------------------------------------------

    if state.drained ==
        true then

        return false,
            'npc_drained'
    end


    amount =
        tonumber(amount)


    if amount == nil then

        return false,
            'invalid_amount'
    end


    local previous =
        state.blood


    state.blood =
        Clamp(
            amount,

            0,

            GetMaximum()
        )


    state.lastRecoveryAt =
        os.time()


    -----------------------------------------------------
    -- ZERO
    -----------------------------------------------------

    if state.blood <= 0 then

        state.blood =
            0

        state.drained =
            true

        state.depletedAt =
            os.time()

        state.feedingToken =
            nil
    end


    TriggerEvent(
        'lb-vampire:server:npcBloodChanged',

        state.netId,

        previous,

        state.blood,

        state
    )


    -----------------------------------------------------
    -- Separate depletion event.
    --
    -- npc_reactions / witness / dispatch bunun üzerinden
    -- çalışacak.
    -----------------------------------------------------

    if state.drained ==
        true
        and previous > 0 then


        TriggerEvent(
            'lb-vampire:server:npcBloodDepleted',

            state.netId,

            state
        )
    end


    return true,
        state.blood,
        state
end


---------------------------------------------------------
-- ADD
---------------------------------------------------------

function NPCBlood.Add(
    netId,
    amount
)
    amount =
        tonumber(amount)


    if not amount
        or amount < 0 then

        return false,
            'invalid_amount'
    end


    local current,
        stateOrReason =
        NPCBlood.Get(
            netId
        )


    if current == nil then

        return false,
            stateOrReason
    end


    return NPCBlood.Set(
        netId,
        current + amount
    )
end


---------------------------------------------------------
-- REMOVE
---------------------------------------------------------

function NPCBlood.Remove(
    netId,
    amount
)
    amount =
        tonumber(amount)


    if not amount
        or amount < 0 then

        return false,
            'invalid_amount'
    end


    local current,
        stateOrReason =
        NPCBlood.Get(
            netId
        )


    if current == nil then

        return false,
            stateOrReason
    end


    return NPCBlood.Set(
        netId,
        current - amount
    )
end


---------------------------------------------------------
-- IS DRAINED
---------------------------------------------------------

function NPCBlood.IsDrained(
    netId
)
    local state =
        NPCBlood.GetState(
            netId
        )


    return state
        and state.drained
        == true
        or false
end


---------------------------------------------------------
-- REMOVE STATE
---------------------------------------------------------

function NPCBlood.RemoveState(
    netId
)
    netId =
        tonumber(netId)


    if not netId then
        return false
    end


    Runtime[
        netId
    ] =
        nil


    return true
end


---------------------------------------------------------
-- PERIODIC RECOVERY + CLEANUP
---------------------------------------------------------

CreateThread(function()

    while true do


        local runtimeConfig =
            GetConfig().Runtime
            or {}


        local interval =
            tonumber(
                runtimeConfig.CleanupInterval
            )
            or 60000


        Wait(
            math.max(
                interval,
                5000
            )
        )


        local toRemove =
            {}


        for netId,
            state in pairs(
                Runtime
            ) do


            local entity =
                GetEntityFromNetId(
                    netId
                )


            -------------------------------------------------
            -- ENTITY CLEANUP
            -------------------------------------------------

            if not entity
                or not IsValidNPCEntity(
                    entity
                ) then


                if runtimeConfig
                    .RemoveMissingEntities
                    ~= false then


                    toRemove[
                        #toRemove + 1
                    ] =
                        netId
                end


            else


                state.entity =
                    entity


                ApplyRecovery(
                    state
                )
            end
        end


        for i = 1,
            #toRemove do


            Runtime[
                toRemove[i]
            ] =
                nil
        end
    end
end)


---------------------------------------------------------
-- DEBUG
---------------------------------------------------------

if Config.Debug then

    RegisterCommand(
        'vamnpcbloodcount',
        function(source)

            local count =
                0


            for _ in pairs(
                Runtime
            ) do

                count =
                    count + 1
            end


            local message =
                (
                    'NPC Blood runtime count: %s'
                ):format(
                    count
                )


            if source > 0 then

                TriggerClientEvent(
                    'QBCore:Notify',
                    source,
                    message,
                    'primary',
                    5000
                )
            end


            print(
                '^5[LB-VAMPIRE]^7 '
                .. message
            )
        end,

        false
    )
end