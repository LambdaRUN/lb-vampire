LBVampire = LBVampire or {}

LBVampire.Vampires =
    LBVampire.Vampires or {}

LBVampire.Runtime =
    LBVampire.Runtime or {}

LBVampire.Runtime.Vampires =
    LBVampire.Runtime.Vampires or {}

LBVampire.Runtime.SourceToCitizen =
    LBVampire.Runtime.SourceToCitizen or {}

LBVampire.Runtime.TransitionLocks =
    LBVampire.Runtime.TransitionLocks or {}


---------------------------------------------------------
-- TRANSITION LOCKS
---------------------------------------------------------

local function BeginTransition(
    source
)
    source =
        tonumber(source)

    if not source then
        return nil,
            'invalid_source'
    end


    local citizenId =
        LBVampire.Framework.GetCitizenId(
            source
        )
        or LBVampire.Runtime.SourceToCitizen[
            source
        ]


    if not citizenId then
        return nil,
            'player_not_found'
    end


    if LBVampire.Runtime
        .TransitionLocks[citizenId] then

        return nil,
            'state_busy'
    end


    LBVampire.Runtime
        .TransitionLocks[citizenId] =
        true


    return citizenId
end


local function EndTransition(
    citizenId
)
    if not citizenId then
        return
    end


    LBVampire.Runtime
        .TransitionLocks[citizenId] =
        nil
end


function LBVampire.Vampires.IsTransitioning(
    source
)
    source =
        tonumber(source)

    if not source then
        return false
    end


    local citizenId =
        LBVampire.Framework.GetCitizenId(
            source
        )
        or LBVampire.Runtime.SourceToCitizen[
            source
        ]


    if not citizenId then
        return false
    end


    return LBVampire.Runtime
        .TransitionLocks[citizenId]
        == true
end


---------------------------------------------------------
-- HELPERS
---------------------------------------------------------

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


local function SyncBlood(
    source
)
    if LBVampire.Blood
        and LBVampire.Blood.Sync then

        LBVampire.Blood.Sync(
            source
        )
    end
end

---------------------------------------------------------
-- ENSURE BLOOD AFFINITY
---------------------------------------------------------

