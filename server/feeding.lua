LBVampire = LBVampire or {}
LBVampire.Feeding =
    LBVampire.Feeding or {}

LBVampire.Runtime =
    LBVampire.Runtime or {}

LBVampire.Runtime.Interactions =
    LBVampire.Runtime.Interactions or {}

LBVampire.Runtime.FeedingRequests =
    LBVampire.Runtime.FeedingRequests or {}

LBVampire.Runtime.FeedingSessions =
    LBVampire.Runtime.FeedingSessions or {}

LBVampire.Runtime.FeedingCooldowns =
    LBVampire.Runtime.FeedingCooldowns or {}


local Feeding =
    LBVampire.Feeding


local requestSequence =
    0


---------------------------------------------------------
-- BASIC HELPERS
---------------------------------------------------------

local function GetCitizenId(
    source
)
    source =
        tonumber(source)


    if not source then
        return nil
    end


    if not LBVampire.Framework
        or not LBVampire.Framework.GetCitizenId then

        return nil
    end


    return LBVampire.Framework.GetCitizenId(
        source
    )
end


local function IsPlayerOnline(
    source
)
    source =
        tonumber(source)


    if not source
        or source <= 0 then

        return false
    end


    return GetPlayerName(
        source
    ) ~= nil
end


local function GetCharacterName(
    source
)
    if LBVampire.Framework
        and LBVampire.Framework.GetPlayerName then


        local name =
            LBVampire.Framework.GetPlayerName(
                source
            )


        if name
            and name ~= '' then

            return name
        end
    end


    return GetPlayerName(
        source
    )
        or (
            'Player %s'
        ):format(
            source
        )
end


local function Notify(
    source,
    message,
    notifyType,
    duration
)
    if not IsPlayerOnline(
        source
    ) then

        return
    end


    TriggerClientEvent(
        'lb-vampire:client:feedingNotify',

        source,

        message,

        notifyType
            or 'primary',

        duration
            or 5000
    )
end


---------------------------------------------------------
-- CONFIG HELPERS
---------------------------------------------------------

local function GetVampireMaximum()
    return tonumber(
        Config.Blood
            and Config.Blood.Max
    ) or 100
end


local function GetHumanBloodMaximum()
    return tonumber(
        Config.HumanBlood
            and Config.HumanBlood.Max
    ) or 100
end


local function GetTransferDuration()
    return tonumber(
        Config.Feeding
            and Config.Feeding.Transfer
            and Config.Feeding.Transfer.Duration
    ) or 30000
end


local function GetTransferTickInterval()
    local interval =
        tonumber(
            Config.Feeding
                and Config.Feeding.Transfer
                and Config.Feeding.Transfer.TickInterval
        )
        or 500


    return math.max(
        interval,
        100
    )
end


local function GetGainRatio()
    local ratio =
        tonumber(
            Config.Feeding
                and Config.Feeding.Transfer
                and Config.Feeding.Transfer.GainRatio
        )
        or 1.0


    return math.max(
        ratio,
        0.0
    )
end

---------------------------------------------------------
-- BLOOD AFFINITY
---------------------------------------------------------

local function GetBloodAffinity(
    vampireSource,
    humanSource
)
    -----------------------------------------------------
    -- Feature kapalıysa neutral.
    -----------------------------------------------------

    if not Config.BloodAffinity
        or Config.BloodAffinity.Enabled
            ~= true then


        return 1.0,
            {
                tier =
                    'DISABLED'
            }
    end


    -----------------------------------------------------
    -- Module yoksa feeding'i bozma.
    -----------------------------------------------------

    if not LBVampire.BloodAffinity
        or not LBVampire.BloodAffinity.GetMultiplier then


        if Config.Debug then

            print(
                '^3[LB-VAMPIRE]^7 BloodAffinity unavailable. Using x1.00.'
            )
        end


        return 1.0,
            {
                tier =
                    'UNAVAILABLE'
            }
    end


    -----------------------------------------------------
    -- Güvenli çağrı.
    -----------------------------------------------------

    local success,
        multiplier,
        details =
        pcall(
            LBVampire.BloodAffinity.GetMultiplier,
            vampireSource,
            humanSource
        )


    if not success then

        if Config.Debug then

            print(
                (
                    '^1[LB-VAMPIRE]^7 BloodAffinity error: %s'
                ):format(
                    tostring(
                        multiplier
                    )
                )
            )
        end


        return 1.0,
            {
                tier =
                    'ERROR'
            }
    end


    multiplier =
        tonumber(
            multiplier
        )
        or 1.0


    -----------------------------------------------------
    -- Bozuk config feeding'i durdurmasın.
    -----------------------------------------------------

    if multiplier <= 0 then
        multiplier = 1.0
    end


    return multiplier,
        details or {}
end


local function IsTransferEnabled()
    return Config.Feeding
        and Config.Feeding.Transfer
        and Config.Feeding.Transfer.Enabled
            == true
end


---------------------------------------------------------
-- DISTANCE
---------------------------------------------------------

local function DistanceBetweenPlayers(
    firstSource,
    secondSource
)
    if not IsPlayerOnline(
        firstSource
    )
        or not IsPlayerOnline(
            secondSource
        ) then

        return nil
    end


    local firstPed =
        GetPlayerPed(
            firstSource
        )


    local secondPed =
        GetPlayerPed(
            secondSource
        )


    if not firstPed
        or firstPed == 0
        or not secondPed
        or secondPed == 0 then

        return nil
    end


    local firstCoords =
        GetEntityCoords(
            firstPed
        )


    local secondCoords =
        GetEntityCoords(
            secondPed
        )


    local x =
        firstCoords.x -
        secondCoords.x


    local y =
        firstCoords.y -
        secondCoords.y


    local z =
        firstCoords.z -
        secondCoords.z


    return math.sqrt(
        (x * x)
        +
        (y * y)
        +
        (z * z)
    )
