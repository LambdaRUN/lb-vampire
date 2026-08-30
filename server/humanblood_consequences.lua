LBVampire = LBVampire or {}

LBVampire.HumanBloodConsequences =
    LBVampire.HumanBloodConsequences or {}


local Consequences =
    LBVampire.HumanBloodConsequences


---------------------------------------------------------
-- RUNTIME
---------------------------------------------------------

local ZeroLatch =
    {}


local SourceCitizen =
    {}


---------------------------------------------------------
-- CONFIG
---------------------------------------------------------

local function GetConfig()
    return Config.HumanBlood
        and Config.HumanBlood.Consequences
        or {}
end


local function GetZeroConfig()
    local config =
        GetConfig()


    return config.ZeroBlood
        or {}
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


    if not LBVampire.Runtime
        or not LBVampire.Runtime.Vampires then

        return false
    end


    return LBVampire.Runtime
        .Vampires[citizenId]
        ~= nil
end


---------------------------------------------------------
-- APPLY ZERO CONSEQUENCE
---------------------------------------------------------

local function ApplyZero(
    source,
    citizenId
)
    source =
        tonumber(source)


    if not source
        or not citizenId then

        return false
    end


    -----------------------------------------------------
    -- HumanBlood consequence insan içindir.
    -----------------------------------------------------

    if IsVampire(
        citizenId
    ) then

        return false
    end


    local config =
        GetConfig()


    local zeroConfig =
        GetZeroConfig()


    if config.Enabled ~= true
        or zeroConfig.Enabled ~= true then

        return false
    end


    -----------------------------------------------------
    -- Aynı zero state boyunca yalnızca bir kez.
    -----------------------------------------------------

    if ZeroLatch[
        citizenId
    ] == true then

        return false
    end


    ZeroLatch[
        citizenId
    ] =
        true


    SourceCitizen[
        source
    ] =
        citizenId


    TriggerClientEvent(
        'lb-vampire:client:humanBloodZero',

        source,

        {
            citizenId =
                citizenId,

            setHealthToZero =
                zeroConfig.SetHealthToZero
                == true,

            notification =
                tostring(
                    zeroConfig.Notification
                    or
                    'Aşırı kan kaybı nedeniyle bilincini kaybettin.'
                )
        }
    )


    if Config.Debug then

        print(
            (
                '^1[LB-VAMPIRE]^7 HumanBlood ZERO | Source: %s | Citizen: %s'
            ):format(
                tostring(source),
                tostring(citizenId)
            )
        )
    end


    return true
end


---------------------------------------------------------
-- EVALUATE
---------------------------------------------------------

local function Evaluate(
    source,
    citizenId,
    blood
)
    source =
        tonumber(source)


    blood =
        tonumber(blood)


    if not source
        or not citizenId
        or blood == nil then

        return
    end


    SourceCitizen[
        source
    ] =
        citizenId


    -----------------------------------------------------
    -- HumanBlood tekrar 0'ın üzerine çıktı.
    --
    -- Treatment gerçekleşmiş sayılır ve gelecekte yeni
    -- bir zero event tetiklenebilir.
    -----------------------------------------------------

    if blood > 0 then

        ZeroLatch[
            citizenId
        ] =
            nil


        return
    end


    ApplyZero(
        source,
        citizenId
    )
end


---------------------------------------------------------
-- INITIAL LOAD
---------------------------------------------------------

AddEventHandler(
    'lb-vampire:server:humanBloodLoaded',
    function(
        source,
        citizenId,
        blood
    )

        Evaluate(
            source,
            citizenId,
            blood
        )
    end
)


---------------------------------------------------------
-- BLOOD CHANGE
---------------------------------------------------------

AddEventHandler(
    'lb-vampire:server:humanBloodChanged',
    function(
        source,
        citizenId,
        previousBlood,
        currentBlood
    )

        Evaluate(
            source,
            citizenId,
            currentBlood
        )
    end
)


---------------------------------------------------------
-- DISCONNECT
---------------------------------------------------------

AddEventHandler(
    'playerDropped',
    function()

        local playerSource =
            tonumber(source)


        if not playerSource then
            return
        end


        local citizenId =
            SourceCitizen[
                playerSource
            ]


        if citizenId then

            ZeroLatch[
                citizenId
            ] =
                nil
        end


        SourceCitizen[
            playerSource
        ] =
            nil
    end
)