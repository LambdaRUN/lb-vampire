LBVampire = LBVampire or {}
LBVampire.HumanBlood = LBVampire.HumanBlood or {}

LBVampire.Runtime =
    LBVampire.Runtime or {}

LBVampire.Runtime.HumanBlood =
    LBVampire.Runtime.HumanBlood or {}


local HumanBlood =
    LBVampire.HumanBlood


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

    if value < minimum then
        return minimum
    end

    if value > maximum then
        return maximum
    end

    return value
end


local function GetMaximum()
    return tonumber(
        Config.HumanBlood
            and Config.HumanBlood.Max
    ) or 100
end


local function GetDefault()
    return tonumber(
        Config.HumanBlood
            and Config.HumanBlood.Default
    ) or GetMaximum()
end


local function GetRecoveryIntervalSeconds()
    local interval =
        tonumber(
            Config.HumanBlood
                and Config.HumanBlood.Recovery
                and Config.HumanBlood.Recovery.Interval
        )
        or (5 * 60 * 1000)

    return math.max(
        math.floor(
            interval / 1000
        ),
        1
    )
end


local function GetRecoveryAmount()
    return tonumber(
        Config.HumanBlood
            and Config.HumanBlood.Recovery
            and Config.HumanBlood.Recovery.Amount
    ) or 5
end


local function IsRecoveryEnabled()
    return Config.HumanBlood
        and Config.HumanBlood.Recovery
        and Config.HumanBlood.Recovery.Enabled
            == true
end


---------------------------------------------------------
-- CITIZEN ID
---------------------------------------------------------

local function GetCitizenId(
    source
)
    source =
        tonumber(source)

    if not source then
        return nil
    end

    if not LBVampire.Framework
        or not LBVampire.Framework.GetCitizenId then

        return nil
    end

    return LBVampire.Framework.GetCitizenId(
        source
    )
end


local function SyncState(
    state
)
    if not state
        or not state.source
        or not GetPlayerName(
            state.source
        ) then

        return
    end

    local hudConfig =
        Config.HumanBlood
        and Config.HumanBlood.HUD
        or {}

    local thresholds =
        hudConfig.Thresholds
        or {}

    TriggerClientEvent(
        'lb-vampire:client:humanBloodSync',
        state.source,
        {
            blood =
                tonumber(
                    state.blood
                )
                or GetDefault(),

            maxBlood =
                GetMaximum(),

            lowThreshold =
                tonumber(
                    thresholds.Low
                )
                or 70,

            criticalThreshold =
                tonumber(
                    thresholds.Critical
                )
                or 40,

            severeThreshold =
                tonumber(
                    thresholds.Severe
                )
                or 20
        }
    )
end

---------------------------------------------------------
-- CLIENT SYNC REQUEST
---------------------------------------------------------



---------------------------------------------------------
-- SAVE
---------------------------------------------------------