end


---------------------------------------------------------
-- HEALTH / AVAILABILITY
---------------------------------------------------------

local function IsPlayerUnavailable(
    source
)
    if not LBVampire.Framework
        or not LBVampire.Framework.GetPlayer then

        return false
    end


    local player =
        LBVampire.Framework.GetPlayer(
            source
        )


    if not player
        or not player.PlayerData then

        return true
    end


    local metadata =
        player.PlayerData.metadata
        or {}


    if metadata.isdead == true then
        return true
    end


    if metadata.inlaststand == true then
        return true
    end


    return false
end


---------------------------------------------------------
-- TOKEN
---------------------------------------------------------

local function GenerateToken(
    requesterCitizenId,
    targetCitizenId
)
    requestSequence =
        requestSequence + 1


    if requestSequence >
        999999 then

        requestSequence =
            1
    end


    return (
        '%s:%s:%s:%s:%s'
    ):format(

        os.time(),

        requesterCitizenId,

        targetCitizenId,

        requestSequence,

        math.random(
            100000,
            999999
        )
    )
end


---------------------------------------------------------
-- INTERACTION STATE
---------------------------------------------------------

local function GetInteractionByCitizenId(
    citizenId
)
    if not citizenId then
        return nil
    end


    return LBVampire.Runtime
        .Interactions[
            citizenId
        ]
end


function Feeding.GetInteraction(
    source
)
    local citizenId =
        GetCitizenId(
            source
        )


    if not citizenId then
        return nil
    end


    return GetInteractionByCitizenId(
        citizenId
    )
end


local function SyncInteractionToClient(
    source,
    interaction
)
    if not IsPlayerOnline(
        source
    ) then

        return
    end


    TriggerClientEvent(
        'lb-vampire:client:feedingState',

        source,

        {
            state =
                interaction
                and interaction.state
                or 'IDLE',

            partnerSource =
                interaction
                and interaction.partnerSource
                or nil,

            token =
                interaction
                and interaction.token
                or nil
        }
    )
end


local function SetInteraction(
    source,
    stateName,
    token,
    partnerSource
)
    source =
        tonumber(source)


    local citizenId =
        GetCitizenId(
            source
        )


    if not citizenId then
        return false
    end


    local interaction = {

        source =
            source,

        citizenId =
            citizenId,

        state =
            stateName
            or 'IDLE',

        token =
            token,

        partnerSource =
            tonumber(
                partnerSource
            )
    }


    if interaction.state ==
        'IDLE' then


        LBVampire.Runtime
            .Interactions[
                citizenId
            ] =
            nil


    else


        LBVampire.Runtime
            .Interactions[
                citizenId
            ] =
            interaction
    end


    -----------------------------------------------------
    -- Vampire runtime mirror
    -----------------------------------------------------

    if LBVampire.Vampires
        and LBVampire.Vampires.GetState then


        local vampireState =
            LBVampire.Vampires.GetState(
                source
            )


        if vampireState then

            vampireState.interactionState =
                interaction.state
        end
    end


    SyncInteractionToClient(
        source,
        interaction
    )


    return true
end


local function ClearInteractionBySource(
    source
)
    source =
        tonumber(source)


    if not source then
        return
    end


    for citizenId,
        interaction in pairs(
            LBVampire.Runtime.Interactions
        ) do


        if interaction.source ==
            source then


            LBVampire.Runtime
                .Interactions[
                    citizenId
                ] =
                nil
        end
    end
end


local function ResetInteractionIfTokenMatches(
    source,
    token
)
    if not IsPlayerOnline(
        source
    ) then

        return
    end


    local interaction =
        Feeding.GetInteraction(
            source
        )


    if not interaction then

        SetInteraction(
            source,
            'IDLE'
        )

        return
    end


    if token
        and interaction.token
            ~= token then

        return
    end


    SetInteraction(
        source,
        'IDLE'
    )
end


---------------------------------------------------------
-- SESSION PERSISTENCE
---------------------------------------------------------

local function PersistSessionState(
    session
)
    if not session then
        return
    end


    -----------------------------------------------------
    -- HUMAN BLOOD
    -----------------------------------------------------

    if IsPlayerOnline(
        session.targetSource
    )
        and LBVampire.HumanBlood
        and LBVampire.HumanBlood.Save then


        LBVampire.HumanBlood.Save(
            session.targetSource
        )
    end


    -----------------------------------------------------
    -- VAMPIRE BLOOD
    -----------------------------------------------------

    if IsPlayerOnline(
        session.requesterSource
    ) then


        local vampireState =
            LBVampire.Vampires.GetState(
                session.requesterSource
            )


        if vampireState
            and LBVampire.Persistence
            and LBVampire.Persistence.SaveRuntimeState then


            local success =
                LBVampire.Persistence
                    .SaveRuntimeState(
                        vampireState
                    )


            if success then

                vampireState.dirty =
                    false
            end
        end
    end
end


---------------------------------------------------------
-- STOP SESSION
---------------------------------------------------------

