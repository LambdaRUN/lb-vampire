LBVampire = LBVampire or {}

LBVampire.ClientState =
    LBVampire.ClientState or {}

LBVampire.ClientState.isVampire =
    false

LBVampire.ClientState.blood =
    0

LBVampire.ClientState.maxBlood =
    Config.Blood.Max

LBVampire.ClientState.bloodStateReceived =
    false


local function RequestBloodSync()
    TriggerServerEvent(
        'lb-vampire:server:requestBloodSync'
    )
end


RegisterNetEvent(
    'lb-vampire:client:bloodSync',
    function(data)
        if type(data) ~= 'table' then
            return
        end

        LBVampire.ClientState.isVampire =
            data.isVampire == true

        LBVampire.ClientState.blood =
            tonumber(data.blood)
            or 0

        LBVampire.ClientState.maxBlood =
            tonumber(data.maxBlood)
            or Config.Blood.Max

        LBVampire.ClientState.bloodStateReceived =
            true

        if Config.Debug then
            print(
                (
                    '^5[LB-VAMPIRE]^7 Blood sync | Vampire: %s | Blood: %.2f / %.2f'
                ):format(
                    tostring(
                        LBVampire
                            .ClientState
                            .isVampire
                    ),

                    LBVampire
                        .ClientState
                        .blood,

                    LBVampire
                        .ClientState
                        .maxBlood
                )
            )
        end

        TriggerEvent(
            'lb-vampire:client:bloodStateUpdated',
            {
                isVampire =
                    LBVampire
                        .ClientState
                        .isVampire,

                blood =
                    LBVampire
                        .ClientState
                        .blood,

                maxBlood =
                    LBVampire
                        .ClientState
                        .maxBlood
            }
        )
    end
)


RegisterNetEvent(
    'QBCore:Client:OnPlayerLoaded',
    function()
        CreateThread(function()
            Wait(1000)

            RequestBloodSync()

            -- Karakter/runtime yükleme yarışı ihtimaline
            -- karşı ikinci doğrulama.
            Wait(2000)

            RequestBloodSync()
        end)
    end
)


RegisterNetEvent(
    'QBCore:Client:OnPlayerUnload',
    function()
        LBVampire.ClientState.isVampire =
            false

        LBVampire.ClientState.blood =
            0

        LBVampire.ClientState.bloodStateReceived =
            false

        TriggerEvent(
            'lb-vampire:client:bloodStateUpdated',
            {
                isVampire = false,
                blood = 0,
                maxBlood = Config.Blood.Max
            }
        )
    end
)


CreateThread(function()
    -- Resource oyuncu zaten online durumdayken
    -- restart edilmiş olabilir.
    Wait(1500)

    RequestBloodSync()

    -- İlk request runtime'ın yüklenmesinden önce
    -- gittiyse ikinci request gerçek state'i alır.
    Wait(2500)

    RequestBloodSync()
end)