local function SaveState(
    state
)
    if not state
        or not state.citizenId then

        return false
    end


    local maxBlood =
        GetMaximum()


    state.blood =
        Clamp(
            state.blood,
            0,
            maxBlood
        )


    -----------------------------------------------------
    -- DEFAULT STATE
    --
    -- HumanBlood tekrar 100 olduğunda DB'de bu satırı
    -- tutmaya gerek yok.
    --
    -- Row yok = HumanBlood 100.
    -----------------------------------------------------

    if state.blood >= maxBlood then

        MySQL.update.await(
            [[
                DELETE FROM vampire_human_state
                WHERE citizenid = ?
            ]],
            {
                state.citizenId
            }
        )


        state.blood =
            maxBlood

        state.dirty =
            false

        return true
    end


    -----------------------------------------------------
    -- NON-DEFAULT STATE
    -----------------------------------------------------

    local recoveryTimestamp =
        tonumber(
            state.lastRecoveryAt
        )
        or os.time()


    MySQL.query.await(
        [[
            INSERT INTO vampire_human_state
            (
                citizenid,
                blood_volume,
                last_recovery_at
            )
            VALUES
            (
                ?,
                ?,
                FROM_UNIXTIME(?)
            )

            ON DUPLICATE KEY UPDATE

                blood_volume =
                    VALUES(blood_volume),

                last_recovery_at =
                    VALUES(last_recovery_at)
        ]],
        {
            state.citizenId,
            state.blood,
            recoveryTimestamp
        }
    )


    state.dirty =
        false

    return true
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


    if not IsRecoveryEnabled() then
        return false
    end


    local maxBlood =
        GetMaximum()


    if state.blood >= maxBlood then
        return false
    end

        -----------------------------------------------------
    -- ZERO BLOOD RECOVERY LOCK
    --
    -- HumanBlood 0'a ulaştığında doğal recovery durur.
    -- Oyuncunun tekrar recovery alabilmesi için önce
    -- blood bag / EMS / explicit treatment ile 0'ın
    -- üzerine çıkarılması gerekir.
    -----------------------------------------------------

    if state.blood <= 0 then
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
            elapsed / interval
        )


    if completedIntervals <= 0 then
        return false
    end


    local recoveryAmount =
        GetRecoveryAmount()


    local amountToRecover =
        completedIntervals *
        recoveryAmount


    local previousBlood =
        state.blood


    state.blood =
        Clamp(
            state.blood +
            amountToRecover,

            0,
            maxBlood
        )


    -----------------------------------------------------
    -- Önemli:
    --
    -- lastRecoveryAt = os.time() yapmıyoruz.
    --
    -- Kullanılmayan saniye/dakika kısmı kaybolmasın.
    -----------------------------------------------------

    state.lastRecoveryAt =
        lastRecoveryAt +
        (
            completedIntervals *
            interval
        )


    if state.blood >= maxBlood then
        state.blood =
            maxBlood

        state.lastRecoveryAt =
            now
    end


    if state.blood ~= previousBlood then

        state.dirty =
            true

        SyncState(
            state
        )

        if Config.Debug then

            print(
                (
                    '^5[LB-VAMPIRE]^7 HumanBlood recovery: %s | %.2f -> %.2f'
                ):format(
                    state.citizenId,
                    previousBlood,
                    state.blood
                )
            )
        end

        return true
    end


    return false
end


---------------------------------------------------------
-- LOAD
---------------------------------------------------------

function HumanBlood.Load(
    source
)
    source =
        tonumber(source)

    if not source then
        return nil, 'invalid_source'
    end


    local citizenId =
        GetCitizenId(
            source
        )


    if not citizenId then
        return nil, 'player_not_found'
    end


    -----------------------------------------------------
    -- ALREADY CACHED
    -----------------------------------------------------

    local cached =
        LBVampire.Runtime
            .HumanBlood[citizenId]


    if cached then

        cached.source =
            source


        ApplyRecovery(
            cached
        )


        return cached
    end


    -----------------------------------------------------
    -- DATABASE
    -----------------------------------------------------

    local row =
        MySQL.single.await(
            [[
                SELECT
                    citizenid,
                    blood_volume,

                    COALESCE(
                        UNIX_TIMESTAMP(last_recovery_at),
                        UNIX_TIMESTAMP(updated_at),
                        UNIX_TIMESTAMP()
                    ) AS last_recovery_unix

                FROM vampire_human_state

                WHERE citizenid = ?

                LIMIT 1
            ]],
            {
                citizenId
            }
        )


    local state


    if row then

        state = {
            source =
                source,

            citizenId =
                citizenId,

            blood =
                Clamp(
                    row.blood_volume,
                    0,
                    GetMaximum()
                ),

            lastRecoveryAt =
                tonumber(
                    row.last_recovery_unix
                )
                or os.time(),

            dirty =
                false
        }


    else

        -------------------------------------------------
        -- Row yok = default HumanBlood.
        -------------------------------------------------

        state = {
            source =
                source,

            citizenId =
                citizenId,

            blood =
                GetDefault(),

            lastRecoveryAt =
                os.time(),

            dirty =
                false
        }
    end


    LBVampire.Runtime
        .HumanBlood[citizenId] =
        state


    -----------------------------------------------------
    -- Offline recovery burada hesaplanır.
    -----------------------------------------------------

    local recovered =
        ApplyRecovery(
            state
        )


    if recovered then
        SaveState(
            state
        )
    end

    TriggerEvent(
        'lb-vampire:server:humanBloodLoaded',

        state.source,

        state.citizenId,

        state.blood
    )



    return state
