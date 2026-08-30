LBVampire = LBVampire or {}

LBVampire.ClientState =
    LBVampire.ClientState or {}

LBVampire.FeedingRuntime =
    LBVampire.FeedingRuntime or {}


local Runtime =
    LBVampire.FeedingRuntime

    
---------------------------------------------------------
-- STATE
---------------------------------------------------------

Runtime.active =
    false

Runtime.role =
    nil

Runtime.partnerSource =
    nil

Runtime.debugPartnerPed =
    nil

Runtime.debugMode =
    false

Runtime.interruptSent =
    false

Runtime.startHealth =
    nil

Runtime.startArmor =
    nil

Runtime.lastCoords =
    nil

Runtime.generation =
    0

Runtime.attachedToPartner =
    false


---------------------------------------------------------
-- CONFIG
---------------------------------------------------------

local function GetAnimationConfig()
    return Config.Feeding
        and Config.Feeding.Animation
        or {}
end


local function GetInterruptConfig()
    return Config.Feeding
        and Config.Feeding.Interrupts
        or {}
end


---------------------------------------------------------
-- DISTANCE
---------------------------------------------------------

local function DistanceBetweenCoords(
    first,
    second
)
    if not first
        or not second then

        return 0.0
    end


    local x =
        first.x -
        second.x

    local y =
        first.y -
        second.y

    local z =
        first.z -
        second.z


    return math.sqrt(
        (x * x)
        +
        (y * y)
        +
        (z * z)
    )
end


---------------------------------------------------------
-- PARTNER PED
---------------------------------------------------------

local function GetPartnerPed()

    -----------------------------------------------------
    -- DEBUG NPC
    -----------------------------------------------------

    if Runtime.debugMode == true
        and Runtime.debugPartnerPed
        and DoesEntityExist(
            Runtime.debugPartnerPed
        ) then

        return Runtime.debugPartnerPed
    end


    -----------------------------------------------------
    -- REAL PLAYER
    -----------------------------------------------------

    if not Runtime.partnerSource then
        return nil
    end


    local player =
        GetPlayerFromServerId(
            Runtime.partnerSource
        )


    if player == -1 then
        return nil
    end


    local ped =
        GetPlayerPed(
            player
        )


    if not ped
        or ped == 0
        or not DoesEntityExist(
            ped
        ) then

        return nil
    end


    return ped
end


---------------------------------------------------------
-- ANIMATION DICTIONARY
---------------------------------------------------------

local function LoadAnimationDictionary(
    dictionary
)
    if not dictionary
        or dictionary == '' then

        return false
    end


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
-- DETACH LOCAL PED
---------------------------------------------------------

local function DetachLocalPed()

    local ped =
        PlayerPedId()


    if not ped
        or ped == 0
        or not DoesEntityExist(
            ped
        ) then

        Runtime.attachedToPartner =
            false

        return
    end


    if IsEntityAttached(
        ped
    ) then


        DetachEntity(
            ped,
            true,
            true
        )
    end


    Runtime.attachedToPartner =
        false
end

---------------------------------------------------------
-- STOP LOCAL ANIMATION
---------------------------------------------------------

local function StopLocalAnimation()

    local ped =
        PlayerPedId()


    -----------------------------------------------------
    -- Önce paired attachment çözülür.
    -----------------------------------------------------

    DetachLocalPed()


    if ped
        and ped ~= 0 then


        ClearPedTasks(
            ped
        )


        ClearPedSecondaryTask(
            ped
        )
    end
end


---------------------------------------------------------
-- RESET RUNTIME
---------------------------------------------------------

local function ResetRuntime()
    Runtime.generation =
        Runtime.generation + 1


    Runtime.active =
        false


    Runtime.role =
        nil


    Runtime.partnerSource =
        nil


    Runtime.debugPartnerPed =
        nil


    Runtime.debugMode =
        false


    Runtime.interruptSent =
        false


    Runtime.startHealth =
        nil


    Runtime.startArmor =
        nil


    Runtime.lastCoords =
        nil
    
    Runtime.attachedToPartner =
    false