local function StopSession(
    token,
    reason
)
    local session =
        LBVampire.Runtime
            .FeedingSessions[
                token
            ]


    if not session then
        return false
    end


    reason =
        reason
        or 'cancelled'


    -----------------------------------------------------
    -- Remove session first.
    --
    -- Böylece aynı session ikinci kez
    -- tamamlanamaz.
    -----------------------------------------------------

    LBVampire.Runtime
        .FeedingSessions[
            token
        ] =
        nil


    session.state =
        'STOPPED'


    session.stoppedAt =
        os.time()


    session.stopReason =
        reason


    -----------------------------------------------------
    -- SAVE
    -----------------------------------------------------

    PersistSessionState(
        session
    )


    -----------------------------------------------------
    -- INTERACTION RESET
    -----------------------------------------------------

    ResetInteractionIfTokenMatches(
        session.requesterSource,
        token
    )


    ResetInteractionIfTokenMatches(
        session.targetSource,
        token
    )


    -----------------------------------------------------
    -- CLIENT
    -----------------------------------------------------

    if IsPlayerOnline(
        session.requesterSource
    ) then


        TriggerClientEvent(
            'lb-vampire:client:feedingStopped',

            session.requesterSource,

            reason
        )
    end


    if IsPlayerOnline(
        session.targetSource
    ) then


        TriggerClientEvent(
            'lb-vampire:client:feedingStopped',

            session.targetSource,

            reason
        )
    end


    if Config.Debug then

        print(
            (
                '^5[LB-VAMPIRE]^7 Feeding session STOPPED | %s -> %s | Reason: %s | Human drained: %.2f | Vampire gained: %.2f'
            ):format(

                session.requesterCitizenId,

                session.targetCitizenId,

                tostring(
                    reason
                ),

                tonumber(
                    session.totalHumanDrained
                ) or 0,

                tonumber(
                    session.totalVampireGained
                ) or 0
            )
        )
    end


    return true
end


---------------------------------------------------------
-- REQUEST VALIDATION
---------------------------------------------------------

local function ValidateNewRequest(
    requesterSource,
    targetSource
)
    requesterSource =
        tonumber(
            requesterSource
        )


    targetSource =
        tonumber(
            targetSource
        )


    if not Config.Feeding
        or Config.Feeding.Enabled
            ~= true then


        return false,
            'feeding_disabled'
    end


    if not requesterSource
        or not targetSource then


        return false,
            'invalid_player'
    end


    if requesterSource ==
        targetSource then


        return false,
            'cannot_feed_self'
    end


    if not IsPlayerOnline(
        requesterSource
    ) then


        return false,
            'requester_offline'
    end


    if not IsPlayerOnline(
        targetSource
    ) then


        return false,
            'target_offline'
    end


    -----------------------------------------------------
    -- REQUESTER MUST BE VAMPIRE
    -----------------------------------------------------

    if not LBVampire.Vampires
        or not LBVampire.Vampires.GetState then


        return false,
            'vampire_system_unavailable'
    end


    local vampireState =
        LBVampire.Vampires.GetState(
            requesterSource
        )


    if not vampireState then

        return false,
            'not_vampire'
    end


    -----------------------------------------------------
    -- VAMPIRE ALREADY FULL
    -----------------------------------------------------

    if tonumber(
        vampireState.blood
    ) >= GetVampireMaximum() then


        return false,
            'vampire_blood_full'
    end


    -----------------------------------------------------
    -- TARGET MUST BE HUMAN
    -----------------------------------------------------

    if Config.Feeding.AllowVampireTarget
        ~= true then


        local targetVampire =
            LBVampire.Vampires.GetState(
                targetSource
            )


        if targetVampire then

            return false,
                'target_is_vampire'
        end
    end


    -----------------------------------------------------
    -- TARGET MUST HAVE BLOOD
    -----------------------------------------------------

    if not LBVampire.HumanBlood
        or not LBVampire.HumanBlood.Get then


        return false,
            'humanblood_unavailable'
    end


    local targetHumanBlood =
        LBVampire.HumanBlood.Get(
            targetSource
        )


    if targetHumanBlood == nil then

        return false,
            'humanblood_unavailable'
    end


    if targetHumanBlood <= 0 then

        return false,
            'target_has_no_blood'
    end


    -----------------------------------------------------
    -- HEALTH
    -----------------------------------------------------

    if IsPlayerUnavailable(
        requesterSource
    ) then


        return false,
            'requester_unavailable'
    end


    if IsPlayerUnavailable(
        targetSource
    ) then


        return false,
            'target_unavailable'
    end


    -----------------------------------------------------
    -- BOTH IDLE
    -----------------------------------------------------

    if Feeding.GetInteraction(
        requesterSource
    ) then


        return false,
            'requester_busy'
    end


    if Feeding.GetInteraction(
        targetSource
    ) then


        return false,
            'target_busy'
    end


    -----------------------------------------------------
    -- DISTANCE
    -----------------------------------------------------

    local distance =
        DistanceBetweenPlayers(
            requesterSource,
            targetSource
        )


    if not distance then

        return false,
            'distance_unavailable'
    end


    local maximumDistance =
        tonumber(
            Config.Feeding.RequestDistance
        )
        or 2.5


    if distance >
        maximumDistance then


        return false,
            'too_far'
    end


    return true,
        vampireState
end


---------------------------------------------------------
-- CREATE REQUEST
---------------------------------------------------------

