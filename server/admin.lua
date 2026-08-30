LBVampire = LBVampire or {}

local function Reply(
    source,
    message,
    notifyType
)
    if source == 0 then
        print(
            ('^5[LB-VAMPIRE]^7 %s'):format(
                message
            )
        )

        return
    end

    LBVampire.Notify.Send(
        source,
        message,
        notifyType or 'primary',
        7000
    )
end

local function GetTargetSource(value)
    local targetSource =
        tonumber(value)

    if not targetSource then
        return nil
    end

    if not GetPlayerName(
        targetSource
    ) then
        return nil
    end

    return targetSource
end

local function GetActorLabel(source)
    if source == 0 then
        return 'CONSOLE'
    end

    local name =
        LBVampire.Framework
            .GetPlayerName(source)
        or GetPlayerName(source)
        or 'UNKNOWN'

    local citizenId =
        LBVampire.Framework
            .GetCitizenId(source)
        or 'UNKNOWN'

    return (
        '%s | CitizenID: %s | ID: %s'
    ):format(
        name,
        citizenId,
        source
    )
end

local function GetTargetLabel(source)
    local name =
        LBVampire.Framework
            .GetPlayerName(source)
        or GetPlayerName(source)
        or 'UNKNOWN'

    local citizenId =
        LBVampire.Framework
            .GetCitizenId(source)
        or 'UNKNOWN'

    return (
        '%s | CitizenID: %s | ID: %s'
    ):format(
        name,
        citizenId,
        source
    )
end

local function ParseBoolean(value)
    value =
        string.lower(
            tostring(value or '')
        )

    if value == 'true'
        or value == '1'
        or value == 'yes'
        or value == 'on' then

        return true
    end

    if value == 'false'
        or value == '0'
        or value == 'no'
        or value == 'off' then

        return false
    end

    return nil
end

