LBVampire = LBVampire or {}

LBVampire.BloodAffinity =
    LBVampire.BloodAffinity or {}

LBVampire.Runtime =
    LBVampire.Runtime or {}

LBVampire.Runtime.BloodAffinity =
    LBVampire.Runtime.BloodAffinity or {}


local BloodAffinity =
    LBVampire.BloodAffinity


local Runtime =
    LBVampire.Runtime.BloodAffinity


---------------------------------------------------------
-- QBCORE
---------------------------------------------------------

local QBCore =
    exports['qb-core']
        :GetCoreObject()


---------------------------------------------------------
-- CONFIG
---------------------------------------------------------

local function GetConfig()
    return Config.BloodAffinity
        or {}
end


---------------------------------------------------------
-- NORMALIZE BLOOD TYPE
---------------------------------------------------------

local function NormalizeBloodType(
    bloodType
)
    if bloodType == nil then
        return nil
    end


    bloodType =
        string.upper(
            tostring(
                bloodType
            )
        )


    bloodType =
        bloodType:gsub(
            '%s+',
            ''
        )


    if bloodType == '' then
        return nil
    end


    return bloodType
end


---------------------------------------------------------
-- VALID TYPE
---------------------------------------------------------

local function IsValidBloodType(
    bloodType
)
    bloodType =
        NormalizeBloodType(
            bloodType
        )


    if not bloodType then
        return false
    end


    local types =
        GetConfig().BloodTypes
        or {}


    for i = 1,
        #types do


        if NormalizeBloodType(
            types[i]
        ) == bloodType then


            return true
        end
    end


    return false
end


---------------------------------------------------------
-- ABO GROUP
---------------------------------------------------------

local function GetABOGroup(
    bloodType
)
    bloodType =
        NormalizeBloodType(
            bloodType
        )


    if not bloodType then
        return nil
    end


    local finalCharacter =
        bloodType:sub(
            -1
        )


    if finalCharacter == '+'
        or finalCharacter == '-' then


        return bloodType:sub(
            1,
            -2
        )
    end


    return bloodType
end


---------------------------------------------------------
-- CITIZEN ID
---------------------------------------------------------

local function GetCitizenId(
    source
)
    source =
        tonumber(source)


    if not source then
        return nil
    end


    if LBVampire.Framework
        and LBVampire.Framework.GetCitizenId then


        return LBVampire.Framework.GetCitizenId(
            source
        )
    end


    local Player =
        QBCore.Functions.GetPlayer(
            source
        )


    return Player
        and Player.PlayerData
        and Player.PlayerData.citizenid
        or nil
end


---------------------------------------------------------
-- VAMPIRE CHECK
---------------------------------------------------------

local function IsVampire(
    citizenId
)
    if not citizenId then
        return false
    end


    return LBVampire.Runtime
        and LBVampire.Runtime.Vampires
        and LBVampire.Runtime
            .Vampires[citizenId]
            ~= nil
end


---------------------------------------------------------
-- QB CHARACTER BLOOD TYPE
---------------------------------------------------------

function BloodAffinity.GetHumanBloodType(
    source
)
    source =
        tonumber(source)


    if not source then
        return nil
    end


    -----------------------------------------------------
    -- Framework bridge varsa önce onu kullan.
    -----------------------------------------------------

    if LBVampire.Framework then

        if LBVampire.Framework.GetBloodType then

            local bloodType =
                NormalizeBloodType(
                    LBVampire.Framework.GetBloodType(
                        source
                    )
                )


            if IsValidBloodType(
                bloodType
            ) then

                return bloodType
            end
        end


        if LBVampire.Framework.GetPlayerBloodType then

            local bloodType =
                NormalizeBloodType(
                    LBVampire.Framework.GetPlayerBloodType(
                        source
                    )
                )


            if IsValidBloodType(
                bloodType
            ) then

                return bloodType
            end
        end
    end

    

    -----------------------------------------------------
    -- Stock QBCore fallback.
    -----------------------------------------------------

    local Player =
        QBCore.Functions.GetPlayer(
            source
        )


    if not Player
        or not Player.PlayerData then

        return nil
    end


    local metadata =
        Player.PlayerData.metadata
        or {}


    local bloodType =
        NormalizeBloodType(
            metadata.bloodtype
        )


    if not IsValidBloodType(
        bloodType
    ) then

        return nil
    end


    return bloodType
end


---------------------------------------------------------
-- RANDOM PREFERENCE
---------------------------------------------------------

local function GeneratePreference()
    local types =
        GetConfig().BloodTypes
        or {}


    local valid =
        {}


    for i = 1,
        #types do


        local normalized =
            NormalizeBloodType(
                types[i]
            )


        if IsValidBloodType(
            normalized
        ) then


            valid[
                #valid + 1
            ] =
                normalized
        end
    end


    if #valid <= 0 then
        return nil
    end


    return valid[
        math.random(
            1,
            #valid
        )
    ]