function Feeding.Request(
    requesterSource,
    targetSource
)
    requesterSource =
        tonumber(
            requesterSource
        )


    targetSource =
        tonumber(
            targetSource
        )


    -----------------------------------------------------
    -- COOLDOWN
    -----------------------------------------------------

    local requesterCitizenId =
        GetCitizenId(
            requesterSource
        )


    if not requesterCitizenId then

        return false,
            'requester_not_loaded'
    end


    local now =
        GetGameTimer()


    local cooldownUntil =
        tonumber(
            LBVampire.Runtime
                .FeedingCooldowns[
                    requesterCitizenId
                ]
        ) or 0


    if now <
        cooldownUntil then


        return false,
            'request_cooldown'
    end


    LBVampire.Runtime
        .FeedingCooldowns[
            requesterCitizenId
        ] =
        now
        +
        (
            tonumber(
                Config.Feeding.RequestCooldown
            )
            or 3000
        )


    -----------------------------------------------------
    -- VALIDATE
    -----------------------------------------------------

    local valid,
        reason =
        ValidateNewRequest(
            requesterSource,
            targetSource
        )


    if not valid then

        return false,
            reason
    end


    local targetCitizenId =
        GetCitizenId(
            targetSource
        )


    if not targetCitizenId then

        return false,
            'target_not_loaded'
    end


    -----------------------------------------------------
    -- SERVER TOKEN
    -----------------------------------------------------

    local token =
        GenerateToken(
            requesterCitizenId,
            targetCitizenId
        )


    local timeout =
        tonumber(
            Config.Feeding.ConsentTimeout
        )
        or 15000


    local request = {

        token =
            token,


        requesterSource =
            requesterSource,


        requesterCitizenId =
            requesterCitizenId,


        targetSource =
            targetSource,


        targetCitizenId =
            targetCitizenId,


        createdAt =
            os.time(),


        expiresAt =
            os.time()
            +
            math.ceil(
                timeout /
                1000
            ),


        status =
            'PENDING'
    }


    LBVampire.Runtime
        .FeedingRequests[
            token
        ] =
        request


    -----------------------------------------------------
    -- STATES
    -----------------------------------------------------

    SetInteraction(
        requesterSource,

        'REQUESTING',

        token,

        targetSource
    )


    SetInteraction(
        targetSource,

        'REQUESTED',

        token,

        requesterSource
    )


    -----------------------------------------------------
    -- CLIENT REQUEST
    -----------------------------------------------------

    TriggerClientEvent(
        'lb-vampire:client:feedingRequest',

        targetSource,

        {
            requesterSource =
                requesterSource,

            requesterName =
                GetCharacterName(
                    requesterSource
                ),

            timeout =
                timeout
        }
    )


    TriggerClientEvent(
        'lb-vampire:client:feedingRequestSent',

        requesterSource,

        {
            targetSource =
                targetSource,

            targetName =
                GetCharacterName(
                    targetSource
                ),

            timeout =
                timeout
        }
    )


    -----------------------------------------------------
    -- TIMEOUT
    -----------------------------------------------------

    SetTimeout(
        timeout,

        function()

            local current =
                LBVampire.Runtime
                    .FeedingRequests[
                        token
                    ]


            if not current
                or current.status
                    ~= 'PENDING' then

                return
            end


            current.status =
                'TIMEOUT'


            LBVampire.Runtime
                .FeedingRequests[
                    token
                ] =
                nil


            ResetInteractionIfTokenMatches(
                current.requesterSource,
                token
            )


            ResetInteractionIfTokenMatches(
                current.targetSource,
                token
            )


            Notify(
                current.requesterSource,

                'Beslenme isteğinin süresi doldu.',

                'error'
            )


            Notify(
                current.targetSource,

                'Beslenme isteğinin süresi doldu.',

                'primary'
            )


            if Config.Debug then

                print(
                    (
                        '^5[LB-VAMPIRE]^7 Feeding request TIMEOUT | %s -> %s'
                    ):format(

                        current.requesterCitizenId,

                        current.targetCitizenId
                    )
                )
            end
        end
    )


    if Config.Debug then

        print(
            (
                '^5[LB-VAMPIRE]^7 Feeding request CREATED | %s -> %s'
            ):format(

                requesterCitizenId,

                targetCitizenId
            )
        )
    end


    return true,
        token
end


---------------------------------------------------------
-- GET TARGET REQUEST
---------------------------------------------------------

local function GetPendingRequestForTarget(
    targetSource
)
    local interaction =
        Feeding.GetInteraction(
            targetSource
        )


    if not interaction
        or interaction.state
            ~= 'REQUESTED'
        or not interaction.token then


        return nil,
            'no_pending_request'
    end


    local request =
        LBVampire.Runtime
            .FeedingRequests[
                interaction.token
            ]


    if not request
        or request.status
            ~= 'PENDING' then


        return nil,
            'request_not_found'
    end


    return request
end


---------------------------------------------------------
-- ACCEPT
---------------------------------------------------------

function Feeding.Accept(
    targetSource
)
    targetSource =
        tonumber(
            targetSource
        )


    local request,
        reason =
        GetPendingRequestForTarget(
            targetSource
        )


    if not request then

        return false,
            reason
    end


    -----------------------------------------------------
    -- TARGET MATCH
    -----------------------------------------------------

    if request.targetSource
        ~= targetSource then


        return false,
            'invalid_target'
    end


    -----------------------------------------------------
    -- EXPIRY
    -----------------------------------------------------

    if os.time() >
        request.expiresAt then


        return false,
            'request_expired'
    end


    -----------------------------------------------------
    -- ONLINE
    -----------------------------------------------------

    if not IsPlayerOnline(
        request.requesterSource
    )
        or not IsPlayerOnline(
            request.targetSource
        ) then


        return false,
            'player_offline'
    end


    -----------------------------------------------------
    -- CITIZEN IDs STILL MATCH
    -----------------------------------------------------

    if GetCitizenId(
        request.requesterSource
    ) ~= request.requesterCitizenId then


        return false,
            'requester_changed'
    end


    if GetCitizenId(
        request.targetSource
    ) ~= request.targetCitizenId then


        return false,
            'target_changed'
    end


    -----------------------------------------------------
    -- REQUESTER STILL VAMPIRE
    -----------------------------------------------------

    local vampireState =
        LBVampire.Vampires.GetState(
            request.requesterSource
        )


    if not vampireState then

        return false,
            'requester_not_vampire'
    end


    -----------------------------------------------------
    -- TARGET STILL HUMAN
    -----------------------------------------------------

    if Config.Feeding.AllowVampireTarget
        ~= true then


        local targetVampire =
            LBVampire.Vampires.GetState(
                request.targetSource
            )


        if targetVampire then

            return false,
                'target_became_vampire'
        end
    end


    -----------------------------------------------------
    -- HEALTH
    -----------------------------------------------------

    if IsPlayerUnavailable(
        request.requesterSource
    )
        or IsPlayerUnavailable(
            request.targetSource
        ) then


        return false,
            'player_unavailable'
    end


    -----------------------------------------------------
    -- DISTANCE AGAIN
    -----------------------------------------------------

    local distance =
        DistanceBetweenPlayers(
            request.requesterSource,
            request.targetSource
        )


    if not distance then

        return false,
            'distance_unavailable'
    end


    if distance >
        (
            tonumber(
                Config.Feeding.AcceptDistance
            )
            or 3.0
        ) then


        LBVampire.Runtime
            .FeedingRequests[
                request.token
            ] =
            nil


        ResetInteractionIfTokenMatches(
            request.requesterSource,
            request.token
        )


        ResetInteractionIfTokenMatches(
            request.targetSource,
            request.token
        )


        Notify(
            request.requesterSource,

            'Hedef çok uzaklaştığı için beslenme isteği iptal edildi.',

            'error'
        )


        Notify(
            request.targetSource,

            'Çok uzaklaştığın için beslenme isteği iptal edildi.',

            'error'
        )


        return false,
            'too_far'
    end


    -----------------------------------------------------
    -- BLOOD VALIDATION
    -----------------------------------------------------

    local humanBlood =
        LBVampire.HumanBlood.Get(
            request.targetSource
        )


    if not humanBlood
        or humanBlood <= 0 then


        return false,
            'target_has_no_blood'
    end


    if tonumber(
        vampireState.blood
    ) >= GetVampireMaximum() then


        return false,
            'vampire_blood_full'
    end

