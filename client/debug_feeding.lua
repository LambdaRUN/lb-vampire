LBVampire = LBVampire or {}

LBVampire.DebugFeeding =
    LBVampire.DebugFeeding or {}


local Test =
    LBVampire.DebugFeeding


---------------------------------------------------------
-- STATE
---------------------------------------------------------

Test.active =
    false

Test.role =
    nil

Test.npc =
    nil

Test.vehicle =
    nil


---------------------------------------------------------
-- DEBUG ONLY
---------------------------------------------------------

if Config.Debug ~= true then
    return
end


---------------------------------------------------------
-- NOTIFY
---------------------------------------------------------

local function Notify(
    message,
    notifyType
)
    TriggerEvent(
        'QBCore:Notify',

        message,

        notifyType
            or 'primary',

        5000
    )
end


---------------------------------------------------------
-- MODEL LOADER
---------------------------------------------------------

local function LoadModel(
    model
)
    local hash =
        type(model) ==
            'number'
        and model
        or joaat(
            model
        )


    if not IsModelInCdimage(
        hash
    )
        or not IsModelValid(
            hash
        ) then

        return nil
    end


    RequestModel(
        hash
    )


    local timeout =
        GetGameTimer()
        + 5000


    while not HasModelLoaded(
        hash
    ) do


        Wait(
            10
        )


        if GetGameTimer()
            >= timeout then

            return nil
        end
    end


    return hash
end


---------------------------------------------------------
-- ANIM DICT
---------------------------------------------------------

local function LoadAnimDict(
    dictionary
)
    if HasAnimDictLoaded(
        dictionary
    ) then

        return true
    end


    RequestAnimDict(
        dictionary
    )


    local timeout =
        GetGameTimer()
        + 5000


    while not HasAnimDictLoaded(
        dictionary
    ) do


        Wait(
            10
        )


        if GetGameTimer()
            >= timeout then

            return false
        end
    end


    return true
end


---------------------------------------------------------
-- ENTITY DELETE
---------------------------------------------------------

local function DeleteEntitySafe(
    entity
)
    if not entity
        or entity == 0
        or not DoesEntityExist(
            entity
        ) then

        return
    end


    SetEntityAsMissionEntity(
        entity,
        true,
        true
    )


    DeleteEntity(
        entity
    )
end


---------------------------------------------------------
-- CLEANUP ENTITIES
---------------------------------------------------------

local function CleanupEntities()

    -----------------------------------------------------
    -- NPC
    -----------------------------------------------------

    if Test.npc
        and DoesEntityExist(
            Test.npc
        ) then


        ClearPedTasksImmediately(
            Test.npc
        )


        DeleteEntitySafe(
            Test.npc
        )
    end


    Test.npc =
        nil


    -----------------------------------------------------
    -- TEST VEHICLE
    -----------------------------------------------------

    if Test.vehicle
        and DoesEntityExist(
            Test.vehicle
        ) then


        DeleteEntitySafe(
            Test.vehicle
        )
    end


    Test.vehicle =
        nil
end


---------------------------------------------------------
-- STOP
---------------------------------------------------------

local function StopTest(
    reason,
    skipRuntimeStop,
    showNotification
)
    reason =
        tostring(
            reason
            or 'manual'
        )


    if skipRuntimeStop ~= true then


        TriggerEvent(
            'lb-vampire:client:debugFeedingRuntimeStop'
        )
    end


    Test.active =
        false


    Test.role =
        nil


    CleanupEntities()


    if showNotification ~= false then


        Notify(
            (
                'Debug feeding durdu: %s'
            ):format(
                reason
            ),
            'primary'
        )
    end


    if Config.Debug then

        print(
            (
                '^5[LB-VAMPIRE]^7 Debug feeding stopped | Reason: %s'
            ):format(
                reason
            )
        )
    end
end


---------------------------------------------------------
-- NPC ANIMATION
---------------------------------------------------------

local function StartNpcAnimation(
    npc,
    role
)
    local config =
        Config.Feeding
        and Config.Feeding.Animation
        or {}


    if config.Enabled ~= true then
        return
    end


    local dictionary =
        tostring(
            config.Dictionary
            or 'mp_ped_interaction'
        )


    if not LoadAnimDict(
        dictionary
    ) then


        Notify(
            'NPC animasyon dictionary yüklenemedi.',
            'error'
        )


        return
    end


    -----------------------------------------------------
    -- NPC opposite role.
    -----------------------------------------------------

    local animation


    if role ==
        'VAMPIRE' then


        animation =
            tostring(
                config.Human
                or 'hugs_guy_b'
            )


    else


        animation =
            tostring(
                config.Vampire
                or 'hugs_guy_a'
            )
    end


    TaskPlayAnim(
        npc,

        dictionary,

        animation,

        8.0,
        -8.0,

        -1,

        tonumber(
            config.Flag
        )
        or 1,

        0.0,

        false,
        false,
        false
    )