end


---------------------------------------------------------
-- INTERRUPT SERVER / DEBUG
---------------------------------------------------------

local function RequestInterrupt(
    reason
)
    if Runtime.active ~= true
        or Runtime.interruptSent == true then

        return
    end


    Runtime.interruptSent =
        true


    reason =
        tostring(
            reason
            or 'client_interrupt'
        )


    -----------------------------------------------------
    -- Görsel anında kesilir.
    -----------------------------------------------------

    StopLocalAnimation()


    -----------------------------------------------------
    -- DEBUG HARNESS
    --
    -- Burada server session olmadığı için server'a
    -- interrupt göndermiyoruz.
    -----------------------------------------------------

    if Runtime.debugMode == true then

        if Config.Debug then

            print(
                (
                    '^3[LB-VAMPIRE]^7 DEBUG feeding interrupt: %s'
                ):format(
                    reason
                )
            )
        end


        ResetRuntime()


        TriggerEvent(
            'lb-vampire:client:debugFeedingRuntimeInterrupted',
            reason
        )


        return
    end


    -----------------------------------------------------
    -- REAL FEEDING
    --
    -- Gerçek session'ı sadece server kapatabilir.
    -----------------------------------------------------

    TriggerServerEvent(
        'lb-vampire:server:interruptFeeding',
        reason
    )


    if Config.Debug then

        print(
            (
                '^3[LB-VAMPIRE]^7 Feeding interrupt requested: %s'
            ):format(
                reason
            )
        )
    end
end


---------------------------------------------------------
-- CONTROL LOCK
---------------------------------------------------------

local function DisableFeedingControls()

    -----------------------------------------------------
    -- MOVEMENT
    -----------------------------------------------------

    DisableControlAction(
        0,
        30,
        true
    )

    DisableControlAction(
        0,
        31,
        true
    )


    -----------------------------------------------------
    -- SPRINT / JUMP
    -----------------------------------------------------

    DisableControlAction(
        0,
        21,
        true
    )

    DisableControlAction(
        0,
        22,
        true
    )


    -----------------------------------------------------
    -- ATTACK / AIM
    -----------------------------------------------------

    DisableControlAction(
        0,
        24,
        true
    )

    DisableControlAction(
        0,
        25,
        true
    )


    -----------------------------------------------------
    -- WEAPON WHEEL
    -----------------------------------------------------

    DisableControlAction(
        0,
        37,
        true
    )


    -----------------------------------------------------
    -- COVER
    -----------------------------------------------------

    DisableControlAction(
        0,
        44,
        true
    )


    -----------------------------------------------------
    -- VEHICLE EXIT
    -----------------------------------------------------

    DisableControlAction(
        0,
        75,
        true
    )
end

---------------------------------------------------------
-- ANIMATION ATTACHMENT
---------------------------------------------------------

