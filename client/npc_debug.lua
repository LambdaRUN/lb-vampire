LBVampire = LBVampire or {}

LBVampire.NPCDebug =
    LBVampire.NPCDebug or {}


local NPCDebug =
    LBVampire.NPCDebug


---------------------------------------------------------
-- CONFIG
---------------------------------------------------------

local function GetConfig()

    return Config.NPCFeeding
        and Config.NPCFeeding.Debug
        or {}
end


local function GetTargetConfig()

    return GetConfig().Target
        or {}
end


---------------------------------------------------------
-- SPAWN READY
---------------------------------------------------------

local function IsSpawnReady()

    if LBVampire.Spawn
        and LBVampire.Spawn.IsReady then


        return LBVampire.Spawn.IsReady()
    end


    return NetworkIsPlayerActive(
        PlayerId()
    )
end


---------------------------------------------------------
-- HUMAN NPC
---------------------------------------------------------

local function IsHumanNPC(
    entity
)
    if not entity
        or entity == 0
        or not DoesEntityExist(
            entity
        ) then


        return false
    end


    if not IsEntityAPed(
        entity
    ) then


        return false
    end


    -----------------------------------------------------
    -- Gerçek player olmaz.
    -----------------------------------------------------

    if IsPedAPlayer(
        entity
    ) then


        return false
    end


    -----------------------------------------------------
    -- Hayvan olmaz.
    -----------------------------------------------------

    if not IsPedHuman(
        entity
    ) then


        return false
    end


    -----------------------------------------------------
    -- Ölü NPC tekrar hedeflenmez.
    -----------------------------------------------------

    if IsEntityDead(
        entity
    )
        or GetEntityHealth(
            entity
        ) <= 0 then


        return false
    end


    return true
end


---------------------------------------------------------
-- CAN DEPLETE
---------------------------------------------------------

function NPCDebug.CanDeplete(
    entity,
    distance
)
    -----------------------------------------------------
    -- GLOBAL DEBUG
    -----------------------------------------------------

    if Config.Debug ~= true then

        return false
    end


    -----------------------------------------------------
    -- NPC DEBUG
    -----------------------------------------------------

    local config =
        GetConfig()


    if config.Enabled ~= true then

        return false
    end


    local targetConfig =
        GetTargetConfig()


    if targetConfig.Enabled ~= true then

        return false
    end


    -----------------------------------------------------
    -- SPAWN
    -----------------------------------------------------

    if not IsSpawnReady() then

        return false
    end


    -----------------------------------------------------
    -- VAMPIRE ONLY
    -----------------------------------------------------

    if not LBVampire.ClientState
        or LBVampire.ClientState.isVampire
            ~= true then


        return false
    end


    -----------------------------------------------------
    -- NPC
    -----------------------------------------------------

    if not IsHumanNPC(
        entity
    ) then


        return false
    end


    -----------------------------------------------------
    -- DISTANCE
    -----------------------------------------------------

    local maximumDistance =
        tonumber(
            targetConfig.Distance
        )
        or 2.5


    if distance
        and tonumber(
            distance
        )
        and tonumber(
            distance
        ) > maximumDistance then


        return false
    end


    return true
end


---------------------------------------------------------
-- NETWORK ENTITY
---------------------------------------------------------

local function GetOrCreateNetId(
    entity
)
    if not entity
        or entity == 0
        or not DoesEntityExist(
            entity
        ) then


        return nil
    end


    -----------------------------------------------------
    -- Ambient NPC henüz networked olmayabilir.
    -----------------------------------------------------

    if not NetworkGetEntityIsNetworked(
        entity
    ) then


        NetworkRegisterEntityAsNetworked(
            entity
        )


        local timeout =
            GetGameTimer()
            + 1000


        while not NetworkGetEntityIsNetworked(
            entity
        ) do


            Wait(
                20
            )


            if GetGameTimer() >=
                timeout then


                return nil
            end
        end
    end


    local netId =
        NetworkGetNetworkIdFromEntity(
            entity
        )


    netId =
        tonumber(
            netId
        )


    if not netId
        or netId <= 0 then


        return nil
    end


    return netId
end


---------------------------------------------------------
-- DEPLETE
---------------------------------------------------------

function NPCDebug.Deplete(
    entity
)
    if not NPCDebug.CanDeplete(
        entity
    ) then


        return false
    end


    local netId =
        GetOrCreateNetId(
            entity
        )


    if not netId then


        TriggerEvent(
            'QBCore:Notify',
            'NPC network kimliği oluşturulamadı.',
            'error',
            5000
        )


        return false
    end


    -----------------------------------------------------
    -- GERÇEK SERVER PIPELINE
    -----------------------------------------------------

    TriggerServerEvent(
        'lb-vampire:server:debugDepleteNPC',
        netId
    )


    if Config.Debug then

        print(
            (
                '^5[LB-VAMPIRE]^7 NPC depletion requested through qb-target | NetID: %s'
            ):format(
                tostring(
                    netId
                )
            )
        )
    end


    return true
end


---------------------------------------------------------
-- EXPORTS
---------------------------------------------------------

exports(
    'CanDebugDepleteNPC',
    function(
        entity,
        distance
    )

        return NPCDebug.CanDeplete(
            entity,
            distance
        )
    end
)


exports(
    'DebugDepleteNPC',
    function(
        entity
    )

        return NPCDebug.Deplete(
            entity
        )
    end
)