end


---------------------------------------------------------
-- START
---------------------------------------------------------

local function StartTest(
    requestedRole
)
    -----------------------------------------------------
    -- PREVIOUS TEST
    -----------------------------------------------------

    if Test.active == true then


        StopTest(
            'restart',
            false,
            false
        )


        Wait(
            250
        )
    end


    local ped =
        PlayerPedId()


    if not ped
        or ped == 0
        or not DoesEntityExist(
            ped
        ) then


        Notify(
            'Player ped bulunamadı.',
            'error'
        )


        return
    end


    if IsEntityDead(
        ped
    ) then


        Notify(
            'Ölü durumdayken debug feeding başlatılamaz.',
            'error'
        )


        return
    end


    if IsPedInAnyVehicle(
        ped,
        false
    ) then


        Notify(
            'Önce araçtan çık.',
            'error'
        )


        return
    end


    -----------------------------------------------------
    -- ROLE
    -----------------------------------------------------

    local role =
        string.upper(
            tostring(
                requestedRole
                or 'VAMPIRE'
            )
        )


    if role ~= 'VAMPIRE'
        and role ~= 'HUMAN' then


        Notify(
            'Rol vampire veya human olmalı.',
            'error'
        )


        return
    end


    -----------------------------------------------------
    -- NPC MODEL
    -----------------------------------------------------

    local model =
        LoadModel(
            'a_m_m_business_01'
        )


    if not model then


        Notify(
            'Debug NPC modeli yüklenemedi.',
            'error'
        )


        return
    end


    -----------------------------------------------------
    -- POSITION
    -----------------------------------------------------

    local playerCoords =
        GetEntityCoords(
            ped
        )


    local spawnCoords =
        GetOffsetFromEntityInWorldCoords(
            ped,
            0.0,
            0.85,
            0.0
        )


    local playerHeading =
        GetEntityHeading(
            ped
        )


    local npcHeading =
        playerHeading
        + 180.0


    if npcHeading >= 360.0 then
        npcHeading =
            npcHeading
            - 360.0
    end


    -----------------------------------------------------
    -- CREATE NPC
    -----------------------------------------------------

    local npc =
        CreatePed(

            4,

            model,

            spawnCoords.x,
            spawnCoords.y,
            playerCoords.z,

            npcHeading,

            false,
            false
        )


    SetModelAsNoLongerNeeded(
        model
    )


    if not npc
        or npc == 0 then


        Notify(
            'Debug NPC oluşturulamadı.',
            'error'
        )


        return
    end


    Test.npc =
        npc


    Test.active =
        true


    Test.role =
        role


    -----------------------------------------------------
    -- NPC SETTINGS
    -----------------------------------------------------

    SetEntityAsMissionEntity(
        npc,
        true,
        true
    )


    SetEntityInvincible(
        npc,
        true
    )


    SetBlockingOfNonTemporaryEvents(
        npc,
        true
    )


    SetPedCanRagdoll(
        npc,
        false
    )


    SetPedFleeAttributes(
        npc,
        0,
        false
    )


    SetPedCombatAttributes(
        npc,
        46,
        true
    )


    -----------------------------------------------------
    -- FACE PLAYER
    -----------------------------------------------------

    local animationConfig =
        Config.Feeding
        and Config.Feeding.Animation
        or {}


    local faceDuration =
        tonumber(
            animationConfig.FaceDuration
        )
        or 500


    TaskTurnPedToFaceEntity(
        npc,
        ped,
        faceDuration
    )


    -----------------------------------------------------
    -- PLAYER RUNTIME
    -----------------------------------------------------

    TriggerEvent(
        'lb-vampire:client:debugFeedingRuntimeStart',
        {
            role =
                role,

            partnerPed =
                npc
        }
    )


    -----------------------------------------------------
    -- NPC ANIMATION
    -----------------------------------------------------

    CreateThread(function()

        Wait(
            faceDuration
        )


        if Test.active ~= true
            or not Test.npc
            or not DoesEntityExist(
                Test.npc
            ) then

            return
        end


        StartNpcAnimation(
            Test.npc,
            role
        )
    end)


    Notify(
        (
            'Debug feeding başladı. Rol: %s'
        ):format(
            role
        ),
        'success'
    )


    print(
        (
            '^2[LB-VAMPIRE]^7 Debug feeding started | Role: %s | NPC: %s'
        ):format(
            role,
            tostring(
                npc
            )
        )
    )
end


---------------------------------------------------------
-- RUNTIME INTERRUPTED
---------------------------------------------------------

AddEventHandler(
    'lb-vampire:client:debugFeedingRuntimeInterrupted',
    function(reason)

        if Test.active ~= true then
            return
        end


        StopTest(
            reason,
            true,
            true
        )
    end
)


