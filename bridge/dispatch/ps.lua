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
-- SEND
---------------------------------------------------------

function Provider.Send(
    data
)
    data =
        data or {}


    if not Provider.IsAvailable() then

        return false,
            'ps_dispatch_not_started'
    end


    local coords =
        data.coords


    if not coords then

        return false,
            'missing_coords'
    end


    local profile =
        GetProfile(
            data.kind
        )


    -----------------------------------------------------
    -- PS DISPATCH DATA
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

        coords =
            vector3(

                tonumber(
                    coords.x
                )
                or 0.0,

                tonumber(
                    coords.y
                )
                or 0.0,

                tonumber(
                    coords.z
                )
                or 0.0
            ),

        -------------------------------------------------
        -- PS UI bu alanı gösterebilir.
        -- Server-side street native bağımlılığı
        -- yaratmamak için genel başlık kullanıyoruz.
        -------------------------------------------------

        street =
            tostring(
                data.street
                or data.title
                or 'Bilinmeyen Bölge'
            ),

        heading =
            tonumber(
                data.heading
            )
            or 0,

        jobs =
            data.jobs
            or profile.Jobs
            or {
                'leo'
            }
    }


    -----------------------------------------------------
    -- ÖNEMLİ:
    --
    -- Güncel ps-dispatch server/main.lua bu eventte
    -- source kullanmadan dispatch datasını kaydediyor
    -- ve clientlara broadcast ediyor.
    --
    -- Bu yüzden server -> local TriggerEvent uygundur.
    -----------------------------------------------------

    TriggerEvent(
        'ps-dispatch:server:notify',
        dispatchData
    )


    if Config.Debug then

        print(
            (
                '^2[LB-VAMPIRE]^7 PS dispatch sent | CodeName: %s | Code: %s | %s'
            ):format(

                tostring(
                    dispatchData.codeName
                ),

                tostring(
                    dispatchData.code
                ),

                tostring(
                    dispatchData.message
                )
            )
        )
    end


    return true,
        {
            provider =
                'ps',

            codeName =
                dispatchData.codeName
        }
end


---------------------------------------------------------
-- REGISTER PROVIDER
---------------------------------------------------------

LBVampire.DispatchProviders.PS =
    Provider