local function ApplyAnimationAttachment(
    ped,
    partnerPed,
    config
)
    local attach =
        config.Attach
        or {}


    -----------------------------------------------------
    -- Attachment kullanılmıyor.
    -----------------------------------------------------

    if attach.Enabled ~= true then
        return true
    end


    -----------------------------------------------------
    -- Sadece config'te belirtilen role uygulanır.
    -----------------------------------------------------

    local attachRole =
        string.upper(
            tostring(
                attach.Role
                or 'HUMAN'
            )
        )


    if Runtime.role ~=
        attachRole then

        return true
    end


    -----------------------------------------------------
    -- Partner gerekli.
    -----------------------------------------------------

    if not partnerPed
        or partnerPed == 0
        or not DoesEntityExist(
            partnerPed
        ) then


        if Config.Debug then

            print(
                '^1[LB-VAMPIRE]^7 Feeding attachment failed: partner ped missing.'
            )
        end


        return false
    end


    -----------------------------------------------------
    -- PED
    -----------------------------------------------------

    if not ped
        or ped == 0
        or not DoesEntityExist(
            ped
        ) then

        return false
    end


    -----------------------------------------------------
    -- Önce eski attachment varsa temizle.
    -----------------------------------------------------

    if IsEntityAttached(
        ped
    ) then


        DetachEntity(
            ped,
            true,
            true
        )
    end


    -----------------------------------------------------
    -- BONE
    -----------------------------------------------------

    local bone =
        tonumber(
            attach.Bone
        )
        or 0


    -----------------------------------------------------
    -- ATTACH
    --
    -- Human ped -> Vampire ped
    -----------------------------------------------------

    AttachEntityToEntity(

        ped,

        partnerPed,

        bone,

        tonumber(
            attach.X
        )
        or 0.0,

        tonumber(
            attach.Y
        )
        or 0.0,

        tonumber(
            attach.Z
        )
        or 0.0,

        tonumber(
            attach.RotX
        )
        or 0.0,

        tonumber(
            attach.RotY
        )
        or 0.0,

        tonumber(
            attach.RotZ
        )
        or 0.0,

        false,
        false,
        false,
        false,

        2,

        true
    )


    Runtime.attachedToPartner =
        true


    if Config.Debug then

        print(
            (
                '^2[LB-VAMPIRE]^7 Feeding attachment applied | Role: %s | Offset: %.3f %.3f %.3f'
            ):format(

                tostring(
                    Runtime.role
                ),

                tonumber(
                    attach.X
                )
                or 0.0,

                tonumber(
                    attach.Y
                )
                or 0.0,

                tonumber(
                    attach.Z
                )
                or 0.0
            )
        )
    end


    return true
end


---------------------------------------------------------
-- PLAY FEEDING ANIMATION
---------------------------------------------------------

local function StartAnimation(
    generation
)
    local config =
        GetAnimationConfig()


    if config.Enabled ~= true then
        return
    end


    local ped =
        PlayerPedId()


    if not ped
        or ped == 0 then

        return
    end


    -----------------------------------------------------
    -- PARTNER STREAMING
    -----------------------------------------------------

    local partnerPed


    local timeout =
        GetGameTimer()
        + 2000


    while Runtime.active == true
        and generation ==
            Runtime.generation do


        partnerPed =
            GetPartnerPed()


        if partnerPed then
            break
        end


        if GetGameTimer()
            >= timeout then

            break
        end


        Wait(
            50
        )
    end


    if Runtime.active ~= true
        or generation ~=
            Runtime.generation then

        return
    end


    -----------------------------------------------------
    -- FACE PARTNER
    -----------------------------------------------------

    if config.FacePartner == true
        and partnerPed then


        local faceDuration =
            tonumber(
                config.FaceDuration
            )
            or 500


        TaskTurnPedToFaceEntity(
            ped,
            partnerPed,
            faceDuration
        )


        Wait(
            faceDuration
        )
    end


    if Runtime.active ~= true
        or generation ~=
            Runtime.generation then

        return
    end


    -----------------------------------------------------
    -- DICTIONARY
    -----------------------------------------------------

    local dictionary


if Runtime.role ==
    'VAMPIRE' then


    dictionary =
        tostring(
            config.VampireDictionary
            or config.Dictionary
            or 'mp_ped_interaction'
        )


elseif Runtime.role ==
    'HUMAN' then


    dictionary =
        tostring(
            config.HumanDictionary
            or config.Dictionary
            or 'mp_ped_interaction'
        )


else


    dictionary =
        tostring(
            config.Dictionary
            or 'mp_ped_interaction'
        )
end


    if not LoadAnimationDictionary(
        dictionary
    ) then


        if Config.Debug then

            print(
                (
                    '^1[LB-VAMPIRE]^7 Feeding animation dictionary failed: %s'
                ):format(
                    dictionary
                )
            )
        end


        return
    end


    -----------------------------------------------------
    -- ROLE ANIMATION
    -----------------------------------------------------

    local animation


    if Runtime.role ==
        'VAMPIRE' then


        animation =
            tostring(
                config.Vampire
                or 'hugs_guy_a'
            )


    elseif Runtime.role ==
        'HUMAN' then


        animation =
            tostring(
                config.Human
                or 'hugs_guy_b'
            )


    else


        if Config.Debug then

            print(
                (
                    '^1[LB-VAMPIRE]^7 Unknown feeding role: %s'
                ):format(
                    tostring(
                        Runtime.role
                    )
                )
            )
        end


        return
    end