end


---------------------------------------------------------
-- GET STATE
---------------------------------------------------------

function HumanBlood.GetState(
    source
)
    return HumanBlood.Load(
        source
    )
end


---------------------------------------------------------
-- GET VALUE
---------------------------------------------------------

function HumanBlood.Get(
    source
)
    local state,
        reason =
        HumanBlood.Load(
            source
        )


    if not state then
        return nil,
            reason
    end


    ApplyRecovery(
        state
    )


    return state.blood
end


---------------------------------------------------------
-- SET
---------------------------------------------------------

function HumanBlood.Set(
    source,
    amount,
    immediateSave
)
    local state,
        reason =
        HumanBlood.Load(
            source
        )


    if not state then
        return false,
            reason
    end


    amount =
        tonumber(amount)


    if not amount then
        return false,
            'invalid_amount'
    end

    local previousBlood =
    tonumber(
        state.blood
    )
    or GetDefault()

    state.blood =
        Clamp(
            amount,
            0,
            GetMaximum()
        )


    -----------------------------------------------------
    -- Kan değiştiği an recovery timer yeniden başlar.
    -----------------------------------------------------

    state.lastRecoveryAt =
        os.time()


    state.dirty =
        true
    SyncState(
        state
    )

    TriggerEvent(
        'lb-vampire:server:humanBloodChanged',

        state.source,

        state.citizenId,

        previousBlood,

        state.blood
    )

    if immediateSave == true then
        SaveState(
            state
        )
    end


    return true,
        state.blood
end


---------------------------------------------------------
-- ADD
---------------------------------------------------------

function HumanBlood.Add(
    source,
    amount,
    immediateSave
)
    amount =
        tonumber(amount)


    if not amount then
        return false,
            'invalid_amount'
    end


    local current,
        reason =
        HumanBlood.Get(
            source
        )


    if current == nil then
        return false,
            reason
    end


    return HumanBlood.Set(
        source,
        current + amount,
        immediateSave
    )
end


---------------------------------------------------------
-- REMOVE
---------------------------------------------------------

function HumanBlood.Remove(
    source,
    amount,
    immediateSave
)
    amount =
        tonumber(amount)


    if not amount then
        return false,
            'invalid_amount'
    end


    if amount < 0 then
        return false,
            'invalid_amount'
    end


    local current,
        reason =
        HumanBlood.Get(
            source
        )


    if current == nil then
        return false,
            reason
    end


    return HumanBlood.Set(
        source,
        current - amount,
        immediateSave
    )
end


---------------------------------------------------------
-- SAVE BY SOURCE
---------------------------------------------------------

function HumanBlood.Save(
    source
)
    source =
        tonumber(source)


    local citizenId =
        GetCitizenId(
            source
        )


    if not citizenId then
        return false
    end


    local state =
        LBVampire.Runtime
            .HumanBlood[citizenId]


    if not state then
        return true
    end


    ApplyRecovery(
        state
    )


    return SaveState(
        state
    )
end


---------------------------------------------------------
-- UNLOAD
---------------------------------------------------------

function HumanBlood.Unload(
    source
)
    source =
        tonumber(source)


    if not source then
        return
    end


    for citizenId, state in pairs(
        LBVampire.Runtime.HumanBlood
    ) do

        if state.source == source then

            ApplyRecovery(
                state
            )


            if state.dirty then
                SaveState(
                    state
                )
            end


            LBVampire.Runtime
                .HumanBlood[citizenId] =
                nil


            return
        end
    end
end


---------------------------------------------------------
-- PERIODIC RECOVERY + SAVE
---------------------------------------------------------

CreateThread(function()

    local saveInterval =
        tonumber(
            Config.HumanBlood
                and Config.HumanBlood.Runtime
                and Config.HumanBlood.Runtime.SaveInterval
        )
        or 60000


    while true do

        Wait(
            saveInterval
        )


        for _, state in pairs(
            LBVampire.Runtime.HumanBlood
        ) do

            ApplyRecovery(
                state
            )


            if state.dirty then
                SaveState(
                    state
                )
            end
        end
    end
end)


