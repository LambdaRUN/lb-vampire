LBVampire = LBVampire or {}

LBVampire.FeedingConsent =
    LBVampire.FeedingConsent or {}


local Consent =
    LBVampire.FeedingConsent


---------------------------------------------------------
-- STATE
---------------------------------------------------------

Consent.active =
    false

Consent.debugMode =
    false

Consent.requesterName =
    nil

Consent.requesterSource =
    nil

Consent.generation =
    0



---------------------------------------------------------
-- NUI FOCUS
---------------------------------------------------------

local function AcquireFocus()
    SetNuiFocus(
        true,
        true
    )


    SetNuiFocusKeepInput(
        false
    )


    -----------------------------------------------------
    -- Bazı NUI/resource lifecycle durumlarında aynı
    -- frame içinde başka focus değişikliği olabiliyor.
    -- Bir sonraki frame tekrar garanti ediyoruz.
    -----------------------------------------------------

    CreateThread(function()

        Wait(
            50
        )


        if Consent.active ~= true then
            return
        end


        SetNuiFocus(
            true,
            true
        )


        SetNuiFocusKeepInput(
            false
        )
    end)
end


local function ReleaseFocus()
    SetNuiFocusKeepInput(
        false
    )


    SetNuiFocus(
        false,
        false
    )
end


---------------------------------------------------------
-- CLOSE
---------------------------------------------------------

local function CloseConsent(
    reason
)
    Consent.generation =
        Consent.generation + 1


    Consent.active =
        false


    Consent.debugMode =
        false


    Consent.requesterName =
        nil


    Consent.requesterSource =
        nil


    ReleaseFocus()


    SendNUIMessage({
        action =
            'feeding-consent:close',

        reason =
            reason
            or 'closed'
    })
end


---------------------------------------------------------
-- OPEN
---------------------------------------------------------

local function OpenConsent(
    data,
    debugMode
)
    data =
        data or {}


    -----------------------------------------------------
    -- Önce eski pencere varsa temizle.
    -----------------------------------------------------

    if Consent.active then

        CloseConsent(
            'replaced'
        )
    end


    Consent.generation =
        Consent.generation + 1


    local generation =
        Consent.generation


    Consent.active =
        true


    Consent.debugMode =
        debugMode == true


    Consent.requesterName =
        tostring(
            data.requesterName
            or 'Bir vampir'
        )


    Consent.requesterSource =
        tonumber(
            data.requesterSource
        )


    local timeout =
        tonumber(
            data.timeout
        )
        or tonumber(
            Config.Feeding
                and Config.Feeding.ConsentTimeout
        )
        or 15000


    timeout =
        math.max(
            timeout,
            1000
        )


    -----------------------------------------------------
    -- NUI
    -----------------------------------------------------

    AcquireFocus()


    SendNUIMessage({
        action =
            'feeding-consent:open',

        requesterName =
            Consent.requesterName,

        timeout =
            timeout,

        debug =
            Consent.debugMode
    })


    -----------------------------------------------------
    -- Lua safety timeout
    --
    -- JS timeout kaçarsa focus sonsuza kadar kalmasın.
    -----------------------------------------------------

    CreateThread(function()

        Wait(
            timeout + 750
        )


        if generation ~=
            Consent.generation then

            return
        end


        if Consent.active ~= true then
            return
        end


        CloseConsent(
            'timeout_safety'
        )
    end)
end


---------------------------------------------------------
-- REAL REQUEST
---------------------------------------------------------

RegisterNetEvent(
    'lb-vampire:client:feedingRequest',
    function(data)

        OpenConsent(
            data,
            false
        )
    end
)


---------------------------------------------------------
-- ACCEPTED ELSEWHERE / SESSION STARTED
---------------------------------------------------------

RegisterNetEvent(
    'lb-vampire:client:feedingAccepted',
    function()

        if Consent.active then

            CloseConsent(
                'accepted'
            )
        end
    end
)


---------------------------------------------------------
-- FEEDING STOPPED
---------------------------------------------------------

RegisterNetEvent(
    'lb-vampire:client:feedingStopped',
    function()

        if Consent.active then

            CloseConsent(
                'feeding_stopped'
            )
        end
    end
)


---------------------------------------------------------
-- STATE IDLE SAFETY
---------------------------------------------------------

RegisterNetEvent(
    'lb-vampire:client:feedingState',
    function(data)

        data =
            data or {}


        if data.state == 'IDLE'
            and Consent.active == true then


            CloseConsent(
                'state_idle'
            )
        end
    end
)