-----------------------------------------------------
-- PAIRED ATTACHMENT
-----------------------------------------------------

local attachmentReady =
    ApplyAnimationAttachment(
        ped,
        partnerPed,
        config
    )


if attachmentReady ~= true then

    if Config.Debug then

        print(
            '^1[LB-VAMPIRE]^7 Feeding animation started without attachment because attachment setup failed.'
        )
    end
end    

    -----------------------------------------------------
    -- PLAY
    -----------------------------------------------------

    TaskPlayAnim(
        ped,

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


    if Config.Debug then

        print(
            (
                '^2[LB-VAMPIRE]^7 Feeding animation started | Role: %s | Debug: %s | Anim: %s'
            ):format(

                tostring(
                    Runtime.role
                ),

                tostring(
                    Runtime.debugMode
                ),

                animation
            )
        )
    end
end


---------------------------------------------------------
-- INTERRUPT MONITOR
---------------------------------------------------------

local function StartInterruptMonitor(
    generation
)
    local config =
        GetInterruptConfig()


    if config.Enabled ~= true then
        return
    end


    local ped =
        PlayerPedId()


    if not ped
        or ped == 0 then

        return
    end


    Runtime.startHealth =
        GetEntityHealth(
            ped
        )


    Runtime.startArmor =
        GetPedArmour(
            ped
        )


    Runtime.lastCoords =
        GetEntityCoords(
            ped
        )


    local interval =
        math.max(
            tonumber(
                config.ClientCheckInterval
            )
            or 100,

            50
        )


    while Runtime.active == true
        and generation ==
            Runtime.generation do


        Wait(
            interval
        )


        if Runtime.active ~= true
            or generation ~=
                Runtime.generation then

            break
        end


        ped =
            PlayerPedId()


        -------------------------------------------------
        -- PED MISSING
        -------------------------------------------------

        if not ped
            or ped == 0
            or not DoesEntityExist(
                ped
            ) then


            RequestInterrupt(
                'ped_missing'
            )


            break
        end


        -------------------------------------------------
        -- DEATH
        -------------------------------------------------

        if IsEntityDead(
            ped
        ) then


            RequestInterrupt(
                'death'
            )


            break
        end


        -------------------------------------------------
        -- VEHICLE
        -------------------------------------------------

        if config.CancelInVehicle == true
            and IsPedInAnyVehicle(
                ped,
                false
            ) then


            RequestInterrupt(
                'vehicle'
            )


            break
        end


        -------------------------------------------------
        -- RAGDOLL / FALL
        -------------------------------------------------

        if config.CancelOnRagdoll == true
            and (
                IsPedRagdoll(
                    ped
                )
                or IsPedFalling(
                    ped
                )
            ) then


            RequestInterrupt(
                'ragdoll'
            )


            break
        end


        -------------------------------------------------
        -- DAMAGE
        -------------------------------------------------

        if config.CancelOnDamage == true then


            local health =
                GetEntityHealth(
                    ped
                )


            local armor =
                GetPedArmour(
                    ped
                )


            if health <
                (
                    Runtime.startHealth
                    or health
                )
                or armor <
                (
                    Runtime.startArmor
                    or armor
                ) then


                RequestInterrupt(
                    'damage'
                )


                break
            end


            Runtime.startHealth =
                health


            Runtime.startArmor =
                armor
        end


        -------------------------------------------------
        -- TELEPORT
        -------------------------------------------------

        local currentCoords =
            GetEntityCoords(
                ped
            )


        local teleportDistance =
            tonumber(
                config.TeleportDistance
            )
            or 5.0


        if Runtime.lastCoords then


            local moved =
                DistanceBetweenCoords(
                    currentCoords,
                    Runtime.lastCoords
                )


            if moved >
                teleportDistance then


                RequestInterrupt(
                    'teleport'
                )


                break
            end
        end


        Runtime.lastCoords =
            currentCoords
    end
end


---------------------------------------------------------
-- BEGIN RUNTIME
---------------------------------------------------------

local function BeginRuntime(
    role,
    partnerSource,
    debugPartnerPed,
    debugMode
)
    -----------------------------------------------------
    -- Önce eski runtime temizlenir.
    -----------------------------------------------------

    StopLocalAnimation()


    Runtime.generation =
        Runtime.generation + 1


    local generation =
        Runtime.generation


    Runtime.active =
        true


    Runtime.interruptSent =
        false


    Runtime.role =
        string.upper(
            tostring(
                role
                or 'UNKNOWN'
            )
        )


    Runtime.partnerSource =
        tonumber(
            partnerSource
        )


    Runtime.debugPartnerPed =
        debugPartnerPed


    Runtime.debugMode =
        debugMode == true


    Runtime.startHealth =
        nil


    Runtime.startArmor =
        nil


    Runtime.lastCoords =
        nil


    -----------------------------------------------------
    -- ANIMATION
    -----------------------------------------------------

    CreateThread(function()

        StartAnimation(
            generation
        )
    end)


    -----------------------------------------------------
    -- INTERRUPTS
    -----------------------------------------------------

    CreateThread(function()

        StartInterruptMonitor(
            generation
        )
    end)
end


---------------------------------------------------------
-- CONTROL THREAD
---------------------------------------------------------

CreateThread(function()

    while true do


        if Runtime.active == true
            and GetAnimationConfig()
                .DisableControls == true then


            DisableFeedingControls()


            Wait(
                0
            )


        else


            Wait(
                250
            )
        end
    end
end)


---------------------------------------------------------
-- REAL FEEDING ACCEPTED
---------------------------------------------------------

RegisterNetEvent(
    'lb-vampire:client:feedingAccepted',
    function(data)

        data =
            data or {}


        BeginRuntime(

            data.role,

            data.partnerSource,

            nil,

            false
        )
    end
)


---------------------------------------------------------
-- REAL FEEDING STOPPED
---------------------------------------------------------

RegisterNetEvent(
    'lb-vampire:client:feedingStopped',
    function()

        StopLocalAnimation()


        ResetRuntime()
    end
)


---------------------------------------------------------
-- FEEDING STATE SAFETY
---------------------------------------------------------

RegisterNetEvent(
    'lb-vampire:client:feedingState',
    function(data)

        data =
            data
            or {}


        if data.state ==
            'IDLE'
            and Runtime.active == true
            and Runtime.debugMode ~= true then


            StopLocalAnimation()


            ResetRuntime()
        end
    end
)


---------------------------------------------------------
-- DEBUG RUNTIME START
--
-- LOCAL EVENT ONLY.
---------------------------------------------------------

AddEventHandler(
    'lb-vampire:client:debugFeedingRuntimeStart',
    function(data)

        if Config.Debug ~= true then
            return
        end


        data =
            data
            or {}


        local partnerPed =
            tonumber(
                data.partnerPed
            )


        if not partnerPed
            or not DoesEntityExist(
                partnerPed
            ) then


            print(
                '^1[LB-VAMPIRE]^7 Debug Feeding: invalid NPC ped.'
            )


            return
        end


        BeginRuntime(

            data.role
                or 'VAMPIRE',

            nil,

            partnerPed,

            true
        )
    end
)


---------------------------------------------------------
-- DEBUG RUNTIME STOP
---------------------------------------------------------

AddEventHandler(
    'lb-vampire:client:debugFeedingRuntimeStop',
    function()

        if Runtime.debugMode ~= true then
            return
        end


        StopLocalAnimation()


        ResetRuntime()
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


        StopLocalAnimation()


        ResetRuntime()
    end
)