-----------------------------------------------------
-- BLOOD AFFINITY
--
-- Session başında bir kez hesaplanır.
-- Tick başına tekrar DB/metadata okumayız.
-----------------------------------------------------

local bloodAffinityMultiplier,
        bloodAffinityDetails =
        GetBloodAffinity(
            request.requesterSource,
            request.targetSource
        )


    bloodAffinityDetails =
        bloodAffinityDetails or {}


    -----------------------------------------------------
    -- REQUEST COMPLETE
    -----------------------------------------------------

    request.status =
        'ACCEPTED'


    LBVampire.Runtime
        .FeedingRequests[
            request.token
        ] =
        nil


    -----------------------------------------------------
    -- CREATE FEEDING SESSION
    -----------------------------------------------------

    local nowMs =
        GetGameTimer()


    local session = {

        token =
            request.token,


        requesterSource =
            request.requesterSource,


        requesterCitizenId =
            request.requesterCitizenId,


        targetSource =
            request.targetSource,


        targetCitizenId =
            request.targetCitizenId,


        createdAt =
            request.createdAt,


        acceptedAt =
            os.time(),


        startedAtMs =
            nowMs,


        lastTickAtMs =
            nowMs,


        totalHumanDrained =
            0.0,


        totalVampireGained =
            0.0,


        -----------------------------------------------------
        -- BLOOD AFFINITY SNAPSHOT
        -----------------------------------------------------

        bloodAffinityMultiplier =
            bloodAffinityMultiplier,


        bloodAffinityTier =
            tostring(
                bloodAffinityDetails.tier
                or 'OTHER'
            ),


        preferredBloodType =
            bloodAffinityDetails.preference,


        targetBloodType =
            bloodAffinityDetails.humanBloodType,


        affinityNotificationSent =
            false,


        state =
            'FEEDING'
            }


    LBVampire.Runtime
        .FeedingSessions[
            request.token
        ] =
        session


    -----------------------------------------------------
    -- INTERACTION STATES
    -----------------------------------------------------

    SetInteraction(
        request.requesterSource,

        'FEEDING',

        request.token,

        request.targetSource
    )


    SetInteraction(
        request.targetSource,

        'FEEDING',

        request.token,

        request.requesterSource
    )


    -----------------------------------------------------
    -- CLIENTS
    -----------------------------------------------------

    TriggerClientEvent(
        'lb-vampire:client:feedingAccepted',

        request.requesterSource,

        {
            role =
                'VAMPIRE',

            partnerSource =
                request.targetSource,

            partnerName =
                GetCharacterName(
                    request.targetSource
                )
        }
    )


    TriggerClientEvent(
        'lb-vampire:client:feedingAccepted',

        request.targetSource,

        {
            role =
                'HUMAN',

            partnerSource =
                request.requesterSource,

            partnerName =
                GetCharacterName(
                    request.requesterSource
                )
        }
    )

    ---------------------------------------------------------
    -- AFFINITY DISCOVERY
    ---------------------------------------------------------

    if session.bloodAffinityTier ==
        'EXACT'
        and Config.BloodAffinity
        and Config.BloodAffinity.NotifyExactMatch
            == true then


        Notify(
            session.requesterSource,

            'Bu kan sende alışılmadık derecede güçlü bir etki bırakıyor.',

            'success',

            6500
        )


        session.affinityNotificationSent =
            true
    end

    if Config.Debug then

        print(
            (
                '^2[LB-VAMPIRE]^7 Feeding STARTED | %s -> %s | Vampire Blood: %.2f | HumanBlood: %.2f'
            ):format(

                request.requesterCitizenId,

                request.targetCitizenId,

                tonumber(
                    vampireState.blood
                ) or 0,

                tonumber(
                    humanBlood
                ) or 0
            )
        )
    end


    return true,
        session
end


---------------------------------------------------------
-- DECLINE
---------------------------------------------------------

function Feeding.Decline(
    targetSource
)
    targetSource =
        tonumber(
            targetSource
        )


    local request,
        reason =
        GetPendingRequestForTarget(
            targetSource
        )


    if not request then

        return false,
            reason
    end


    request.status =
        'DECLINED'


    LBVampire.Runtime
        .FeedingRequests[
            request.token
        ] =
        nil


    ResetInteractionIfTokenMatches(
        request.requesterSource,
        request.token
    )


    ResetInteractionIfTokenMatches(
        request.targetSource,
        request.token
    )


    Notify(
        request.requesterSource,

        (
            '%s beslenme isteğini reddetti.'
        ):format(
            GetCharacterName(
                request.targetSource
            )
        ),

        'error'
    )


    Notify(
        request.targetSource,

        'Beslenme isteğini reddettin.',

        'success'
    )


    if Config.Debug then

        print(
            (
                '^3[LB-VAMPIRE]^7 Feeding consent DECLINED | %s -> %s'
            ):format(

                request.requesterCitizenId,

                request.targetCitizenId
            )
        )
    end


    return true
