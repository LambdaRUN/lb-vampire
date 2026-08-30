LBVampire = LBVampire or {}

LBVampire.ClientState =
    LBVampire.ClientState or {}

LBVampire.Interactions =
    LBVampire.Interactions or {}


local ClientState =
    LBVampire.ClientState


local Interactions =
    LBVampire.Interactions


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
-- LOCAL PLAYER READY
---------------------------------------------------------

local function IsSpawnReady()
    if LBVampire.Spawn
        and LBVampire.Spawn.IsReady then


        return LBVampire.Spawn.IsReady()
    end


    -----------------------------------------------------
    -- Spawn bridge bulunamazsa generic fallback.
    -----------------------------------------------------

    return NetworkIsPlayerActive(
        PlayerId()
    )
end


---------------------------------------------------------
-- ENTITY -> SERVER ID
---------------------------------------------------------

function Interactions.GetPlayerServerIdFromEntity(
    entity
)
    if not entity
        or entity == 0
        or not DoesEntityExist(
            entity
        ) then


        return nil
    end


    if not IsEntityAPed(
        entity
    ) then


        return nil
    end


    if not IsPedAPlayer(
        entity
    ) then


        return nil
    end


    local playerIndex =
        NetworkGetPlayerIndexFromPed(
            entity
        )


    if playerIndex == -1 then
        return nil
    end


    local serverId =
        GetPlayerServerId(
            playerIndex
        )


    serverId =
        tonumber(
            serverId
        )


    if not serverId
        or serverId <= 0 then


        return nil
    end


    -----------------------------------------------------
    -- SELF CHECK
    -----------------------------------------------------

    local myServerId =
        GetPlayerServerId(
            PlayerId()
        )


    if serverId ==
        myServerId then


        return nil
    end


    return serverId
end


---------------------------------------------------------
-- CAN REQUEST FEEDING
---------------------------------------------------------

function Interactions.CanRequestFeeding(
    entity,
    distance
)
    -----------------------------------------------------
    -- FEATURE ENABLED
    -----------------------------------------------------

    if not Config.Feeding
        or Config.Feeding.Enabled
            ~= true then


        return false
    end


    -----------------------------------------------------
    -- SPAWN READY
    -----------------------------------------------------

    if not IsSpawnReady() then
        return false
    end


    -----------------------------------------------------
    -- MUST BE VAMPIRE
    -----------------------------------------------------

    if ClientState.isVampire
        ~= true then


        return false
    end


    -----------------------------------------------------
    -- LOCAL STATE MUST BE IDLE
    -----------------------------------------------------

    local interactionState =
        ClientState.interactionState
        or 'IDLE'


    if interactionState ~=
        'IDLE' then


        return false
    end


    -----------------------------------------------------
    -- VALID PLAYER TARGET
    -----------------------------------------------------

    local targetServerId =
        Interactions
            .GetPlayerServerIdFromEntity(
                entity
            )


    if not targetServerId then
        return false
    end


    -----------------------------------------------------
    -- TARGET PED DEAD
    --
    -- Server yine authoritative kontrol yapacak.
    -----------------------------------------------------

    if IsEntityDead(
        entity
    ) then


        return false
    end


    -----------------------------------------------------
    -- OPTIONAL DISTANCE CHECK
    -----------------------------------------------------

    local maximumDistance =
        tonumber(
            Config.Interactions
                and Config.Interactions.Target
                and Config.Interactions.Target.Feeding
                and Config.Interactions.Target.Feeding.Distance
        )
        or tonumber(
            Config.Feeding.RequestDistance
        )
        or 2.5


    if distance
        and tonumber(distance)
        and tonumber(distance) >
            maximumDistance then


        return false
    end


    return true
end


---------------------------------------------------------
-- REQUEST FEEDING
---------------------------------------------------------

function Interactions.RequestFeeding(
    entity
)
    -----------------------------------------------------
    -- Recheck.
    -----------------------------------------------------

    if not Interactions.CanRequestFeeding(
        entity
    ) then


        Notify(
            'Bu oyuncuyla şu anda beslenme etkileşimi kuramazsın.',
            'error'
        )


        return false
    end


    local targetServerId =
        Interactions
            .GetPlayerServerIdFromEntity(
                entity
            )


    if not targetServerId then


        Notify(
            'Hedef oyuncu bulunamadı.',
            'error'
        )


        return false
    end


    -----------------------------------------------------
    -- SERVER AUTHORITATIVE REQUEST
    -----------------------------------------------------

    TriggerServerEvent(
        'lb-vampire:server:requestFeeding',
        targetServerId
    )


    if Config.Debug then

        print(
            (
                '^5[LB-VAMPIRE]^7 Feeding interaction requested | Target Server ID: %s'
            ):format(
                tostring(
                    targetServerId
                )
            )
        )
    end


    return true
end


---------------------------------------------------------
-- GENERIC LOCAL EVENT
--
-- Target adapterları bunu kullanabilir.
---------------------------------------------------------

AddEventHandler(
    'lb-vampire:client:interactionRequestFeeding',
    function(entity)

        Interactions.RequestFeeding(
            entity
        )
    end
)


---------------------------------------------------------
-- EXPORTS
--
-- Custom interaction/target scriptleri isterse direkt
-- LB-VAMPIRE API'sini kullanabilir.
---------------------------------------------------------

exports(
    'CanRequestFeeding',
    function(
        entity,
        distance
    )

        return Interactions.CanRequestFeeding(
            entity,
            distance
        )
    end
)


exports(
    'RequestFeeding',
    function(entity)

        return Interactions.RequestFeeding(
            entity
        )
    end
)