RegisterNetEvent(
    'lb-vampire:server:requestHumanBloodSync',
    function()

        local playerSource =
            tonumber(source)

        if not playerSource then
            return
        end

        local state =
            HumanBlood.Load(
                playerSource
            )

        if not state then
            return
        end

        ApplyRecovery(
            state
        )

        SyncState(
            state
        )
    end
)

---------------------------------------------------------
-- PLAYER DROP
---------------------------------------------------------

AddEventHandler(
    'playerDropped',
    function()

        local playerSource =
            source


        HumanBlood.Unload(
            playerSource
        )
    end
)


---------------------------------------------------------
-- RESOURCE STOP
---------------------------------------------------------

AddEventHandler(
    'onResourceStop',
    function(resourceName)

        if resourceName
            ~= GetCurrentResourceName() then

            return
        end


        for _, state in pairs(
            LBVampire.Runtime.HumanBlood
        ) do

            ApplyRecovery(
                state
            )


            if state.dirty then
                SaveState(
                    state
                )
            end
        end
    end
)

AddEventHandler(
            'lb-vampire:server:frameworkPlayerLoaded',
            function(source)

                CreateThread(function()

                    Wait(1000)

                    if not GetPlayerName(source) then
                        return
                    end

                    local state =
                        LBVampire.HumanBlood.Load(
                            source
                        )

                    if not state then
                        return
                    end

                    SyncState(
                        state
                    )
                end)
            end
        )


---------------------------------------------------------
-- DEVELOPMENT COMMAND
---------------------------------------------------------

RegisterCommand(
    'vamhblood',
    function(
        source,
        args
    )

        if not Config.Debug then
            return
        end


        if source <= 0 then

            print(
                '[LB-VAMPIRE] /vamhblood must be used by a player.'
            )

            return
        end


        local action =
            args[1]
            and string.lower(
                args[1]
            )
            or 'inspect'


        -------------------------------------------------
        -- INSPECT
        -------------------------------------------------

        if action == 'inspect' then

            local state,
                reason =
                HumanBlood.GetState(
                    source
                )


            if not state then

                print(
                    (
                        '[LB-VAMPIRE] HumanBlood error: %s'
                    ):format(
                        tostring(reason)
                    )
                )

                return
            end


            ApplyRecovery(
                state
            )


            local message =
                (
                    'HumanBlood: %.2f / %.2f'
                ):format(
                    state.blood,
                    GetMaximum()
                )


            print(
                '^5[LB-VAMPIRE]^7 '
                .. message
            )


            TriggerClientEvent(
                'QBCore:Notify',
                source,
                message,
                'primary',
                6000
            )


            return
        end

        


        -------------------------------------------------
        -- SET / ADD / REMOVE
        -------------------------------------------------

        local amount =
            tonumber(
                args[2]
            )


        if not amount then

            TriggerClientEvent(
                'QBCore:Notify',
                source,
                'Usage: /vamhblood set|add|remove [amount]',
                'error'
            )

            return
        end


        local success,
            result


        if action == 'set' then

            success,
            result =
                HumanBlood.Set(
                    source,
                    amount,
                    true
                )


        elseif action == 'add' then

            success,
            result =
                HumanBlood.Add(
                    source,
                    amount,
                    true
                )


        elseif action == 'remove' then

            success,
            result =
                HumanBlood.Remove(
                    source,
                    amount,
                    true
                )


        else

            TriggerClientEvent(
                'QBCore:Notify',
                source,
                'Unknown HumanBlood action.',
                'error'
            )

            return
        end


        if not success then

            TriggerClientEvent(
                'QBCore:Notify',
                source,
                (
                    'HumanBlood error: %s'
                ):format(
                    tostring(result)
                ),
                'error'
            )

            return
        end


        TriggerClientEvent(
            'QBCore:Notify',
            source,
            (
                'HumanBlood: %.2f / %.2f'
            ):format(
                result,
                GetMaximum()
            ),
            'success'
        )
    end,

    false
)