end


---------------------------------------------------------
-- CANCEL
---------------------------------------------------------

function Feeding.Cancel(
    source,
    reason
)
    source =
        tonumber(
            source
        )


    local interaction =
        Feeding.GetInteraction(
            source
        )


    if not interaction
        or not interaction.token then


        return false,
            'not_in_interaction'
    end


    local token =
        interaction.token


    -----------------------------------------------------
    -- PENDING REQUEST
    -----------------------------------------------------

    local request =
        LBVampire.Runtime
            .FeedingRequests[
                token
            ]


    if request then


        LBVampire.Runtime
            .FeedingRequests[
                token
            ] =
            nil


        ResetInteractionIfTokenMatches(
            request.requesterSource,
            token
        )


        ResetInteractionIfTokenMatches(
            request.targetSource,
            token
        )


        Notify(
            request.requesterSource,

            'Beslenme isteği iptal edildi.',

            'primary'
        )


        Notify(
            request.targetSource,

            'Beslenme isteği iptal edildi.',

            'primary'
        )


        return true
    end


    -----------------------------------------------------
    -- ACTIVE SESSION
    -----------------------------------------------------

    if LBVampire.Runtime
        .FeedingSessions[
            token
        ] then


        return StopSession(
            token,
            reason
                or 'manual_cancel'
        )
    end


    ResetInteractionIfTokenMatches(
        source,
        token
    )


    return false,
        'interaction_not_found'
end


---------------------------------------------------------
-- PROCESS TRANSFER
---------------------------------------------------------

local function ProcessSession(
    token,
    session
)
    if not session
        or session.state
            ~= 'FEEDING' then

        return
    end


    -----------------------------------------------------
    -- ONLINE CHECK
    -----------------------------------------------------

    if not IsPlayerOnline(
        session.requesterSource
    )
        or not IsPlayerOnline(
            session.targetSource
        ) then


        StopSession(
            token,
            'player_disconnected'
        )


        return
    end


    -----------------------------------------------------
    -- CITIZEN ID CHECK
    -----------------------------------------------------

    if GetCitizenId(
        session.requesterSource
    ) ~= session.requesterCitizenId then


        StopSession(
            token,
            'requester_changed'
        )


        return
    end


    if GetCitizenId(
        session.targetSource
    ) ~= session.targetCitizenId then


        StopSession(
            token,
            'target_changed'
        )


        return
    end


    -----------------------------------------------------
    -- VAMPIRE CHECK
    -----------------------------------------------------

    local vampireState =
        LBVampire.Vampires.GetState(
            session.requesterSource
        )


    if not vampireState then


        StopSession(
            token,
            'requester_not_vampire'
        )


        return
    end


    -----------------------------------------------------
    -- TARGET MUST STILL BE HUMAN
    -----------------------------------------------------

    if Config.Feeding.AllowVampireTarget
        ~= true then


        local targetVampire =
            LBVampire.Vampires.GetState(
                session.targetSource
            )


        if targetVampire then


            StopSession(
                token,
                'target_became_vampire'
            )


            return
        end
    end


    -----------------------------------------------------
    -- CURRENT VALUES
    -----------------------------------------------------

    local vampireBlood =
        tonumber(
            vampireState.blood
        )
        or 0


    local humanBlood =
        LBVampire.HumanBlood.Get(
            session.targetSource
        )


    if humanBlood == nil then


        StopSession(
            token,
            'humanblood_unavailable'
        )


        return
    end


    local vampireMaximum =
        GetVampireMaximum()


    -----------------------------------------------------
    -- AUTO STOP
    -----------------------------------------------------

    if vampireBlood >=
        vampireMaximum then


        StopSession(
            token,
            'vampire_full'
        )


        return
    end


    if humanBlood <= 0 then


        StopSession(
            token,
            'human_empty'
        )


        return
    end


    -----------------------------------------------------
    -- DELTA TIME
    -----------------------------------------------------

    local nowMs =
        GetGameTimer()


    local lastTick =
        tonumber(
            session.lastTickAtMs
        )
        or nowMs


    local deltaMs =
        nowMs -
        lastTick


    if deltaMs <= 0 then
        return
    end


    session.lastTickAtMs =
        nowMs


    -----------------------------------------------------
    -- RATE
    --
    -- 100 / 30 seconds = 3.333... HB/sec
    -----------------------------------------------------

    local durationMs =
        math.max(
            GetTransferDuration(),
            1000
        )


    local humanBloodPerSecond =
        GetHumanBloodMaximum()
        /
        (
            durationMs /
            1000
        )


    local requestedDrain =
        humanBloodPerSecond
        *
        (
            deltaMs /
            1000
        )


    -----------------------------------------------------
    -- VAMPIRE CAPACITY
    -----------------------------------------------------

    local gainRatio =
    GetGainRatio()


if gainRatio <= 0 then


    StopSession(
        token,
        'invalid_gain_ratio'
    )


    return
end


