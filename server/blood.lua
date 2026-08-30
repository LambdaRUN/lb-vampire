LBVampire = LBVampire or {}
LBVampire.Blood = LBVampire.Blood or {}

local function Clamp(value)
    value = tonumber(value) or 0

    if value < 0 then
        return 0
    end

    if value > Config.Blood.Max then
        return Config.Blood.Max
    end

    return value
end

local function SyncState(state)
    if not state
        or not state.source then
        return
    end

    if not GetPlayerName(state.source) then
        return
    end

    TriggerClientEvent(
        'lb-vampire:client:bloodSync',
        state.source,
        {
            isVampire = true,
            blood = state.blood,
            maxBlood = Config.Blood.Max
        }
    )
end

local function ResetThresholdFlags(state)
    if not state then
        return
    end

    state.thresholdFlags =
        state.thresholdFlags or {}

    if state.blood > Config.Blood.Thresholds.Low then
        state.thresholdFlags.low = false
    end

    if state.blood > Config.Blood.Thresholds.Critical then
        state.thresholdFlags.critical = false
    end
end

local function ProcessThresholds(state)
    if not state then
        return
    end

    state.thresholdFlags =
        state.thresholdFlags or {}

    if state.blood <= Config.Blood.Thresholds.Low
        and state.blood > Config.Blood.Thresholds.Critical
        and not state.thresholdFlags.low then

        state.thresholdFlags.low = true

        LBVampire.Notify.Send(
            state.source,
            'Açlığın giderek güçleniyor.',
            'primary',
            5000
        )

        if Config.Debug then
            print(
                ('^5[LB-VAMPIRE]^7 Low Blood threshold: %s | %.2f'):format(
                    state.citizenId,
                    state.blood
                )
            )
        end
    end

    if state.blood <= Config.Blood.Thresholds.Critical
        and state.blood > 0
        and not state.thresholdFlags.critical then

        state.thresholdFlags.critical = true

        LBVampire.Notify.Send(
            state.source,
            'Kan rezervin kritik seviyeye düştü.',
            'error',
            6000
        )

        if Config.Debug then
            print(
                ('^5[LB-VAMPIRE]^7 Critical Blood threshold: %s | %.2f'):format(
                    state.citizenId,
                    state.blood
                )
            )
        end
    end

    if state.blood <= 0 then
        if Config.Debug then
            print(
                ('^5[LB-VAMPIRE]^7 Blood reached zero: %s'):format(
                    state.citizenId
                )
            )
        end

        -- Torpor Faz 5'te burada devreye girecek.
    end
end

function LBVampire.Blood.Get(source)
    local state =
        LBVampire.Vampires.GetState(source)

    if not state then
        return nil
    end

    return state.blood
end

function LBVampire.Blood.Set(
    source,
    amount,
    immediateSave
)
    source = tonumber(source)
    amount = tonumber(amount)

    if not source
        or amount == nil then

        return false, 'invalid_arguments'
    end

    local state =
        LBVampire.Vampires.GetState(source)

    if not state then
        return false, 'not_vampire'
    end

    local previousBlood =
        state.blood

    amount = Clamp(amount)

    state.blood = amount

    ResetThresholdFlags(state)
    ProcessThresholds(state)

    if immediateSave then
        local success =
            LBVampire.Persistence.SaveRuntimeState(
                state
            )

        if not success then
            state.blood = previousBlood

            return false, 'database_error'
        end

        state.dirty = false
    else
        state.dirty = true
    end

    SyncState(state)

    return true, state, previousBlood
end

function LBVampire.Blood.Add(
    source,
    amount,
    immediateSave
)
    amount = tonumber(amount)

    if not amount then
        return false, 'invalid_amount'
    end

    local current =
        LBVampire.Blood.Get(source)

    if current == nil then
        return false, 'not_vampire'
    end

    return LBVampire.Blood.Set(
        source,
        current + amount,
        immediateSave
    )
end

function LBVampire.Blood.Remove(
    source,
    amount,
    immediateSave
)
    amount = tonumber(amount)

    if not amount then
        return false, 'invalid_amount'
    end

    return LBVampire.Blood.Add(
        source,
        -amount,
        immediateSave
    )
end

function LBVampire.Blood.Sync(source)
    local state =
        LBVampire.Vampires.GetState(source)

    if not state then
        TriggerClientEvent(
            'lb-vampire:client:bloodSync',
            source,
            {
                isVampire = false,
                blood = 0,
                maxBlood = Config.Blood.Max
            }
        )

        return
    end

    SyncState(state)
end

CreateThread(function()
    local interval =
        tonumber(
            Config.Blood.NaturalDrain.Interval
        )
        or (8 * 60 * 1000)

    interval =
        math.max(interval, 1000)

    while true do
        Wait(interval)

        if Config.Blood.NaturalDrain.Enabled then
            local amount =
                tonumber(
                    Config.Blood.NaturalDrain.Amount
                )
                or 1

            for citizenId, state in pairs(
                LBVampire.Runtime.Vampires
            ) do

                if state
                    and state.source
                    and state.blood > 0
                    and GetPlayerName(state.source) then

                    local success =
                        LBVampire.Blood.Remove(
                            state.source,
                            amount,
                            false
                        )

                    if success
                        and Config.Debug then

                        print(
                            ('^5[LB-VAMPIRE]^7 Natural Blood drain: %s | %.2f'):format(
                                citizenId,
                                state.blood
                            )
                        )
                    end
                end
            end
        end
    end
end)

RegisterNetEvent(
    'lb-vampire:server:requestBloodSync',
    function()
        local playerSource =
            tonumber(source)

        if not playerSource
            or playerSource <= 0 then
            return
        end

        local citizenId =
            LBVampire.Framework.GetCitizenId(
                playerSource
            )

        if not citizenId then
            return
        end

        local state =
            LBVampire.Vampires.GetState(
                playerSource
            )

        if not state then
            local databaseState =
                LBVampire.Persistence.GetVampire(
                    citizenId
                )

            if databaseState
                and databaseState.is_vampire then

                LBVampire.Vampires.LoadPlayer(
                    playerSource
                )
            end
        end

        LBVampire.Blood.Sync(
            playerSource
        )
    end
)