end


---------------------------------------------------------
-- GET / CREATE PREFERENCE
---------------------------------------------------------

function BloodAffinity.GetPreference(
    source
)
    source =
        tonumber(source)


    if not source then
        return nil,
            'invalid_source'
    end


    local citizenId =
        GetCitizenId(
            source
        )


    if not citizenId then
        return nil,
            'player_not_found'
    end


    -----------------------------------------------------
    -- DATABASE = AUTHORITATIVE VAMPIRE STATE
    --
    -- Runtime sadece cache'tir.
    -- Affinity kararında DB esas alınır.
    -----------------------------------------------------

    local row =
        MySQL.single.await(
            [[
                SELECT
                    is_vampire,
                    preferred_blood_type

                FROM vampire_characters

                WHERE citizenid = ?

                LIMIT 1
            ]],
            {
                citizenId
            }
        )


    -----------------------------------------------------
    -- NO CHARACTER ROW
    -----------------------------------------------------

    if not row then

        Runtime[
            citizenId
        ] =
            nil


        if Config.Debug then

            print(
                (
                    '^3[LB-VAMPIRE]^7 Blood Affinity | No vampire row | Citizen: %s'
                ):format(
                    tostring(citizenId)
                )
            )
        end


        return nil,
            'not_vampire'
    end


    -----------------------------------------------------
    -- NOT VAMPIRE
    -----------------------------------------------------

    local rawIsVampire =
        row.is_vampire


    local isVampire =
        rawIsVampire == true
        or rawIsVampire == 1
        or rawIsVampire == '1'

    if not isVampire then

        Runtime[
            citizenId
        ] =
            nil


        if Config.Debug then

            print(
                (
                    '^3[LB-VAMPIRE]^7 Blood Affinity | is_vampire != 1 | Citizen: %s | Value: %s'
                ):format(

                    tostring(
                        citizenId
                    ),

                    tostring(
                        row.is_vampire
                    )
                )
            )
        end


        return nil,
            'not_vampire'
    end


    -----------------------------------------------------
    -- DATABASE PREFERENCE
    -----------------------------------------------------

    local databasePreference =
        NormalizeBloodType(
            row.preferred_blood_type
        )


    -----------------------------------------------------
    -- VALID DB VALUE
    -----------------------------------------------------

    if IsValidBloodType(
        databasePreference
    ) then


        Runtime[
            citizenId
        ] =
            databasePreference


        return databasePreference
    end


    -----------------------------------------------------
    -- CACHE
    --
    -- DB boşsa ama bu resource lifecycle içinde
    -- geçerli cache varsa kullanabiliriz.
    -----------------------------------------------------

    local cached =
        Runtime[
            citizenId
        ]


    if cached
        and IsValidBloodType(
            cached
        ) then


        -------------------------------------------------
        -- DB'ye de geri yaz.
        -------------------------------------------------

        MySQL.update.await(
            [[
                UPDATE vampire_characters

                SET preferred_blood_type = ?

                WHERE citizenid = ?
                  AND is_vampire = 1
            ]],
            {
                cached,
                citizenId
            }
        )


        return cached
    end


    -----------------------------------------------------
    -- FIRST ASSIGNMENT
    -----------------------------------------------------

    local preference =
        GeneratePreference()


    if not preference then

        return nil,
            'no_blood_types_configured'
    end


    local affectedRows =
        MySQL.update.await(
            [[
                UPDATE vampire_characters

                SET preferred_blood_type = ?

                WHERE citizenid = ?
                  AND is_vampire = 1
            ]],
            {
                preference,
                citizenId
            }
        )


    -----------------------------------------------------
    -- UPDATE FAILED
    -----------------------------------------------------

    if not affectedRows
        or affectedRows <= 0 then


        return nil,
            'preference_save_failed'
    end


    Runtime[
        citizenId
    ] =
        preference


    if Config.Debug then

        print(
            (
                '^2[LB-VAMPIRE]^7 Blood affinity assigned | Citizen: %s | Preferred: %s'
            ):format(

                tostring(
                    citizenId
                ),

                tostring(
                    preference
                )
            )
        )
    end


    return preference
end



---------------------------------------------------------
-- ENSURE PREFERENCE
--
-- Vampire creation / Embrace gibi sistemler tarafından
-- çağrılabilir.
---------------------------------------------------------

function BloodAffinity.EnsurePreference(
    source
)
    source =
        tonumber(source)


    if not source then

        return false,
            'invalid_source'
    end


    local preference,
        reason =
        BloodAffinity.GetPreference(
            source
        )


    if not preference then

        return false,
            reason
    end


    return true,
        preference
end


exports(
    'EnsureBloodAffinity',
    function(
        source
    )

        return BloodAffinity.EnsurePreference(
            source
        )
    end
)



---------------------------------------------------------
-- MULTIPLIER
---------------------------------------------------------

