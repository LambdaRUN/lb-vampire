print(
    '^6[LB-VAMPIRE]^7 ACTIVE RESOURCE PATH: '
    .. tostring(
        GetResourcePath(
            GetCurrentResourceName()
        )
    )
)


LBVampire = LBVampire or {}

LBVampire.Version = '0.7.6'

LBVampire.Runtime =
    LBVampire.Runtime or {}

LBVampire.Runtime.Vampires =
    LBVampire.Runtime.Vampires or {}

LBVampire.Runtime.SourceToCitizen =
    LBVampire.Runtime.SourceToCitizen
    or {}

CreateThread(function()
    Wait(0)

    print(
        '^5[LB-VAMPIRE]^7 -----------------------------------'
    )

    print(
        '^5[LB-VAMPIRE]^7 Production V1'
    )

    print(
        (
            '^5[LB-VAMPIRE]^7 Version: %s'
        ):format(
            LBVampire.Version
        )
    )

    print(
        '^5[LB-VAMPIRE]^7 Framework: QBCore'
    )

    print(
        '^5[LB-VAMPIRE]^7 Bootstrap loaded successfully.'
    )

    print(
        '^5[LB-VAMPIRE]^7 -----------------------------------'
    )
end)