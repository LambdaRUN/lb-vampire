LBVampire = LBVampire or {}

LBVampire.DispatchProviders =
    LBVampire.DispatchProviders or {}


local Provider = {}


---------------------------------------------------------
-- CONFIG
---------------------------------------------------------

local function GetConfig()

    return Config.Dispatch
        and Config.Dispatch.PS
        or {}
end


---------------------------------------------------------
-- RESOURCE
---------------------------------------------------------

local function GetResourceName()

    return tostring(
        GetConfig().Resource
        or 'ps-dispatch'
    )
end


---------------------------------------------------------
-- IS AVAILABLE
---------------------------------------------------------

function Provider.IsAvailable()

    return GetResourceState(
        GetResourceName()
    ) == 'started'
end


---------------------------------------------------------
-- PROFILE
---------------------------------------------------------

local function GetProfile(
    kind
)
    local profiles =
        GetConfig().Profiles
        or {}


    kind =
        string.lower(
            tostring(
                kind
                or 'suspicious'
            )
        )


    if kind == 'npc_death'
        or kind == 'npcdeath' then


        return profiles.NPCDeath
            or {}
    end


    if kind == 'beast_call'
        or kind == 'beastcall'
        or kind == 'animal' then


        return profiles.BeastCall
            or {}
    end


    return profiles.Suspicious
        or {}
end


---------------------------------------------------------
-- PLAYER ONLINE
---------------------------------------------------------

local function IsPlayerOnline(
    source
)
    source =
        tonumber(
            source
        )


    if not source
        or source <= 0 then


        return false
    end


    return GetPlayerName(
        source
    ) ~= nil
end


---------------------------------------------------------
-- RELAY PLAYER
--
-- PS-Dispatch'in resmi API akışı:
--
-- CLIENT
--      ↓
-- TriggerServerEvent
--      ↓
-- ps-dispatch:server:notify
--
-- Bu nedenle LB-VAMPIRE server bir online client'ı
-- yalnızca transport/relay olarak kullanır.
---------------------------------------------------------

local function ResolveRelaySource(
    preferredSource
)
    -----------------------------------------------------
    -- Olayı başlatan oyuncu hâlâ online ise
    -- öncelikle onu kullan.
    -----------------------------------------------------

    if IsPlayerOnline(
        preferredSource
    ) then


        return tonumber(
            preferredSource
        )
    end


    -----------------------------------------------------
    -- Preferred source yoksa herhangi bir online
    -- oyuncu relay olabilir.
    --
    -- Relay oyuncunun polis olması gerekmez.
    -- PS-Dispatch server daha sonra alert'i uygun
    -- job'lara kendisi dağıtır.
    -----------------------------------------------------

    local players =
        GetPlayers()


    for i = 1,
        #players do


        local playerSource =
            tonumber(
                players[i]
            )


        if IsPlayerOnline(
            playerSource
        ) then


            return playerSource
        end
    end


    return nil
end


---------------------------------------------------------
-- SEND
---------------------------------------------------------

function Provider.Send(
    data
)
    data =
        data or {}


    -----------------------------------------------------
    -- RESOURCE
    -----------------------------------------------------

    if not Provider.IsAvailable() then

        return false,
            'ps_dispatch_not_started'
    end


    -----------------------------------------------------
    -- COORDS
    -----------------------------------------------------

    local coords =
        data.coords


    if not coords then

        return false,
            'missing_coords'
    end


    -----------------------------------------------------
    -- PROFILE
    -----------------------------------------------------

    local profile =
        GetProfile(
            data.kind
        )


    -----------------------------------------------------
    -- RELAY CLIENT
    -----------------------------------------------------

    local relaySource =
        ResolveRelaySource(
            data.source
        )


    if not relaySource then

        return false,
            'no_relay_player'
    end


    -----------------------------------------------------
    -- DISPATCH DATA
    --
    -- Vector3'ü client tarafında oluşturacağız.
    -- Network transferinde plain table kullanıyoruz.
    -----------------------------------------------------

    local dispatchData = {

        message =
            tostring(
                data.description
                or data.message
                or 'Şüpheli bir olay bildirildi.'
            ),

        codeName =
            tostring(
                data.codeName
                or profile.CodeName
                or 'civdead'
            ),

        code =
            tostring(
                data.code
                or profile.Code
                or '10-66'
            ),

        icon =
            tostring(
                data.icon
                or profile.Icon
                or 'fas fa-triangle-exclamation'
            ),

        priority =
            tonumber(
                data.priority
                or profile.Priority
            )
            or 2,

        coords = {

            x =
                tonumber(
                    coords.x
                )
                or 0.0,

            y =
                tonumber(
                    coords.y
                )
                or 0.0,

            z =
                tonumber(
                    coords.z
                )
                or 0.0
        },

        -------------------------------------------------
        -- Client gerçek street name üretmeye çalışacak.
        -------------------------------------------------

        street =
            data.street,

        heading =
            tonumber(
                data.heading
            )
            or 0,

        jobs =
            data.jobs
            or profile.Jobs
            or {
                'leo',
                'police'
            }
    }


    -----------------------------------------------------
    -- SERVER -> LB-VAMPIRE CLIENT RELAY
    -----------------------------------------------------

    TriggerClientEvent(
        'lb-vampire:client:psDispatchRelay',

        relaySource,

        dispatchData
    )


    if Config.Debug then

        print(
            (
                '^2[LB-VAMPIRE]^7 PS dispatch relay requested | Relay: %s | CodeName: %s | Code: %s'
            ):format(

                tostring(
                    relaySource
                ),

                tostring(
                    dispatchData.codeName
                ),

                tostring(
                    dispatchData.code
                )
            )
        )
    end


    return true,
        {
            provider =
                'ps',

            relaySource =
                relaySource,

            codeName =
                dispatchData.codeName
        }
end


---------------------------------------------------------
-- CLIENT RELAY DEBUG ACK
---------------------------------------------------------

RegisterNetEvent(
    'lb-vampire:server:psDispatchRelayComplete',

    function(
        codeName
    )
        if Config.Debug ~= true then

            return
        end


        print(
            (
                '^2[LB-VAMPIRE]^7 PS dispatch relay completed | Source: %s | CodeName: %s'
            ):format(

                tostring(
                    source
                ),

                tostring(
                    codeName
                )
            )
        )
    end
)


---------------------------------------------------------
-- REGISTER PROVIDER
---------------------------------------------------------

LBVampire.DispatchProviders.PS =
    Provider