---------------------------------------------------------
-- MULTIPLIER FROM BLOOD TYPE
---------------------------------------------------------

function BloodAffinity.GetMultiplierForBloodType(
    vampireSource,
    humanBloodType
)
    local config =
        GetConfig()


    if config.Enabled ~= true then

        return 1.0,
            {
                tier =
                    'DISABLED'
            }
    end


    -----------------------------------------------------
    -- VAMPIRE PREFERENCE
    -----------------------------------------------------

    local preference,
        preferenceReason =
        BloodAffinity.GetPreference(
            vampireSource
        )


    if not preference then

        return 1.0,
            {
                tier =
                    'NO_PREFERENCE',

                reason =
                    preferenceReason
            }
    end


    -----------------------------------------------------
    -- TARGET BLOOD TYPE
    -----------------------------------------------------

    humanBloodType =
        NormalizeBloodType(
            humanBloodType
        )


    if not IsValidBloodType(
        humanBloodType
    ) then

        return 1.0,
            {
                tier =
                    'UNKNOWN',

                preference =
                    preference
            }
    end


    local multipliers =
        config.Multipliers
        or {}


    -----------------------------------------------------
    -- EXACT
    -----------------------------------------------------

    if preference ==
        humanBloodType then


        return tonumber(
            multipliers.Exact
        )
        or 1.20,
            {
                tier =
                    'EXACT',

                preference =
                    preference,

                humanBloodType =
                    humanBloodType
            }
    end


    -----------------------------------------------------
    -- SAME ABO
    -----------------------------------------------------

    if GetABOGroup(
        preference
    ) == GetABOGroup(
        humanBloodType
    ) then


        return tonumber(
            multipliers.SameABO
        )
        or 1.08,
            {
                tier =
                    'SAME_ABO',

                preference =
                    preference,

                humanBloodType =
                    humanBloodType
            }
    end


    -----------------------------------------------------
    -- OTHER
    -----------------------------------------------------

    return tonumber(
        multipliers.Other
    )
    or 1.00,
        {
            tier =
                'OTHER',

            preference =
                preference,

            humanBloodType =
                humanBloodType
        }
end


---------------------------------------------------------
-- PLAYER -> PLAYER MULTIPLIER
---------------------------------------------------------

function BloodAffinity.GetMultiplier(
    vampireSource,
    humanSource
)
    local humanBloodType =
        BloodAffinity.GetHumanBloodType(
            humanSource
        )


    return BloodAffinity.GetMultiplierForBloodType(
        vampireSource,
        humanBloodType
    )
end


---------------------------------------------------------
-- EXPORT
---------------------------------------------------------

exports(
    'GetBloodAffinityMultiplier',
    function(
        vampireSource,
        humanSource
    )

        return BloodAffinity.GetMultiplier(
            vampireSource,
            humanSource
        )
    end
)

exports(
    'GetBloodAffinityMultiplierForType',
    function(
        vampireSource,
        bloodType
    )

        return BloodAffinity.GetMultiplierForBloodType(
            vampireSource,
            bloodType
        )
    end
)

---------------------------------------------------------
-- DEBUG
---------------------------------------------------------

if Config.Debug then

    RegisterCommand(
        'vamaffinity',
        function(
            source,
            args
        )

            source =
                tonumber(source)


            if not source
                or source <= 0 then

                return
            end


            local preference,
                reason =
                BloodAffinity.GetPreference(
                    source
                )


            if not preference then

                TriggerClientEvent(
                    'QBCore:Notify',
                    source,
                    (
                        'Blood Affinity: %s'
                    ):format(
                        tostring(reason)
                    ),
                    'error'
                )


                return
            end


            -------------------------------------------------
            -- /vamaffinity
            -------------------------------------------------

            if not args[1] then

                TriggerClientEvent(
                    'QBCore:Notify',
                    source,
                    (
                        'Preferred Blood Type: %s'
                    ):format(
                        preference
                    ),
                    'primary',
                    6000
                )


                print(
                    (
                        '^5[LB-VAMPIRE]^7 Affinity | Source: %s | Preferred: %s'
                    ):format(
                        tostring(source),
                        tostring(preference)
                    )
                )


                return
            end


            -------------------------------------------------
            -- /vamaffinity [target id]
            -------------------------------------------------

            local targetSource =
                tonumber(
                    args[1]
                )


            if not targetSource then
                return
            end


            local multiplier,
                details =
                BloodAffinity.GetMultiplier(
                    source,
                    targetSource
                )


            TriggerClientEvent(
                'QBCore:Notify',
                source,
                (
                    'Target: %s | %s | x%.2f'
                ):format(
                    tostring(
                        details.humanBloodType
                        or 'UNKNOWN'
                    ),
                    tostring(
                        details.tier
                    ),
                    multiplier
                ),
                'primary',
                7000
            )
        end,
        false
    )
end