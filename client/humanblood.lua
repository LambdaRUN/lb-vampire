LBVampire = LBVampire or {}

LBVampire.ClientState =
    LBVampire.ClientState or {}


local ClientState =
    LBVampire.ClientState


---------------------------------------------------------
-- STATE
---------------------------------------------------------

ClientState.humanBloodReceived =
    false

ClientState.humanBlood =
    ClientState.humanBlood
    or 100

ClientState.maxHumanBlood =
    ClientState.maxHumanBlood
    or 100

ClientState.humanBloodState =
    nil


---------------------------------------------------------
-- SYNC GENERATION
---------------------------------------------------------

local syncGeneration =
    0


---------------------------------------------------------
-- QBCORE
---------------------------------------------------------

local function GetQBCore()
    if GetResourceState(
        'qb-core'
    ) ~= 'started' then

        return nil
    end


    return exports[
        'qb-core'
    ]:GetCoreObject()
end


---------------------------------------------------------
-- CHARACTER CHECK
---------------------------------------------------------

local function HasCharacter()
    local QBCore =
        GetQBCore()


    if not QBCore
        or not QBCore.Functions then

        return false
    end


    local PlayerData =
        QBCore.Functions
            .GetPlayerData()


    if not PlayerData
        or not PlayerData.citizenid
        or PlayerData.citizenid == '' then

        return false
    end


    return true
end


---------------------------------------------------------
-- RESET
---------------------------------------------------------

local function ResetHumanBloodState()
    ClientState.humanBloodReceived =
        false


    ClientState.humanBlood =
        100


    ClientState.maxHumanBlood =
        100


    ClientState.humanBloodState =
        nil


    TriggerEvent(
        'lb-vampire:client:humanBloodStateUpdated',
        nil
    )
end


---------------------------------------------------------
-- REQUEST
---------------------------------------------------------

local function RequestHumanBloodSync()
    if not HasCharacter() then
        return false
    end


    TriggerServerEvent(
        'lb-vampire:server:requestHumanBloodSync'
    )


    return true
end


LBVampire.RequestHumanBloodSync =
    RequestHumanBloodSync


---------------------------------------------------------
-- EXTERNAL LOCAL REFRESH
---------------------------------------------------------

AddEventHandler(
    'lb-vampire:client:requestHumanBloodRefresh',
    function()

        RequestHumanBloodSync()
    end
)


---------------------------------------------------------
-- SERVER SYNC
---------------------------------------------------------

RegisterNetEvent(
    'lb-vampire:client:humanBloodSync',
    function(data)

        data =
            data or {}


        local maxBlood =
            tonumber(
                data.maxBlood
            )
            or 100


        if maxBlood <= 0 then
            maxBlood =
                100
        end


        local blood =
            tonumber(
                data.blood
            )


        if blood == nil then
            blood =
                maxBlood
        end


        blood =
            math.max(
                0,
                math.min(
                    blood,
                    maxBlood
                )
            )


        ClientState.humanBloodReceived =
            true


        ClientState.humanBlood =
            blood


        ClientState.maxHumanBlood =
            maxBlood


        local state = {
            blood =
                blood,

            maxBlood =
                maxBlood,

            lowThreshold =
                tonumber(
                    data.lowThreshold
                )
                or 70,

            criticalThreshold =
                tonumber(
                    data.criticalThreshold
                )
                or 40,

            severeThreshold =
                tonumber(
                    data.severeThreshold
                )
                or 20
        }


        ClientState.humanBloodState =
            state


        TriggerEvent(
            'lb-vampire:client:humanBloodStateUpdated',
            state
        )


        if Config.Debug then

            print(
                (
                    '^5[LB-VAMPIRE]^7 HumanBlood sync: %.2f / %.2f'
                ):format(
                    blood,
                    maxBlood
                )
            )
        end
    end
)


---------------------------------------------------------
-- POST SPAWN SYNC
---------------------------------------------------------

local function BeginPostSpawnSync()
    syncGeneration =
        syncGeneration + 1


    local generation =
        syncGeneration


    ClientState.humanBloodReceived =
        false


    CreateThread(function()

        -------------------------------------------------
        -- Spawn bridge zaten gerçek spawn'ı bekledi.
        -- Burada çok küçük settle süresi yeterli.
        -------------------------------------------------

        Wait(
            150
        )


        if generation ~=
            syncGeneration then

            return
        end


        RequestHumanBloodSync()


        -------------------------------------------------
        -- Retry
        -------------------------------------------------

        Wait(
            750
        )


        if generation ~=
            syncGeneration then

            return
        end


        if ClientState.humanBloodReceived
            ~= true then

            RequestHumanBloodSync()
        end


        -------------------------------------------------
        -- Final retry
        -------------------------------------------------

        Wait(
            1250
        )


        if generation ~=
            syncGeneration then

            return
        end


        if ClientState.humanBloodReceived
            ~= true then

            RequestHumanBloodSync()
        end
    end)
end


---------------------------------------------------------
-- SPAWN SELECTION START
---------------------------------------------------------

AddEventHandler(
    'lb-vampire:client:spawnSelectionStarted',
    function()

        syncGeneration =
            syncGeneration + 1


        ResetHumanBloodState()
    end
)


---------------------------------------------------------
-- SPAWN READY
---------------------------------------------------------

AddEventHandler(
    'lb-vampire:client:spawnReady',
    function()

        BeginPostSpawnSync()
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


        syncGeneration =
            syncGeneration + 1
    end
)