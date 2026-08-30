if not Config.Debug then
    return
end

RegisterCommand('lbvdebug', function(source)
    if source == 0 then
        print('^1[LB-VAMPIRE]^7 This command must be used by a player.')
        return
    end

    local citizenId = LBVampire.Framework.GetCitizenId(source)
    local bloodType = LBVampire.Framework.GetBloodType(source)
    local playerName = LBVampire.Framework.GetPlayerName(source)

    if not citizenId then
        LBVampire.Notify.Send(
            source,
            'LB-VAMPIRE: Player data could not be read.',
            'error'
        )

        return
    end

    bloodType = bloodType or 'UNKNOWN'
    playerName = playerName or 'UNKNOWN'

    print(('^5[LB-VAMPIRE]^7 Debug Player: %s'):format(source))
    print(('^5[LB-VAMPIRE]^7 Name: %s'):format(playerName))
    print(('^5[LB-VAMPIRE]^7 CitizenID: %s'):format(citizenId))
    print(('^5[LB-VAMPIRE]^7 Blood Type: %s'):format(bloodType))

    local message = ('CitizenID: %s | Blood Type: %s'):format(
        citizenId,
        bloodType
    )

    LBVampire.Notify.Send(
        source,
        message,
        'success',
        8000
    )
end, false)