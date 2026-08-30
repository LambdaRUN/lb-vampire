LBVampire = LBVampire or {}

LBVampire.FeedingStatusClient =
    LBVampire.FeedingStatusClient or {}


local Status =
    LBVampire.FeedingStatusClient


---------------------------------------------------------
-- STATE
---------------------------------------------------------

Status.active =
    false

Status.debugMode =
    false

Status.partnerName =
    nil

Status.currentLevel =
    nil

Status.token =
    nil

Status.debugGeneration =
    0

Status.nuiReady =
    false

Status.pendingReal =
    false

Status.pendingPartnerName =
    nil

---------------------------------------------------------
-- CONFIG
---------------------------------------------------------

local function GetConfig()
    return Config.Feeding
        and Config.Feeding.StatusUI
        or {}
end


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

        notifyType
            or 'primary',

        duration
            or 5000
    )
end


---------------------------------------------------------
-- LEVEL
---------------------------------------------------------

local function GetBloodLevel(
    blood,
    lowThreshold,
    criticalThreshold,
    severeThreshold
)
    blood =
        tonumber(blood)
        or 100


    if blood <=
        severeThreshold then

        return 'SEVERE'
    end


    if blood <=
        criticalThreshold then

        return 'CRITICAL'
    end


    if blood <=
        lowThreshold then

        return 'LOW'
    end


    return 'STABLE'
end


---------------------------------------------------------
-- CLOSE
---------------------------------------------------------

local function CloseStatus(
    reason
)
    Status.debugGeneration =
        Status.debugGeneration + 1


    Status.active =
        false


    Status.debugMode =
        false


    Status.partnerName =
        nil


    Status.currentLevel =
        nil


    Status.token =
        nil

    Status.pendingReal =
    false


    Status.pendingPartnerName =
    nil

    SendNUIMessage({
        action =
            'feeding-status:close',

        reason =
            reason
            or 'closed'
    })
end


---------------------------------------------------------
-- OPEN
---------------------------------------------------------

local function OpenStatus(
    partnerName,
    debugMode
)
    local config =
        GetConfig()


    if config.Enabled ~= true then

        if Config.Debug then

            print(
                '^1[LB-VAMPIRE]^7 Feeding Status UI cannot open: Config.Feeding.StatusUI.Enabled is not true.'
            )
        end


        return false,
            'status_ui_disabled'
    end


    if Status.nuiReady ~= true then

        if Config.Debug then

            print(
                '^1[LB-VAMPIRE]^7 Feeding Status UI cannot open: NUI is not ready.'
            )
        end


        return false,
            'nui_not_ready'
    end


    Status.active =
        true


    Status.debugMode =
        debugMode == true


    Status.partnerName =
        tostring(
            partnerName
            or 'Hedef'
        )


    Status.currentLevel =
        nil


    SendNUIMessage({
        action =
            'feeding-status:open',

        partnerName =
            Status.partnerName,

        stopKey =
            tostring(
                config.StopKey
                or 'X'
            )
    })


    if Config.Debug then

        print(
            (
                '^2[LB-VAMPIRE]^7 Feeding Status UI opened | Debug: %s | Target: %s'
            ):format(
                tostring(
                    Status.debugMode
                ),
                Status.partnerName
            )
        )
    end


    return true
end


---------------------------------------------------------
-- UPDATE
---------------------------------------------------------

