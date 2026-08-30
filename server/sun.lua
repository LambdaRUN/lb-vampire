LBVampire = LBVampire or {}
LBVampire.Sun = LBVampire.Sun or {}

local VALID_STATES = {
    SAFE = true,
    REDUCED = true,
    DIRECT = true
}


local function NormalizeState(state)
    state =
        string.upper(
            tostring(
                state or ''
            )
        )

    if not VALID_STATES[state] then
        return nil
    end

    return state
end


function LBVampire.Sun.GetState(
    source
)
    local vampire =
        LBVampire.Vampires.GetState(
            source
        )

    if not vampire then
        return 'SAFE'
    end

    return vampire.sunState
        or 'SAFE'
end


function LBVampire.Sun.SetState(
    source,
    newState
)
    source =
        tonumber(source)

    if not source then
        return false, 'invalid_source'
    end

    newState =
        NormalizeState(
            newState
        )

    if not newState then
        return false, 'invalid_state'
    end

    local state =
        LBVampire.Vampires.GetState(
            source
        )

    -- İnsanlardan gelen state eventleri gameplay
    -- açısından hiçbir şey yapmaz.
    if not state then
        TriggerClientEvent(
            'lb-vampire:client:sunSync',
            source,
            'SAFE'
        )

        return false, 'not_vampire'
    end

    local previousState =
        state.sunState
        or 'SAFE'

    state.sunState =
        newState

    TriggerClientEvent(
        'lb-vampire:client:sunSync',
        source,
        newState
    )

    if previousState ~= newState
        and Config.Debug then

        print(
            (
                '^5[LB-VAMPIRE]^7 Sun state changed: %s | %s -> %s'
            ):format(
                state.citizenId,
                previousState,
                newState
            )
        )
    end

    return true, newState
end


RegisterNetEvent(
    'lb-vampire:server:updateSunState',
    function(newState)
        local playerSource =
            tonumber(source)

        if not playerSource
            or playerSource <= 0 then

            return
        end

        LBVampire.Sun.SetState(
            playerSource,
            newState
        )
    end
)


CreateThread(function()
    local tickInterval =
        tonumber(
            Config.Sun.Drain.ServerTick
        ) or 5000

    tickInterval =
        math.max(
            tickInterval,
            1000
        )

    while true do
        Wait(tickInterval)

        if Config.Sun.Enabled then

            for citizenId, state in pairs(
                LBVampire.Runtime.Vampires
            ) do

                if state
                    and state.source
                    and state.blood > 0
                    and GetPlayerName(
                        state.source
                    ) then

                    local sunState =
                        state.sunState
                        or 'SAFE'

                    local drainInterval =
                        nil

                    if sunState ==
                        'DIRECT' then

                        drainInterval =
                            tonumber(
                                Config.Sun
                                    .Drain
                                    .DirectInterval
                            )

                    elseif sunState ==
                        'REDUCED' then

                        drainInterval =
                            tonumber(
                                Config.Sun
                                    .Drain
                                    .ReducedInterval
                            )
                    end

                    if drainInterval
                        and drainInterval > 0 then

                        state.sunDrainProgress =
                            tonumber(
                                state.sunDrainProgress
                            ) or 0.0

                        state.sunDrainProgress =
                            state.sunDrainProgress
                            +
                            (
                                tickInterval /
                                drainInterval
                            )

                        local drainAmount =
                            math.floor(
                                state.sunDrainProgress
                            )

                        if drainAmount > 0 then

                            state.sunDrainProgress =
                                state.sunDrainProgress
                                - drainAmount

                            local success =
                                LBVampire.Blood.Remove(
                                    state.source,
                                    drainAmount,
                                    false
                                )

                            if success
                                and Config.Debug then

                                print(
                                    (
                                        '^5[LB-VAMPIRE]^7 Sun Blood drain: %s | State: %s | -%d | Blood: %.2f'
                                    ):format(
                                        citizenId,
                                        sunState,
                                        drainAmount,
                                        state.blood
                                    )
                                )
                            end
                        end
                    end
                end
            end
        end
    end
end)