-----------------------------------------------------
-- AFFINITY MULTIPLIER
-----------------------------------------------------

    local affinityMultiplier =
        tonumber(
            session.bloodAffinityMultiplier
        )
        or 1.0


    if affinityMultiplier <= 0 then
        affinityMultiplier = 1.0
    end


    -----------------------------------------------------
    -- EFFECTIVE GAIN
    --
    -- Example:
    --
    -- GainRatio        1.00
    -- Affinity         1.20
    --
    -- Effective gain   1.20
    -----------------------------------------------------

    local effectiveGainRatio =
        gainRatio *
        affinityMultiplier


    local vampireCapacity =
        vampireMaximum -
        vampireBlood


    -----------------------------------------------------
    -- Vampire capacity hesabında affinity de hesaba
    -- katılmak zorunda.
    --
    -- Aksi halde hedef gereğinden fazla HumanBlood
    -- kaybeder.
    -----------------------------------------------------

    local maximumHumanDrainForCapacity =
        vampireCapacity /
        effectiveGainRatio


    -----------------------------------------------------
    -- FINAL TRANSFER AMOUNT
    -----------------------------------------------------

    local transferAmount =
        math.min(

            requestedDrain,

            humanBlood,

            maximumHumanDrainForCapacity
        )


    if transferAmount <= 0 then


        StopSession(
            token,
            'nothing_to_transfer'
        )


        return
    end


    -----------------------------------------------------
    -- HUMAN BLOOD REMOVE
    -----------------------------------------------------

    local removed,
        newHumanBlood =
        LBVampire.HumanBlood.Remove(

            session.targetSource,

            transferAmount,

            false
        )


    if not removed then


        StopSession(
            token,
            'humanblood_transfer_failed'
        )


        return
    end


    -----------------------------------------------------
    -- VAMPIRE BLOOD ADD
    -----------------------------------------------------

    local vampireGain =
        transferAmount *
        effectiveGainRatio


    local added,
        newVampireBlood =
        LBVampire.Blood.Add(

            session.requesterSource,

            vampireGain,

            false
        )


    if not added then


        -------------------------------------------------
        -- ROLLBACK HUMAN BLOOD
        -------------------------------------------------

        LBVampire.HumanBlood.Add(

            session.targetSource,

            transferAmount,

            false
        )


        StopSession(
            token,
            'vampire_blood_transfer_failed'
        )


        return
    end


    -----------------------------------------------------
    -- SESSION STATS
    -----------------------------------------------------

    session.totalHumanDrained =
        (
            tonumber(
                session.totalHumanDrained
            )
            or 0
        )
        +
        transferAmount


    session.totalVampireGained =
        (
            tonumber(
                session.totalVampireGained
            )
            or 0
        )
        +
        vampireGain


    -----------------------------------------------------
    -- DEBUG
    -----------------------------------------------------

    if Config.Debug then

        print(
            (
                '^5[LB-VAMPIRE]^7 Feeding tick | Human: %.2f | Vampire: %.2f | Drain: %.2f | Gain: %.2f | Affinity: %s x%.2f'
            ):format(

                tonumber(
                    newHumanBlood
                )
                or 0,

                tonumber(
                    newVampireBlood
                )
                or 0,

                transferAmount,

                vampireGain,

                tostring(
                    session.bloodAffinityTier
                    or 'OTHER'
                ),

                affinityMultiplier
            )
        )
    end


    -----------------------------------------------------
    -- AUTO STOP AFTER TRANSFER
    -----------------------------------------------------

    if tonumber(
        newVampireBlood
    )
        and tonumber(
            newVampireBlood
        ) >=
        (
            vampireMaximum -
            0.001
        ) then


        StopSession(
            token,
            'vampire_full'
        )


        return
    end


    if tonumber(
        newHumanBlood
    )
        and tonumber(
            newHumanBlood
        ) <=
        0.001 then


        StopSession(
            token,
            'human_empty'
        )


        return
    end


    -----------------------------------------------------
    -- SAFETY DURATION LIMIT
    -----------------------------------------------------

    local elapsedMs =
        nowMs -
        session.startedAtMs


    if elapsedMs >=
        durationMs then


        StopSession(
            token,
            'duration_complete'
        )
    end
end


---------------------------------------------------------
-- TRANSFER LOOP
---------------------------------------------------------

CreateThread(function()

    while true do


        Wait(
            GetTransferTickInterval()
        )


        if Config.Feeding
            and Config.Feeding.Enabled == true
            and IsTransferEnabled() then


            local tokens = {}


            -------------------------------------------------
            -- Copy token list first.
            --
            -- ProcessSession StopSession yaparsa pairs
            -- iteration'ının ortasında tablo değişmesin.
            -------------------------------------------------

            for token in pairs(
                LBVampire.Runtime.FeedingSessions
            ) do


                tokens[
                    #tokens + 1
                ] =
                    token
            end


            for _,
                token in ipairs(
                    tokens
                ) do


                local session =
                    LBVampire.Runtime
                        .FeedingSessions[
                            token
                        ]


                if session then

                    ProcessSession(
                        token,
                        session
                    )
                end
            end
        end
    end
end)


---------------------------------------------------------
-- NETWORK EVENTS
---------------------------------------------------------

RegisterNetEvent(
    'lb-vampire:server:requestFeeding',

    function(
        targetSource
    )

        local playerSource =
            tonumber(
                source
            )


        local success,
            reason =
            Feeding.Request(

                playerSource,

                targetSource
            )


        if not success then


            Notify(
                playerSource,

                (
                    'Beslenme isteği başarısız: %s'
                ):format(
                    tostring(
                        reason
                    )
                ),

                'error'
            )
        end
    end
)


RegisterNetEvent(
    'lb-vampire:server:acceptFeeding',

    function()

        local playerSource =
            tonumber(
                source
            )


        local success,
            reason =
            Feeding.Accept(
                playerSource
            )


        if not success then


            Notify(
                playerSource,

                (
                    'Beslenme isteği kabul edilemedi: %s'
                ):format(
                    tostring(
                        reason
                    )
                ),

                'error'
            )
        end
    end
)


RegisterNetEvent(
    'lb-vampire:server:declineFeeding',

    function()

        local playerSource =
            tonumber(
                source
            )


        local success,
            reason =
            Feeding.Decline(
                playerSource
            )


        if not success then


            Notify(
                playerSource,

                (
                    'Beslenme isteği reddedilemedi: %s'
                ):format(
                    tostring(
                        reason
                    )
                ),

                'error'
            )
        end
    end
)