local function UpdateStatus(
    data
)
    if Status.active ~= true then
        return
    end


    data =
        data or {}


    local blood =
        tonumber(
            data.blood
        )
        or 100


    local maxBlood =
        tonumber(
            data.maxBlood
        )
        or 100


    local lowThreshold =
        tonumber(
            data.lowThreshold
        )
        or 70


    local criticalThreshold =
        tonumber(
            data.criticalThreshold
        )
        or 40


    local severeThreshold =
        tonumber(
            data.severeThreshold
        )
        or 20


    local level =
        GetBloodLevel(
            blood,
            lowThreshold,
            criticalThreshold,
            severeThreshold
        )


    -----------------------------------------------------
    -- LEVEL CHANGE
    -----------------------------------------------------

    if level ~=
        Status.currentLevel then


        local config =
            GetConfig()


        local notifications =
            config.Notifications
            or {}


        if level ==
            'CRITICAL'
            and notifications.Critical
                == true then


            Notify(
                'Hedefin kan seviyesi kritik.',
                'error',
                5000
            )


        elseif level ==
            'SEVERE'
            and notifications.Severe
                == true then


            Notify(
                'Hedefin kan rezervi tükenmek üzere.',
                'error',
                6000
            )
        end


        Status.currentLevel =
            level
    end


    Status.token =
        data.token
        or Status.token


    SendNUIMessage({
        action =
            'feeding-status:update',

        blood =
            blood,

        maxBlood =
            maxBlood,

        level =
            level
    })
end


---------------------------------------------------------
-- NUI READY HANDSHAKE
---------------------------------------------------------

RegisterNUICallback(
    'feedingStatusReady',
    function(
        _,
        cb
    )

        Status.nuiReady =
            true


        if Config.Debug then

            print(
                '^2[LB-VAMPIRE]^7 Feeding Status NUI ready.'
            )
        end


        cb({
            success =
                true
        })
    end
)


---------------------------------------------------------
-- REAL FEEDING START
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
                    or ''
                )
            )


        if role ~= 'VAMPIRE' then
            return
        end


        -------------------------------------------------
        -- UI'ı hemen açmıyoruz.
        --
        -- İlk authoritative HumanBlood update'ini
        -- bekliyoruz.
        -------------------------------------------------

        Status.pendingReal =
            true


        Status.pendingPartnerName =
            tostring(
                data.partnerName
                or 'Hedef'
            )


        if Config.Debug then

            print(
                (
                    '^5[LB-VAMPIRE]^7 Feeding Status waiting for first server update | Target: %s'
                ):format(
                    Status.pendingPartnerName
                )
            )
        end
    end
)


---------------------------------------------------------
-- SERVER STATUS UPDATE
---------------------------------------------------------

RegisterNetEvent(
    'lb-vampire:client:feedingStatusUpdate',
    function(data)

        if Status.debugMode == true then
            return
        end


        -------------------------------------------------
        -- İlk server update geldi.
        --
        -- UI şimdi açılıyor.
        -------------------------------------------------

        if Status.active ~= true
            and Status.pendingReal == true then


            local opened,
                reason =
                OpenStatus(
                    Status.pendingPartnerName
                        or 'Hedef',
                    false
                )


            if not opened then

                if Config.Debug then

                    print(
                        (
                            '^1[LB-VAMPIRE]^7 Feeding Status first-update open failed: %s'
                        ):format(
                            tostring(reason)
                        )
                    )
                end


                return
            end


            Status.pendingReal =
                false


            Status.pendingPartnerName =
                nil
        end


        -------------------------------------------------
        -- Aynı frame'de gerçek durum uygulanır.
        -------------------------------------------------

        UpdateStatus(
            data
        )
    end
)


---------------------------------------------------------
-- FEEDING STOP
---------------------------------------------------------

RegisterNetEvent(
    'lb-vampire:client:feedingStopped',
    function(reason)

        if Status.active then

            CloseStatus(
                reason
                or 'feeding_stopped'
            )
        end
    end
)


---------------------------------------------------------
-- STATE SAFETY
---------------------------------------------------------

RegisterNetEvent(
    'lb-vampire:client:feedingState',
    function(data)

        data =
            data
            or {}


        if data.state ==
            'IDLE'
            and Status.active == true
            and Status.debugMode ~= true then


            CloseStatus(
                'state_idle'
            )
        end
    end
)


---------------------------------------------------------
-- STOP
---------------------------------------------------------

