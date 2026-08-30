LBVampire = LBVampire or {}
LBVampire.Notify = LBVampire.Notify or {}

function LBVampire.Notify.Send(source, message, notifyType, duration)
    if not source or source <= 0 then
        return
    end

    TriggerClientEvent(
        'QBCore:Notify',
        source,
        message,
        notifyType or 'primary',
        duration or 5000
    )
end