RegisterNetEvent(
    'lb-vampire:server:cancelFeeding',

    function()

        local playerSource =
            tonumber(
                source
            )


        Feeding.Cancel(
            playerSource,
            'manual_cancel'
        )
    end
)


---------------------------------------------------------
-- PLAYER DROPPED
---------------------------------------------------------

AddEventHandler(
    'playerDropped',

    function()

        local droppedSource =
            tonumber(
                source
            )


        -------------------------------------------------
        -- REQUEST CLEANUP
        -------------------------------------------------

        local requestsToRemove =
            {}


        for token,
            request in pairs(
                LBVampire.Runtime.FeedingRequests
            ) do


            if request.requesterSource ==
                droppedSource
                or request.targetSource ==
                    droppedSource then


                requestsToRemove[
                    #requestsToRemove + 1
                ] =
                    token
            end
        end


        for _,
            token in ipairs(
                requestsToRemove
            ) do


            local request =
                LBVampire.Runtime
                    .FeedingRequests[
                        token
                    ]


            if request then


                LBVampire.Runtime
                    .FeedingRequests[
                        token
                    ] =
                    nil


                local otherSource


                if request.requesterSource ==
                    droppedSource then


                    otherSource =
                        request.targetSource


                else


                    otherSource =
                        request.requesterSource
                end


                ResetInteractionIfTokenMatches(
                    otherSource,
                    token
                )


                Notify(
                    otherSource,

                    'Diğer oyuncu ayrıldığı için beslenme işlemi iptal edildi.',

                    'error'
                )
            end
        end


        -------------------------------------------------
        -- SESSION CLEANUP
        -------------------------------------------------

        local sessionsToStop =
            {}


        for token,
            session in pairs(
                LBVampire.Runtime.FeedingSessions
            ) do


            if session.requesterSource ==
                droppedSource
                or session.targetSource ==
                    droppedSource then


                sessionsToStop[
                    #sessionsToStop + 1
                ] =
                    token
            end
        end


        for _,
            token in ipairs(
                sessionsToStop
            ) do


            StopSession(
                token,
                'player_disconnected'
            )
        end


        -------------------------------------------------
        -- DROPPED STATE
        -------------------------------------------------

        ClearInteractionBySource(
            droppedSource
        )
    end
)


---------------------------------------------------------
-- RESOURCE STOP
---------------------------------------------------------

AddEventHandler(
    'onResourceStop',

    function(
        resourceName
    )

        if resourceName ~=
            GetCurrentResourceName() then

            return
        end


        for _,
            session in pairs(
                LBVampire.Runtime.FeedingSessions
            ) do


            PersistSessionState(
                session
            )
        end
    end
)


---------------------------------------------------------
-- DEBUG COMMANDS
---------------------------------------------------------

if Config.Debug
    and Config.Feeding.DebugCommands then


    -----------------------------------------------------
    -- /vamfeed [serverId]
    -----------------------------------------------------

    RegisterCommand(
        'vamfeed',

        function(
            source,
            args
        )

            if source <= 0 then
                return
            end


            local targetSource =
                tonumber(
                    args[1]
                )


            if not targetSource then


                Notify(
                    source,

                    'Usage: /vamfeed [server id]',

                    'error'
                )


                return
            end


            local success,
                reason =
                Feeding.Request(

                    source,

                    targetSource
                )


            if not success then


                Notify(
                    source,

                    (
                        'Feeding request failed: %s'
                    ):format(
                        tostring(
                            reason
                        )
                    ),

                    'error'
                )
            end
        end,

        false
    )


    -----------------------------------------------------
    -- /vamfeedaccept
    -----------------------------------------------------

    RegisterCommand(
        'vamfeedaccept',

        function(
            source
        )

            if source <= 0 then
                return
            end


            local success,
                reason =
                Feeding.Accept(
                    source
                )


            if not success then


                Notify(
                    source,

                    (
                        'Accept failed: %s'
                    ):format(
                        tostring(
                            reason
                        )
                    ),

                    'error'
                )
            end
        end,

        false
    )


    -----------------------------------------------------
    -- /vamfeeddecline
    -----------------------------------------------------

    RegisterCommand(
        'vamfeeddecline',

        function(
            source
        )

            if source <= 0 then
                return
            end


            local success,
                reason =
                Feeding.Decline(
                    source
                )


            if not success then


                Notify(
                    source,

                    (
                        'Decline failed: %s'
                    ):format(
                        tostring(
                            reason
                        )
                    ),

                    'error'
                )
            end
        end,

        false
    )


    -----------------------------------------------------
    -- /vamfeedcancel
    -----------------------------------------------------

    RegisterCommand(
        'vamfeedcancel',

        function(
            source
        )

            if source <= 0 then
                return
            end


            local success,
                reason =
                Feeding.Cancel(
                    source,
                    'manual_cancel'
                )


            if not success then


                Notify(
                    source,

                    (
                        'Cancel failed: %s'
                    ):format(
                        tostring(
                            reason
                        )
                    ),

                    'error'
                )
            end
        end,

        false
    )


    -----------------------------------------------------
    -- /vamfeedstate
    -----------------------------------------------------

    RegisterCommand(
        'vamfeedstate',

        function(
            source
        )

            if source <= 0 then
                return
            end


            local interaction =
                Feeding.GetInteraction(
                    source
                )


            local message


            if not interaction then


                message =
                    'Interaction State: IDLE'


            else


                message =
                    (
                        'Interaction State: %s | Partner: %s'
                    ):format(

                        interaction.state,

                        tostring(
                            interaction.partnerSource
                        )
                    )
            end


            Notify(
                source,

                message,

                'primary',

                7000
            )


            print(
                '^5[LB-VAMPIRE]^7 '
                .. message
            )
        end,

        false
    )
end