local function StopFeeding()
    if Status.active ~=
        true then

        return
    end


    -----------------------------------------------------
    -- DEBUG
    -----------------------------------------------------

    if Status.debugMode ==
        true then


        CloseStatus(
            'debug_manual_stop'
        )


        if Config.Debug then

            print(
                '^3[LB-VAMPIRE]^7 DEBUG Feeding Status manually stopped.'
            )
        end


        return
    end


    -----------------------------------------------------
    -- REAL SESSION
    -----------------------------------------------------

    TriggerServerEvent(
        'lb-vampire:server:cancelFeeding'
    )
end


---------------------------------------------------------
-- KEY
---------------------------------------------------------

RegisterCommand(
    'lbvampire_stopfeeding',
    function()

        StopFeeding()
    end,
    false
)


RegisterKeyMapping(
    'lbvampire_stopfeeding',
    'LB-VAMPIRE: Beslenmeyi bırak',
    'keyboard',
    tostring(
        GetConfig().StopKey
        or 'X'
    )
)


---------------------------------------------------------
-- DEBUG STATUS TEST
---------------------------------------------------------

if Config.Debug then

    RegisterCommand(
        'vamfeedstatustest',
        function()

            print(
                '^5[LB-VAMPIRE]^7 /vamfeedstatustest invoked.'
            )


            local config =
                GetConfig()


            if config.Enabled
                ~= true then


                Notify(
                    'Feeding Status UI config içinde kapalı.',
                    'error'
                )


                print(
                    '^1[LB-VAMPIRE]^7 Config.Feeding.StatusUI.Enabled ~= true'
                )


                return
            end


            if Status.nuiReady
                ~= true then


                Notify(
                    'Feeding Status NUI henüz yüklenmedi.',
                    'error'
                )


                print(
                    '^1[LB-VAMPIRE]^7 feeding-status.js handshake alınmadı.'
                )


                return
            end


            Status.debugGeneration =
                Status.debugGeneration + 1


            local generation =
                Status.debugGeneration


            local opened,
                reason =
                OpenStatus(
                    'Test Hedefi',
                    true
                )


            if not opened then

                Notify(
                    (
                        'Feeding Status UI açılamadı: %s'
                    ):format(
                        tostring(reason)
                    ),
                    'error'
                )


                return
            end


            Notify(
                'Feeding Status debug testi başladı.',
                'success',
                3000
            )


            CreateThread(function()

                local duration =
                    30000


                local startedAt =
                    GetGameTimer()


                while Status.active ==
                    true
                    and Status.debugMode ==
                        true
                    and generation ==
                        Status.debugGeneration do


                    Wait(
                        100
                    )


                    local elapsed =
                        GetGameTimer()
                        -
                        startedAt


                    local progress =
                        math.min(
                            elapsed /
                                duration,
                            1.0
                        )


                    local blood =
                        100.0
                        -
                        (
                            100.0
                            *
                            progress
                        )


                    UpdateStatus({
                        token =
                            'debug',

                        blood =
                            blood,

                        maxBlood =
                            100,

                        lowThreshold =
                            70,

                        criticalThreshold =
                            40,

                        severeThreshold =
                            20
                    })


                    if progress >=
                        1.0 then


                        CloseStatus(
                            'debug_complete'
                        )


                        break
                    end
                end
            end)
        end,
        false
    )


    RegisterCommand(
        'vamfeedstatusstate',
        function()

            print(
                (
                    '^5[LB-VAMPIRE]^7 Feeding Status State | Active: %s | Debug: %s | NUIReady: %s | Level: %s'
                ):format(

                    tostring(
                        Status.active
                    ),

                    tostring(
                        Status.debugMode
                    ),

                    tostring(
                        Status.nuiReady
                    ),

                    tostring(
                        Status.currentLevel
                    )
                )
            )
        end,
        false
    )


    RegisterCommand(
        'vamfeedstatusclose',
        function()

            if Status.active then

                CloseStatus(
                    'debug_close'
                )
            end
        end,
        false
    )
end


---------------------------------------------------------
-- SPAWN
---------------------------------------------------------

AddEventHandler(
    'lb-vampire:client:spawnSelectionStarted',
    function()

        if Status.active then

            CloseStatus(
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


        CloseStatus(
            'resource_stop'
        )
    end
)