local function EnsureBloodAffinity(
    source,
    citizenId
)
    source =
        tonumber(source)


    if not source then

        return false,
            'invalid_source'
    end


    -----------------------------------------------------
    -- Affinity module vampire core'u bloke etmemeli.
    --
    -- Module herhangi bir sebeple hazır değilse
    -- vampire load yine başarılı olur.
    -----------------------------------------------------

    if not LBVampire.BloodAffinity
        or not LBVampire.BloodAffinity
            .EnsurePreference then


        if Config.Debug then

            print(
                (
                    '^3[LB-VAMPIRE]^7 Blood affinity module unavailable | Citizen: %s'
                ):format(
                    tostring(
                        citizenId
                        or 'unknown'
                    )
                )
            )
        end


        return false,
            'affinity_module_unavailable'
    end


    -----------------------------------------------------
    -- Affinity'deki bir hata karakterin vampire olarak
    -- yüklenmesini engellemesin.
    -----------------------------------------------------

    local callSuccess,
        affinitySuccess,
        result =
        pcall(
            function()

                return LBVampire.BloodAffinity
                    .EnsurePreference(
                        source
                    )
            end
        )


    if not callSuccess then

        if Config.Debug then

            print(
                (
                    '^1[LB-VAMPIRE]^7 Blood affinity ensure error | Citizen: %s | Error: %s'
                ):format(

                    tostring(
                        citizenId
                        or 'unknown'
                    ),

                    tostring(
                        affinitySuccess
                    )
                )
            )
        end


        return false,
            'affinity_error'
    end


    if affinitySuccess ~= true then

        if Config.Debug then

            print(
                (
                    '^3[LB-VAMPIRE]^7 Blood affinity ensure failed | Citizen: %s | Reason: %s'
                ):format(

                    tostring(
                        citizenId
                        or 'unknown'
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
                '^2[LB-VAMPIRE]^7 Blood affinity ready | Citizen: %s | Preferred: %s'
            ):format(

                tostring(
                    citizenId
                    or 'unknown'
                ),

                tostring(
                    result
                )
            )
        )
    end


    return true,
        result
end

---------------------------------------------------------
-- GET STATE
---------------------------------------------------------

function LBVampire.Vampires.GetStateByCitizenId(
    citizenId
)
    if not citizenId then
        return nil
    end


    return LBVampire.Runtime.Vampires[
        citizenId
    ]
end


function LBVampire.Vampires.GetState(
    source
)
    source =
        tonumber(source)

    if not source then
        return nil
    end


    local citizenId =
        LBVampire.Runtime.SourceToCitizen[
            source
        ]
        or LBVampire.Framework.GetCitizenId(
            source
        )


    if not citizenId then
        return nil
    end


    return LBVampire.Runtime.Vampires[
        citizenId
    ]
end


function LBVampire.Vampires.IsVampire(
    source
)
    return LBVampire.Vampires.GetState(
        source
    ) ~= nil
end


---------------------------------------------------------
-- LOAD PLAYER
---------------------------------------------------------

function LBVampire.Vampires.LoadPlayer(
    source
)
    source =
        tonumber(source)

    if not source then
        return false,
            'invalid_source'
    end


    -----------------------------------------------------
    -- CHARACTER
    -----------------------------------------------------

    local citizenId =
        LBVampire.Framework.GetCitizenId(
            source
        )


    if not citizenId then
        return false,
            'player_not_loaded'
    end


    -----------------------------------------------------
    -- SOURCE PREVIOUSLY BELONGED TO ANOTHER CHARACTER
    -----------------------------------------------------

    local previousCitizen =
        LBVampire.Runtime.SourceToCitizen[
            source
        ]


    if previousCitizen
        and previousCitizen ~= citizenId then


        local previousState =
            LBVampire.Runtime.Vampires[
                previousCitizen
            ]


        if previousState
            and previousState.dirty then

            LBVampire.Persistence
                .SaveRuntimeState(
                    previousState
                )
        end


        LBVampire.Runtime.Vampires[
            previousCitizen
        ] = nil
    end


    -----------------------------------------------------
    -- SOURCE -> CITIZEN
    -----------------------------------------------------

    LBVampire.Runtime.SourceToCitizen[
        source
    ] = citizenId


    -----------------------------------------------------
    -- EXISTING RUNTIME
    -----------------------------------------------------

    local existingRuntime =
        LBVampire.Runtime.Vampires[
            citizenId
        ]


    if existingRuntime then

        existingRuntime.source =
            source


        SyncBlood(
            source
        )


        -----------------------------------------------------
        -- Vampire runtime zaten varsa bile affinity'nin
        -- mevcut olduğundan emin ol.
        -----------------------------------------------------

        EnsureBloodAffinity(
            source,
            citizenId
        )


        return true,
            existingRuntime
    end


    -----------------------------------------------------
    -- DATABASE
    -----------------------------------------------------

    local databaseState =
        LBVampire.Persistence.GetVampire(
            citizenId
        )


    -----------------------------------------------------
    -- HUMAN CHARACTER
    -----------------------------------------------------

    if not databaseState
        or not databaseState.is_vampire then


        --
        -- Her ihtimale karşı stale runtime temizlenir.
        --
        LBVampire.Runtime.Vampires[
            citizenId
        ] = nil


        --
        -- Client'ta eski vampire Blood/HUD state'i
        -- kalmışsa human state'e zorla.
        --
        SyncBlood(
            source
        )


        if Config.Debug then

            print(
                (
                    '^3[LB-VAMPIRE]^7 Character is not vampire: %s'
                ):format(
                    citizenId
                )
            )
        end


        return false,
            'not_vampire'
    end


    -----------------------------------------------------
    -- DATABASE VAMPIRE -> RUNTIME STATE
    -----------------------------------------------------

    local state = {

        source =
            source,

        citizenId =
            citizenId,


        blood =
            Clamp(
                databaseState.blood,
                0,
                tonumber(
                    Config.Blood.Max
                ) or 100
            ),


        sireCitizenId =
            databaseState.sire_citizenid,


        canEmbrace =
            databaseState.can_embrace == 1
            or databaseState.can_embrace == true,


        embracedAt =
            databaseState.embraced_at,


        -------------------------------------------------
        -- INTERACTION
        -------------------------------------------------

        interactionState =
            'IDLE',


        -------------------------------------------------
        -- SUN
        -------------------------------------------------

        sunState =
            'SAFE',

        sunDrainProgress =
            0.0,


        -------------------------------------------------
        -- ABILITIES / FUTURE
        -------------------------------------------------

        beastCallCooldown =
            0,


        -------------------------------------------------
        -- BLOOD THRESHOLDS
        -------------------------------------------------

        thresholdFlags =
            {},


        -------------------------------------------------
        -- PERSISTENCE
        -------------------------------------------------

        dirty =
            false
    }


    -----------------------------------------------------
    -- STORE RUNTIME
    -----------------------------------------------------

    LBVampire.Runtime.Vampires[
        citizenId
    ] = state


    if Config.Debug then

        print(
            (
                '^5[LB-VAMPIRE]^7 Vampire loaded: %s | Blood: %.2f'
            ):format(
                citizenId,
                state.blood
            )
        )
    end


    -----------------------------------------------------
    -- CLIENT SYNC
    -----------------------------------------------------

    SyncBlood(
        source
    )


    -----------------------------------------------------
    -- BLOOD AFFINITY
    --
    -- Vampire karakter load edildiği anda persistent
    -- affinity garanti edilir.
    -----------------------------------------------------

    EnsureBloodAffinity(
        source,
        citizenId
    )


    return true,
        state
    end


---------------------------------------------------------
-- UNLOAD PLAYER
---------------------------------------------------------

function LBVampire.Vampires.UnloadPlayer(
    source,
    skipSave
)
    source =
        tonumber(source)

    if not source then
        return
    end


    local citizenId =
        LBVampire.Runtime.SourceToCitizen[
            source
        ]


    if not citizenId then

        --
        -- Source mapping yoksa yine de client
        -- tarafındaki eski vampire state'i temizle.
        --
        SyncBlood(
            source
        )

        return
    end


    local state =
        LBVampire.Runtime.Vampires[
            citizenId
        ]


    -----------------------------------------------------
    -- SAVE
    -----------------------------------------------------

    if state
        and state.dirty
        and not skipSave then


        local success =
            LBVampire.Persistence
                .SaveRuntimeState(
                    state
                )


        if success then
            state.dirty =
                false
        end
    end


    -----------------------------------------------------
    -- CLEAR RUNTIME
    -----------------------------------------------------

    LBVampire.Runtime.Vampires[
        citizenId
    ] = nil


    LBVampire.Runtime.SourceToCitizen[
        source
    ] = nil


    if Config.Debug then

        print(
            (
                '^5[LB-VAMPIRE]^7 Runtime unloaded: %s'
            ):format(
                citizenId
            )
        )
    end


    -----------------------------------------------------
    -- CLIENT HUMAN SYNC
    -----------------------------------------------------

    SyncBlood(
        source
    )


    return true
end


---------------------------------------------------------
-- SET VAMPIRE
---------------------------------------------------------

function LBVampire.Vampires.SetPlayerVampire(
    source
)
    source =
        tonumber(source)

    if not source then
        return false,
            'invalid_source'
    end


    -----------------------------------------------------
    -- LOCK
    -----------------------------------------------------

    local citizenId,
        lockError =
        BeginTransition(
            source
        )


    if not citizenId then
        return false,
            lockError
    end


    -----------------------------------------------------
    -- DATABASE STATE
    -----------------------------------------------------

    local existing =
        LBVampire.Persistence.GetVampire(
            citizenId
        )


    -----------------------------------------------------
    -- ALREADY VAMPIRE
    -----------------------------------------------------

    if existing
        and existing.is_vampire then


        --
        -- DB vampire diyorsa runtime/client tarafını
        -- aynı authoritative state'e zorla.
        --
        local loaded,
            result =
            LBVampire.Vampires.LoadPlayer(
                source
            )


        EndTransition(
            citizenId
        )


        if not loaded then

            return false,
                result
                or 'runtime_load_failed'
        end


        return false,
            'already_vampire',
            result
    end


    -----------------------------------------------------
    -- ACTIVATE DATABASE
    -----------------------------------------------------

    local success =
        LBVampire.Persistence
            .ActivateVampire(
                citizenId
            )


    if not success then

        EndTransition(
            citizenId
        )


        return false,
            'database_error'
    end


    -----------------------------------------------------
    -- LOAD NEW RUNTIME STATE
    -----------------------------------------------------

    local loaded,
        result =
        LBVampire.Vampires.LoadPlayer(
            source
        )


    EndTransition(
        citizenId
    )


    if not loaded then

        return false,
            result
            or 'runtime_load_failed'
    end


    return true,
        result
end


---------------------------------------------------------
-- REMOVE VAMPIRE
---------------------------------------------------------

function LBVampire.Vampires.RemovePlayerVampire(
    source
)
    source =
        tonumber(source)

    if not source then
        return false,
            'invalid_source'
    end


    -----------------------------------------------------
    -- LOCK
    -----------------------------------------------------

    local citizenId,
        lockError =
        BeginTransition(
            source
        )


    if not citizenId then
        return false,
            lockError
    end


    -----------------------------------------------------
    -- DATABASE
    -----------------------------------------------------

    local databaseState =
        LBVampire.Persistence.GetVampire(
            citizenId
        )


    -----------------------------------------------------
    -- ALREADY HUMAN
    -----------------------------------------------------

    if not databaseState
        or not databaseState.is_vampire then


        --
        -- DB insan diyorsa stale runtime varsa
        -- temizlenir.
        --
        LBVampire.Vampires.UnloadPlayer(
            source,
            true
        )


        SyncBlood(
            source
        )


        EndTransition(
            citizenId
        )


        return false,
            'not_vampire'
    end


    -----------------------------------------------------
    -- DATABASE DEACTIVATE
    -----------------------------------------------------

    local success =
        LBVampire.Persistence
            .DeactivateVampire(
                citizenId
            )


    if not success then

        EndTransition(
            citizenId
        )


        return false,
            'database_error'
    end


    -----------------------------------------------------
    -- REMOVE RUNTIME
    -----------------------------------------------------

    LBVampire.Vampires.UnloadPlayer(
        source,
        true
    )


    SyncBlood(
        source
    )


    EndTransition(
        citizenId
    )


    return true
end


---------------------------------------------------------
-- SET BLOOD
---------------------------------------------------------

function LBVampire.Vampires.SetBlood(
    source,
    amount
)
    if not LBVampire.Blood
        or not LBVampire.Blood.Set then


        return false,
            'blood_module_unavailable'
    end


    return LBVampire.Blood.Set(
        source,
        amount,
        true
    )
end


---------------------------------------------------------
-- EMBRACE PERMISSION
---------------------------------------------------------

function LBVampire.Vampires.SetEmbracePermission(
    source,
    enabled
)
    source =
        tonumber(source)


    if not source
        or type(enabled)
            ~= 'boolean' then


        return false,
            'invalid_arguments'
    end


    local state =
        LBVampire.Vampires.GetState(
            source
        )


    if not state then
        return false,
            'not_vampire'
    end


    local previousValue =
        state.canEmbrace


    state.canEmbrace =
        enabled


    -----------------------------------------------------
    -- IMMEDIATE SAVE
    -----------------------------------------------------

    local success =
        LBVampire.Persistence
            .SaveRuntimeState(
                state
            )


    if not success then

        state.canEmbrace =
            previousValue


        return false,
            'database_error'
    end


    state.dirty =
        false


    return true,
        state,
        previousValue
end


---------------------------------------------------------
-- RESTORE
--
-- IMPORTANT:
-- Restore HUMANIZE ETMEZ.
--
-- Runtime state tamamen temizlenir ve
-- authoritative database state tekrar yüklenir.
---------------------------------------------------------

function LBVampire.Vampires.RestorePlayer(
    source
)
    source =
        tonumber(source)

    if not source then
        return false,
            'invalid_source'
    end


    -----------------------------------------------------
    -- LOCK
    -----------------------------------------------------

    local citizenId,
        lockError =
        BeginTransition(
            source
        )


    if not citizenId then
        return false,
            lockError
    end


    -----------------------------------------------------
    -- DATABASE STATE
    -----------------------------------------------------

    local databaseState =
        LBVampire.Persistence.GetVampire(
            citizenId
        )


    -----------------------------------------------------
    -- DATABASE SAYS HUMAN
    -----------------------------------------------------

    if not databaseState
        or not databaseState.is_vampire then


        LBVampire.Vampires.UnloadPlayer(
            source,
            true
        )


        SyncBlood(
            source
        )


        EndTransition(
            citizenId
        )


        return false,
            'not_vampire'
    end


    -----------------------------------------------------
    -- DATABASE SAYS VAMPIRE
    --
    -- Existing runtime is discarded WITHOUT save.
    -----------------------------------------------------

    LBVampire.Vampires.UnloadPlayer(
        source,
        true
    )


    -----------------------------------------------------
    -- REBUILD FROM DATABASE
    -----------------------------------------------------

    local loaded,
        result =
        LBVampire.Vampires.LoadPlayer(
            source
        )


    if loaded then

        SyncBlood(
            source
        )
    end


    EndTransition(
        citizenId
    )


    if not loaded then

        return false,
            result
            or 'runtime_load_failed'
    end


    return true,
        result
end


---------------------------------------------------------
-- FRAMEWORK PLAYER LOADED
---------------------------------------------------------

AddEventHandler(
    'lb-vampire:server:frameworkPlayerLoaded',
    function(source)

        LBVampire.Vampires.LoadPlayer(
            source
        )
    end
)


---------------------------------------------------------
-- FRAMEWORK PLAYER UNLOADED
---------------------------------------------------------

AddEventHandler(
    'lb-vampire:server:frameworkPlayerUnloaded',
    function(source)

        LBVampire.Vampires.UnloadPlayer(
            source
        )
    end
)


---------------------------------------------------------
-- PLAYER DROPPED
---------------------------------------------------------

AddEventHandler(
    'playerDropped',
    function()

        LBVampire.Vampires.UnloadPlayer(
            source
        )
    end
)


---------------------------------------------------------
-- RESOURCE START
--
-- Resource restart edildiğinde zaten online olan
-- oyuncuları tekrar runtime'a yükle.
---------------------------------------------------------

CreateThread(function()

    Wait(
        1500
    )


    local players =
        GetPlayers()


    for _, playerSource in ipairs(
        players
    ) do

        LBVampire.Vampires.LoadPlayer(
            tonumber(
                playerSource
            )
        )
    end
end)


---------------------------------------------------------
-- PERIODIC DIRTY SAVE
---------------------------------------------------------

CreateThread(function()

    local interval =
        tonumber(
            Config.Persistence.SaveInterval
        )
        or 60000


    interval =
        math.max(
            interval,
            10000
        )


    while true do

        Wait(
            interval
        )


        for citizenId,
            state in pairs(
                LBVampire.Runtime.Vampires
            ) do


            if state.dirty then


                local success =
                    LBVampire.Persistence
                        .SaveRuntimeState(
                            state
                        )


                if success then

                    state.dirty =
                        false


                    if Config.Debug then

                        print(
                            (
                                '^5[LB-VAMPIRE]^7 Dirty state saved: %s'
                            ):format(
                                citizenId
                            )
                        )
                    end
                end
            end
        end
    end
end)


---------------------------------------------------------
-- RESOURCE STOP SAVE
---------------------------------------------------------

AddEventHandler(
    'onResourceStop',
    function(resourceName)

        if resourceName
            ~= GetCurrentResourceName() then

            return
        end


        for _,
            state in pairs(
                LBVampire.Runtime.Vampires
            ) do


            if state.dirty then

                LBVampire.Persistence
                    .SaveRuntimeState(
                        state
                    )
            end
        end
    end
)