LBVampire.Framework.RegisterCommand(
    'vampire',
    'LB-VAMPIRE administration',
    {},
    false,
    function(source, args)

        local action =
            string.lower(
                args[1] or ''
            )

        if action == '' then
            Reply(
                source,
                'Usage: /vampire set|remove|inspect|restore|blood|embracepermission [id] [value]',
                'error'
            )

            return
        end

        local targetSource =
            GetTargetSource(
                args[2]
            )

        if not targetSource then
            Reply(
                source,
                'Valid online player ID required.',
                'error'
            )

            return
        end

        if action == 'set' then
            local success, result =
                LBVampire.Vampires
                    .SetPlayerVampire(
                        targetSource
                    )

            if not success then
                if result == 'already_vampire' then
                    Reply(
                        source,
                        (
                            'Player %s is already a vampire. Runtime state resynchronized.'
                        ):format(
                            targetSource
                        ),
                        'primary'
                    )

                    return
                end

                if result == 'state_busy' then
                    Reply(
                        source,
                        'Vampire state update is already in progress. Try again in a moment.',
                        'error'
                    )

                    return
                end

                Reply(
                    source,
                    ('Unable to create vampire: %s'):format(
                        result
                        or 'unknown'
                    ),
                    'error'
                )

                return
            end

            Reply(
                source,
                ('Player %s is now a vampire.'):format(
                    targetSource
                ),
                'success'
            )

            LBVampire.Log.Write(
                'Vampire Created',
                (
                    'Admin: %s\nTarget: %s\nBlood: %.2f'
                ):format(
                    GetActorLabel(source),
                    GetTargetLabel(
                        targetSource
                    ),
                    result.blood
                ),
                'red'
            )

            return
        end

        if action == 'remove' then
            local success, reason =
                LBVampire.Vampires
                    .RemovePlayerVampire(
                        targetSource
                    )

            if not success then
                Reply(
                    source,
                    ('Unable to remove vampire: %s'):format(
                        reason
                        or 'unknown'
                    ),
                    'error'
                )

                return
            end

            Reply(
                source,
                ('Vampire state removed from player %s.'):format(
                    targetSource
                ),
                'success'
            )

            LBVampire.Log.Write(
                'Vampire Removed',
                (
                    'Admin: %s\nTarget: %s'
                ):format(
                    GetActorLabel(source),
                    GetTargetLabel(
                        targetSource
                    )
                ),
                'orange'
            )

            return
        end

        if action == 'inspect' then
            local citizenId =
                LBVampire.Framework
                    .GetCitizenId(
                        targetSource
                    )

            local state =
                LBVampire.Vampires
                    .GetState(
                        targetSource
                    )

            if not state then
                Reply(
                    source,
                    (
                        'Player %s | CitizenID: %s | Vampire: NO'
                    ):format(
                        targetSource,
                        citizenId
                        or 'UNKNOWN'
                    ),
                    'primary'
                )

                return
            end

            local message =
                (
                    'Player %s | CitizenID: %s | Vampire: YES | Blood: %.2f | Embrace: %s'
                ):format(
                    targetSource,
                    state.citizenId,
                    state.blood,
                    state.canEmbrace
                        and 'YES'
                        or 'NO'
                )

            Reply(
                source,
                message,
                'success'
            )

            print(
                '^5[LB-VAMPIRE]^7 -------- INSPECT --------'
            )

            print(
                ('CitizenID: %s'):format(
                    state.citizenId
                )
            )

            print(
                ('Blood: %.2f'):format(
                    state.blood
                )
            )

            print(
                ('Can Embrace: %s'):format(
                    tostring(
                        state.canEmbrace
                    )
                )
            )

            print(
                ('Sire: %s'):format(
                    state.sireCitizenId
                    or 'NONE'
                )
            )

            print(
                ('Interaction State: %s'):format(
                    state.interactionState
                )
            )

            print(
                ('Sun State: %s'):format(
                    state.sunState
                )
            )

            print(
                ('Dirty: %s'):format(
                    tostring(
                        state.dirty
                    )
                )
            )

            print(
                '^5[LB-VAMPIRE]^7 -------------------------'
            )

            return
        end

        if action == 'restore' then
            local success, result =
                LBVampire.Vampires
                    .RestorePlayer(
                        targetSource
                    )

            if not success then
                Reply(
                    source,
                    ('Unable to restore vampire: %s'):format(
                        result
                        or 'unknown'
                    ),
                    'error'
                )

                return
            end

            Reply(
                source,
                (
                    'Player %s vampire state restored from database.'
                ):format(
                    targetSource
                ),
                'success'
            )

            LBVampire.Log.Write(
                'Admin Restore',
                (
                    'Admin: %s\nTarget: %s\nBlood after restore: %.2f'
                ):format(
                    GetActorLabel(source),
                    GetTargetLabel(
                        targetSource
                    ),
                    result.blood
                ),
                'blue'
            )

            return
        end

        if action == 'blood' then
            local amount =
                tonumber(args[3])

            if amount == nil then
                Reply(
                    source,
                    'Blood amount required: 0-100.',
                    'error'
                )

                return
            end

            if amount < 0
                or amount
                > Config.Blood.Max then

                Reply(
                    source,
                    (
                        'Blood must be between 0 and %s.'
                    ):format(
                        Config.Blood.Max
                    ),
                    'error'
                )

                return
            end

            local success,
                result,
                previousBlood =
                LBVampire.Vampires
                    .SetBlood(
                        targetSource,
                        amount
                    )

            if not success then
                Reply(
                    source,
                    ('Unable to set Blood: %s'):format(
                        result
                        or 'unknown'
                    ),
                    'error'
                )

                return
            end

            Reply(
                source,
                (
                    'Player %s Blood set to %.2f.'
                ):format(
                    targetSource,
                    result.blood
                ),
                'success'
            )

            LBVampire.Log.Write(
                'Admin Blood Set',
                (
                    'Admin: %s\nTarget: %s\nPrevious Blood: %.2f\nNew Blood: %.2f'
                ):format(
                    GetActorLabel(source),
                    GetTargetLabel(
                        targetSource
                    ),
                    previousBlood,
                    result.blood
                ),
                'yellow'
            )

            return
        end

        if action ==
            'embracepermission' then

            local enabled =
                ParseBoolean(args[3])

            if enabled == nil then
                Reply(
                    source,
                    'Use true or false.',
                    'error'
                )

                return
            end

            local success,
                result,
                previousValue =
                LBVampire.Vampires
                    .SetEmbracePermission(
                        targetSource,
                        enabled
                    )

            if not success then
                Reply(
                    source,
                    (
                        'Unable to change Embrace permission: %s'
                    ):format(
                        result
                        or 'unknown'
                    ),
                    'error'
                )

                return
            end

            Reply(
                source,
                (
                    'Player %s Embrace permission: %s'
                ):format(
                    targetSource,
                    result.canEmbrace
                        and 'ENABLED'
                        or 'DISABLED'
                ),
                'success'
            )

            LBVampire.Log.Write(
                'Embrace Permission Changed',
                (
                    'Admin: %s\nTarget: %s\nPrevious: %s\nNew: %s'
                ):format(
                    GetActorLabel(source),
                    GetTargetLabel(
                        targetSource
                    ),
                    tostring(
                        previousValue
                    ),
                    tostring(
                        result.canEmbrace
                    )
                ),
                'blue'
            )

            return
        end

        Reply(
            source,
            'Unknown action. Use: set, remove, inspect, restore, blood or embracepermission.',
            'error'
        )
    end,
    Config.AdminPermission
)