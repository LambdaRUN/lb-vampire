LBVampire = LBVampire or {}

LBVampire.ClientState =
    LBVampire.ClientState or {}


LBVampire.ClientState.interactionState =
    LBVampire.ClientState.interactionState
    or 'IDLE'

LBVampire.ClientState.feedingPartner =
    nil

LBVampire.ClientState.feedingRole =
    nil


---------------------------------------------------------
-- NOTIFY
---------------------------------------------------------

local function Notify(
    message,
    notifyType,
    duration
)
    TriggerEvent(
        'QBCore:Notify',
        message,
        notifyType or 'primary',
        duration or 5000
    )
end


---------------------------------------------------------
-- ROLE
---------------------------------------------------------

local function SetFeedingRole(
    role
)
    LBVampire.ClientState.feedingRole =
        role


    TriggerEvent(
        'lb-vampire:client:feedingRoleUpdated',
        role
    )
end


---------------------------------------------------------
-- STATE SYNC
---------------------------------------------------------

RegisterNetEvent(
    'lb-vampire:client:feedingState',
    function(data)

        data =
            data or {}


        local newState =
            data.state
            or 'IDLE'


        LBVampire.ClientState.interactionState =
            newState


        LBVampire.ClientState.feedingPartner =
            data.partnerSource


        if newState == 'IDLE' then

            LBVampire.ClientState.feedingPartner =
                nil


            SetFeedingRole(
                nil
            )
        end


        TriggerEvent(
            'lb-vampire:client:feedingStateUpdated',
            {
                state =
                    LBVampire.ClientState
                        .interactionState,

                partnerSource =
                    LBVampire.ClientState
                        .feedingPartner,

                role =
                    LBVampire.ClientState
                        .feedingRole
            }
        )


        if Config.Debug then

            print(
                (
                    '^5[LB-VAMPIRE]^7 Feeding state: %s | Partner: %s | Role: %s'
                ):format(
                    tostring(
                        LBVampire.ClientState
                            .interactionState
                    ),

                    tostring(
                        LBVampire.ClientState
                            .feedingPartner
                    ),

                    tostring(
                        LBVampire.ClientState
                            .feedingRole
                    )
                )
            )
        end
    end
)


---------------------------------------------------------
-- REQUEST SENT
-- VAMPIRE SIDE
---------------------------------------------------------

RegisterNetEvent(
    'lb-vampire:client:feedingRequestSent',
    function(data)

        data =
            data or {}


        local targetName =
            data.targetName
            or 'oyuncu'


        Notify(
            (
                '%s için beslenme isteği gönderildi.'
            ):format(
                targetName
            ),
            'primary',
            5000
        )
    end
)


---------------------------------------------------------
-- IMPORTANT
--
-- feedingRequest event artık burada yok.
--
-- İnsan tarafındaki request:
--
-- client/feeding_consent.lua
--
-- tarafından yönetilecek.
---------------------------------------------------------


---------------------------------------------------------
-- ACCEPTED
---------------------------------------------------------

RegisterNetEvent(
    'lb-vampire:client:feedingAccepted',
    function(data)

        data =
            data or {}


        local role =
            string.upper(
                tostring(
                    data.role
                    or 'UNKNOWN'
                )
            )


        local partnerName =
            data.partnerName
            or 'oyuncu'


        SetFeedingRole(
            role
        )


        if role == 'VAMPIRE' then

            Notify(
                (
                    '%s beslenme isteğini kabul etti.'
                ):format(
                    partnerName
                ),
                'success',
                5000
            )


        elseif role == 'HUMAN' then

            Notify(
                (
                    '%s için beslenmeye izin verdin.'
                ):format(
                    partnerName
                ),
                'success',
                5000
            )


        else

            Notify(
                'Beslenme isteği kabul edildi.',
                'success',
                5000
            )
        end


        if Config.Debug then

            print(
                (
                    '^2[LB-VAMPIRE]^7 Consent accepted | Role: %s | Partner: %s'
                ):format(
                    tostring(role),

                    tostring(
                        data.partnerSource
                    )
                )
            )
        end
    end
)


---------------------------------------------------------
-- STOPPED
---------------------------------------------------------

RegisterNetEvent(
    'lb-vampire:client:feedingStopped',
    function(reason)

        LBVampire.ClientState.interactionState =
            'IDLE'


        LBVampire.ClientState.feedingPartner =
            nil


        SetFeedingRole(
            nil
        )


        TriggerEvent(
            'lb-vampire:client:feedingStateUpdated',
            {
                state =
                    'IDLE',

                partnerSource =
                    nil,

                role =
                    nil
            }
        )


        Notify(
            (
                'Beslenme işlemi sona erdi. (%s)'
            ):format(
                tostring(
                    reason
                    or 'unknown'
                )
            ),
            'primary',
            4000
        )


        if Config.Debug then

            print(
                (
                    '^5[LB-VAMPIRE]^7 Feeding stopped | Reason: %s'
                ):format(
                    tostring(
                        reason
                    )
                )
            )
        end
    end
)


---------------------------------------------------------
-- SERVER NOTIFY
---------------------------------------------------------

RegisterNetEvent(
    'lb-vampire:client:feedingNotify',
    function(
        message,
        notifyType,
        duration
    )

        Notify(
            message,
            notifyType,
            duration
        )
    end
)


---------------------------------------------------------
-- PLAYER UNLOAD
---------------------------------------------------------

RegisterNetEvent(
    'QBCore:Client:OnPlayerUnload',
    function()

        LBVampire.ClientState.interactionState =
            'IDLE'


        LBVampire.ClientState.feedingPartner =
            nil


        SetFeedingRole(
            nil
        )
    end
)


---------------------------------------------------------
-- RESOURCE CLEANUP
---------------------------------------------------------

AddEventHandler(
    'onClientResourceStop',
    function(resourceName)

        if resourceName ~=
            GetCurrentResourceName() then

            return
        end


        LBVampire.ClientState.interactionState =
            'IDLE'


        LBVampire.ClientState.feedingPartner =
            nil


        LBVampire.ClientState.feedingRole =
            nil
    end
)