---------------------------------------------------------
-- /vamfeedtest
--
-- /vamfeedtest
-- /vamfeedtest vampire
-- /vamfeedtest human
---------------------------------------------------------

RegisterCommand(
    'vamfeedtest',
    function(
        _,
        args
    )

        StartTest(
            args[1]
        )
    end,
    false
)


---------------------------------------------------------
-- /vamfeedteststop
---------------------------------------------------------

RegisterCommand(
    'vamfeedteststop',
    function()

        if Test.active ~= true then


            Notify(
                'Aktif debug feeding yok.',
                'error'
            )


            return
        end


        StopTest(
            'manual',
            false,
            true
        )
    end,
    false
)


---------------------------------------------------------
-- /vamfeedtestdamage
---------------------------------------------------------

RegisterCommand(
    'vamfeedtestdamage',
    function()

        if Test.active ~= true then


            Notify(
                'Önce /vamfeedtest kullan.',
                'error'
            )


            return
        end


        local ped =
            PlayerPedId()


        local health =
            GetEntityHealth(
                ped
            )


        -------------------------------------------------
        -- Ölmeden health düşür.
        -------------------------------------------------

        local newHealth =
            math.max(
                health - 10,
                110
            )


        if newHealth >= health then


            Notify(
                'Health damage testi için çok düşük.',
                'error'
            )


            return
        end


        SetEntityHealth(
            ped,
            newHealth
        )
    end,
    false
)


---------------------------------------------------------
-- /vamfeedtestragdoll
---------------------------------------------------------

RegisterCommand(
    'vamfeedtestragdoll',
    function()

        if Test.active ~= true then


            Notify(
                'Önce /vamfeedtest kullan.',
                'error'
            )


            return
        end


        local ped =
            PlayerPedId()


        SetPedToRagdoll(
            ped,
            1500,
            1500,
            0,
            true,
            true,
            false
        )
    end,
    false
)


---------------------------------------------------------
-- /vamfeedtestteleport
---------------------------------------------------------

RegisterCommand(
    'vamfeedtestteleport',
    function()

        if Test.active ~= true then


            Notify(
                'Önce /vamfeedtest kullan.',
                'error'
            )


            return
        end


        local ped =
            PlayerPedId()


        local coords =
            GetOffsetFromEntityInWorldCoords(
                ped,
                0.0,
                7.0,
                0.0
            )


        SetEntityCoordsNoOffset(
            ped,

            coords.x,
            coords.y,
            coords.z,

            false,
            false,
            false
        )
    end,
    false
)


---------------------------------------------------------
-- /vamfeedtestvehicle
---------------------------------------------------------

RegisterCommand(
    'vamfeedtestvehicle',
    function()

        if Test.active ~= true then


            Notify(
                'Önce /vamfeedtest kullan.',
                'error'
            )


            return
        end


        local ped =
            PlayerPedId()


        local model =
            LoadModel(
                'blista'
            )


        if not model then


            Notify(
                'Debug vehicle yüklenemedi.',
                'error'
            )


            return
        end


        local coords =
            GetOffsetFromEntityInWorldCoords(
                ped,
                0.0,
                2.5,
                0.0
            )


        local vehicle =
            CreateVehicle(

                model,

                coords.x,
                coords.y,
                coords.z,

                GetEntityHeading(
                    ped
                ),

                false,
                false
            )


        SetModelAsNoLongerNeeded(
            model
        )


        if not vehicle
            or vehicle == 0 then


            Notify(
                'Debug vehicle oluşturulamadı.',
                'error'
            )


            return
        end


        Test.vehicle =
            vehicle


        SetEntityAsMissionEntity(
            vehicle,
            true,
            true
        )


        -------------------------------------------------
        -- Doğrudan araca koy.
        --
        -- Feeding runtime bir sonraki check'te
        -- vehicle interrupt vermeli.
        -------------------------------------------------

        SetPedIntoVehicle(
            ped,
            vehicle,
            -1
        )
    end,
    false
)


---------------------------------------------------------
-- /vamfeedteststate
---------------------------------------------------------

RegisterCommand(
    'vamfeedteststate',
    function()

        local runtime =
            LBVampire.FeedingRuntime
            or {}


        print(
            (
                '^5[LB-VAMPIRE]^7 Debug Feeding State | TestActive: %s | RuntimeActive: %s | DebugMode: %s | Role: %s | NPC: %s'
            ):format(

                tostring(
                    Test.active
                ),

                tostring(
                    runtime.active
                ),

                tostring(
                    runtime.debugMode
                ),

                tostring(
                    runtime.role
                ),

                tostring(
                    Test.npc
                )
            )
        )
    end,
    false
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


        if Test.active == true then


            TriggerEvent(
                'lb-vampire:client:debugFeedingRuntimeStop'
            )
        end


        CleanupEntities()
    end
)