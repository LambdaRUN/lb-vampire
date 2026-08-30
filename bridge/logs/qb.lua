LBVampire = LBVampire or {}
LBVampire.Log = LBVampire.Log or {}

local warnedMissingResource = false

if Config.Debug then
    print('^5[LB-VAMPIRE]^7 Log bridge loaded.')
end

local function WriteConsole(title, message)
    local cleanMessage = tostring(message or '')
        :gsub('\n', ' | ')

    print(
        ('^5[LB-VAMPIRE]^7 [LOG] %s | %s'):format(
            tostring(title or 'Unknown'),
            cleanMessage
        )
    )
end

function LBVampire.Log.Write(
    title,
    message,
    color,
    tagEveryone
)
    if not Config.Logging
        or Config.Logging.Enabled ~= true then
        return
    end

    local provider = string.lower(
        tostring(
            Config.Logging.Provider or 'console'
        )
    )

    if provider == 'console'
        or provider == 'both' then

        WriteConsole(
            title,
            message
        )
    end

    if provider ~= 'qb'
        and provider ~= 'both' then
        return
    end

    if GetResourceState('qb-smallresources') ~= 'started' then
        if not warnedMissingResource then
            warnedMissingResource = true

            print(
                '^3[LB-VAMPIRE]^7 qb-smallresources is not started. QB logging skipped.'
            )
        end

        return
    end

    TriggerEvent(
        'qb-log:server:CreateLog',
        Config.Logging.QBLogName or 'default',
        title or 'LB-VAMPIRE',
        color or 'default',
        message or '',
        tagEveryone == true
    )
end