---------------------------------------------------------
-- ACCEPT CALLBACK
---------------------------------------------------------

RegisterNUICallback(
    'feedingConsentAccept',
    function(
        _,
        cb
    )

        if Consent.active ~= true then

            cb({
                success =
                    false
            })

            return
        end


        local debugMode =
            Consent.debugMode


        CloseConsent(
            'accept'
        )


        if debugMode then

            print(
                '^2[LB-VAMPIRE]^7 DEBUG consent ACCEPT.'
            )


        else

            TriggerServerEvent(
                'lb-vampire:server:acceptFeeding'
            )
        end


        cb({
            success =
                true
        })
    end
)


---------------------------------------------------------
-- DECLINE CALLBACK
---------------------------------------------------------

RegisterNUICallback(
    'feedingConsentDecline',
    function(
        _,
        cb
    )

        if Consent.active ~= true then

            cb({
                success =
                    false
            })

            return
        end


        local debugMode =
            Consent.debugMode


        CloseConsent(
            'decline'
        )


        if debugMode then

            print(
                '^3[LB-VAMPIRE]^7 DEBUG consent DECLINE.'
            )


        else

            TriggerServerEvent(
                'lb-vampire:server:declineFeeding'
            )
        end


        cb({
            success =
                true
        })
    end
)


---------------------------------------------------------
-- LOCAL TIMEOUT CALLBACK
---------------------------------------------------------

RegisterNUICallback(
    'feedingConsentTimeout',
    function(
        _,
        cb
    )

        if Consent.active == true then

            -------------------------------------------------
            -- Server'ın kendi ConsentTimeout sistemi
            -- authoritative olarak request'i temizleyecek.
            --
            -- Burada sadece NUI/focus kapanıyor.
            -------------------------------------------------

            CloseConsent(
                'timeout'
            )
        end


        cb({
            success =
                true
        })
    end
)

---------------------------------------------------------
-- LOCAL CHARACTER NAME
-- DEBUG PREVIEW ONLY
---------------------------------------------------------

local function GetLocalCharacterName()
    if GetResourceState(
        'qb-core'
    ) ~= 'started' then

        return 'Test Karakteri'
    end


    local QBCore =
        exports['qb-core']
            :GetCoreObject()


    if not QBCore
        or not QBCore.Functions then

        return 'Test Karakteri'
    end


    local PlayerData =
        QBCore.Functions
            .GetPlayerData()


    if not PlayerData then

        return 'Test Karakteri'
    end


    local charinfo =
        PlayerData.charinfo
        or {}


    local firstName =
        tostring(
            charinfo.firstname
            or ''
        )


    local lastName =
        tostring(
            charinfo.lastname
            or ''
        )


    local fullName =
        (
            firstName
            .. ' '
            .. lastName
        )


    fullName =
        fullName:gsub(
            '^%s+',
            ''
        )


    fullName =
        fullName:gsub(
            '%s+$',
            ''
        )


    fullName =
        fullName:gsub(
            '%s+',
            ' '
        )


    if fullName == '' then

        return GetPlayerName(
            PlayerId()
        )
        or 'Test Karakteri'
    end


    return fullName
end

---------------------------------------------------------
-- DEBUG TEST
---------------------------------------------------------

if Config.Debug then

    RegisterCommand(
        'vamconsenttest',
        function()

            OpenConsent(
                {
                    requesterName =
                        GetLocalCharacterName(),

                    requesterSource =
                        999,

                    timeout =
                        tonumber(
                            Config.Feeding
                                .ConsentTimeout
                        )
                        or 15000
                },
                true
            )
        end,
        false
    )


    RegisterCommand(
        'vamconsentclose',
        function()

            if Consent.active then

                CloseConsent(
                    'debug_close'
                )
            end
        end,
        false
    )
end


---------------------------------------------------------
-- PLAYER UNLOAD
---------------------------------------------------------

RegisterNetEvent(
    'QBCore:Client:OnPlayerUnload',
    function()

        if Consent.active then

            CloseConsent(
                'player_unload'
            )
        end
    end
)


---------------------------------------------------------
-- SPAWN SELECTION
---------------------------------------------------------

AddEventHandler(
    'lb-vampire:client:spawnSelectionStarted',
    function()

        if Consent.active then

            CloseConsent(
                'spawn_selection'
            )
        end
    end
)


---------------------------------------------------------
-- RESOURCE STOP
---------------------------------------------------------

AddEventHandler(
    'onClientResourceStop',
    function(resourceName)

        if resourceName ~=
            GetCurrentResourceName() then

            return
        end


        ReleaseFocus()
    end
)