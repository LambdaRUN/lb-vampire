LBVampire = LBVampire or {}

LBVampire.ClientState =
    LBVampire.ClientState or {}

LBVampire.ClientState.sunState =
    'SAFE'

LBVampire.ClientState.sunReason =
    'WAITING_FOR_CALCULATION'


local lastCalculatedState = nil
local lastCalculatedReason = nil


--
-- PHYSICAL COVER CACHE
--
local coverCache = {
    hasCover = false,
    hits = 0,
    total = 0,
    checked = false
}


---------------------------------------------------------
-- DAYLIGHT
---------------------------------------------------------

local function IsDaylight()
    local hour =
        GetClockHours()

    local startHour =
        tonumber(
            Config.Sun.DayStartHour
        ) or 6

    local endHour =
        tonumber(
            Config.Sun.DayEndHour
        ) or 20

    return hour >= startHour
        and hour < endHour
end


---------------------------------------------------------
-- INTERIOR
---------------------------------------------------------

local function IsInsideInterior(ped)
    if not ped
        or ped == 0 then

        return false
    end

    return GetInteriorFromEntity(
        ped
    ) ~= 0
end


---------------------------------------------------------
-- VEHICLE
---------------------------------------------------------

local function GetVehicleOverride(
    vehicle
)
    local vehicleConfig =
        Config.Sun.Vehicle

    if not vehicleConfig
        or not vehicleConfig.ModelOverrides then

        return nil
    end

    local model =
        GetEntityModel(
            vehicle
        )

    for modelName, protects in pairs(
        vehicleConfig.ModelOverrides
    ) do

        if GetHashKey(modelName) == model then
            return protects == true
        end
    end

    return nil
end


local function DoesVehicleProtectFromSun(
    ped
)
    if not Config.Sun.Vehicle
        or Config.Sun.Vehicle.Enabled ~= true then

        return false,
            'VEHICLE_CHECK_DISABLED'
    end

    if not IsPedInAnyVehicle(
        ped,
        false
    ) then

        return false,
            'NO_VEHICLE'
    end

    local vehicle =
        GetVehiclePedIsIn(
            ped,
            false
        )

    if vehicle == 0
        or not DoesEntityExist(vehicle) then

        return false,
            'INVALID_VEHICLE'
    end


    --
    -- CUSTOM MODEL OVERRIDE
    --
    local override =
        GetVehicleOverride(
            vehicle
        )

    if override ~= nil then

        if override then
            return true,
                'VEHICLE_OVERRIDE_SAFE'
        end

        return false,
            'VEHICLE_OVERRIDE_OPEN'
    end


    --
    -- MOTORCYCLE / BICYCLE / BOAT
    --
    local vehicleClass =
        GetVehicleClass(
            vehicle
        )

    if Config.Sun.Vehicle
        .OpenClasses[vehicleClass] then

        return false,
            (
                'OPEN_VEHICLE_CLASS_%s'
            ):format(
                vehicleClass
            )
    end


    --
    -- CONVERTIBLE
    --
    if IsVehicleAConvertible(
        vehicle,
        false
    ) then

        local roofState =
            GetConvertibleRoofState(
                vehicle
            )

        if roofState == 0 then
            return true,
                'CONVERTIBLE_CLOSED'
        end

        return false,
            (
                'CONVERTIBLE_OPEN_%s'
            ):format(
                roofState
            )
    end


    --
    -- ROOFLESS VEHICLE
    --
    if not DoesVehicleHaveRoof(
        vehicle
    ) then

        return false,
            'VEHICLE_NO_ROOF'
    end


    return true,
        'ENCLOSED_VEHICLE'
end


---------------------------------------------------------
-- PHYSICAL COVER
---------------------------------------------------------

local function PerformCoverRay(
    ped,
    coords,
    offset
)
    local coverConfig =
        Config.Sun.Cover

    local rayHeight =
        tonumber(
            coverConfig.RayHeight
        ) or 30.0

    local traceFlags =
        tonumber(
            coverConfig.TraceFlags
        ) or 17

    local optionFlags =
        tonumber(
            coverConfig.OptionFlags
        ) or 7


    local startX =
        coords.x + offset.x

    local startY =
        coords.y + offset.y

    local startZ =
        coords.z + 0.5


    local endX =
        startX

    local endY =
        startY

    local endZ =
        startZ + rayHeight


    local handle =
        StartShapeTestLosProbe(
            startX,
            startY,
            startZ,

            endX,
            endY,
            endZ,

            traceFlags,

            ped,

            optionFlags
        )


    if not handle
        or handle == 0 then

        return false
    end


    --
    -- Shape test asynchronous çalışıyor.
    -- Sonuç hazır olana kadar birkaç frame
    -- bekliyoruz.
    --
    for _ = 1, 10 do

        local status,
            hit =
            GetShapeTestResult(
                handle
            )

        --
        -- 2 = complete
        --
        if status == 2 then

            return hit == true
                or hit == 1
        end


        --
        -- 0 = invalid handle
        --
        if status == 0 then
            return false
        end


        --
        -- 1 = pending
        --
        Wait(0)
    end


    return false
end


local function CalculatePhysicalCover(
    ped
)
    local coverConfig =
        Config.Sun.Cover

    if not coverConfig
        or coverConfig.Enabled ~= true then

        return false, 0, 0
    end


    local coords =
        GetEntityCoords(
            ped
        )

    local offsets =
        coverConfig.Offsets
        or {
            {
                x = 0.0,
                y = 0.0
            }
        }


    local requiredHits =
        tonumber(
            coverConfig.RequiredHits
        ) or 1


    local hits = 0
    local total = #offsets


    for _, offset in ipairs(
        offsets
    ) do

        local hit =
            PerformCoverRay(
                ped,
                coords,
                offset
            )

        if hit then
            hits =
                hits + 1
        end
    end


    return hits >= requiredHits,
        hits,
        total
end


---------------------------------------------------------
-- COVER DETECTION THREAD
---------------------------------------------------------

CreateThread(function()

    print(
        '^2[LB-VAMPIRE]^7 Physical cover detector STARTED'
    )

    while true do

        Wait(
            tonumber(
                Config.Sun.Cover
                    and Config.Sun.Cover.CheckInterval
            ) or 1000
        )


        if not Config.Sun.Cover
            or Config.Sun.Cover.Enabled ~= true then

            coverCache.hasCover =
                false

            coverCache.hits =
                0

            coverCache.total =
                0

            coverCache.checked =
                true

            goto continue
        end


        --
        -- İnsan için cover hesaplamamıza gerek yok.
        --
        if not LBVampire.ClientState
            or LBVampire.ClientState.isVampire ~= true then

            coverCache.hasCover =
                false

            coverCache.hits =
                0

            coverCache.checked =
                true

            goto continue
        end


        --
        -- Gece zaten SAFE.
        --
        if not IsDaylight() then

            coverCache.hasCover =
                false

            coverCache.hits =
                0

            coverCache.checked =
                true

            goto continue
        end


        local ped =
            PlayerPedId()

        if not DoesEntityExist(ped) then
            goto continue
        end


        --
        -- Interior zaten ayrı sistemden SAFE.
        -- Burada raycast harcamıyoruz.
        --
        if IsInsideInterior(ped) then

            coverCache.hasCover =
                false

            coverCache.hits =
                0

            coverCache.checked =
                true

            goto continue
        end


        --
        -- Kapalı araç zaten SAFE.
        --
        local vehicleProtected =
            DoesVehicleProtectFromSun(
                ped
            )

        if vehicleProtected then

            coverCache.hasCover =
                false

            coverCache.hits =
                0

            coverCache.checked =
                true

            goto continue
        end


        --
        -- Yaya veya açık araç:
        -- gerçek physical cover kontrolü.
        --
        local hasCover,
            hits,
            total =
            CalculatePhysicalCover(
                ped
            )


        coverCache.hasCover =
            hasCover

        coverCache.hits =
            hits

        coverCache.total =
            total

        coverCache.checked =
            true


        ::continue::
    end
end)


---------------------------------------------------------
-- SUN STATE
---------------------------------------------------------

local function CalculateSunState()

    if not Config.Sun
        or Config.Sun.Enabled ~= true then

        return 'SAFE',
            'SYSTEM_DISABLED'
    end


    if not LBVampire.ClientState
        or LBVampire.ClientState.isVampire ~= true then

        return 'SAFE',
            'NOT_VAMPIRE'
    end


    if not LBVampire.Weather
        or not LBVampire.Weather.IsReady
        or not LBVampire.Weather.IsReady() then

        return 'SAFE',
            'WEATHER_NOT_READY'
    end


    local ped =
        PlayerPedId()


    if not DoesEntityExist(ped) then
        return 'SAFE',
            'INVALID_PED'
    end


    --
    -- NIGHT
    --
    if not IsDaylight() then

        return 'SAFE',
            'NIGHT'
    end


    --
    -- INTERIOR
    --
    if IsInsideInterior(ped) then

        return 'SAFE',
            'INTERIOR'
    end


    --
    -- VEHICLE
    --
    local vehicleProtected,
        vehicleReason =
        DoesVehicleProtectFromSun(
            ped
        )

    if vehicleProtected then

        return 'SAFE',
            vehicleReason
    end


    --
    -- PHYSICAL COVER
    --
    if coverCache.checked
        and coverCache.hasCover then

        return 'SAFE',
            'PHYSICAL_COVER'
    end


    --
    -- WEATHER
    --
    local weather =
        LBVampire.Weather.GetCurrent()
        or 'CLEAR'


    if LBVampire.Weather.IsReduced(
        weather
    ) then

        return 'REDUCED',
            (
                'WEATHER_%s'
            ):format(
                weather
            )
    end


    --
    -- NOTHING PROTECTS PLAYER
    --
    return 'DIRECT',
        'OPEN_SKY'
end


---------------------------------------------------------
-- SERVER SYNC
---------------------------------------------------------

local function SendSunState(
    state
)
    TriggerServerEvent(
        'lb-vampire:server:updateSunState',
        state
    )
end


RegisterNetEvent(
    'lb-vampire:client:sunSync',
    function(state)

        state =
            string.upper(
                tostring(
                    state or 'SAFE'
                )
            )


        LBVampire.ClientState.sunState =
            state


        TriggerEvent(
            'lb-vampire:client:sunStateUpdated',
            state
        )
    end
)


---------------------------------------------------------
-- MAIN SUN THREAD
---------------------------------------------------------

CreateThread(function()

    print(
        '^2[LB-VAMPIRE]^7 Sun calculation thread STARTED'
    )


    while true do

        Wait(
            tonumber(
                Config.Sun.CheckInterval
            ) or 2000
        )


        local state,
            reason =
            CalculateSunState()


        local stateChanged =
            state ~= lastCalculatedState


        local reasonChanged =
            reason ~= lastCalculatedReason


        LBVampire.ClientState.sunReason =
            reason


        if stateChanged then
            SendSunState(
                state
            )
        end


        if Config.Debug
            and (
                stateChanged
                or reasonChanged
            ) then

            print(
                (
                    '^5[LB-VAMPIRE]^7 Sun calculation: %s | Reason: %s | Weather: %s | Cover: %d/%d | Hour: %02d:%02d'
                ):format(
                    state,
                    reason,

                    LBVampire.Weather.GetCurrent()
                        or 'UNKNOWN',

                    coverCache.hits,
                    coverCache.total,

                    GetClockHours(),
                    GetClockMinutes()
                )
            )
        end


        lastCalculatedState =
            state

        lastCalculatedReason =
            reason
    end
end)


---------------------------------------------------------
-- VAMPIRE STATE CHANGES
---------------------------------------------------------

AddEventHandler(
    'lb-vampire:client:bloodStateUpdated',
    function(state)

        if not state
            or state.isVampire ~= true then

            lastCalculatedState =
                nil

            lastCalculatedReason =
                nil


            coverCache.hasCover =
                false

            coverCache.hits =
                0

            coverCache.total =
                0

            coverCache.checked =
                false


            LBVampire.ClientState.sunState =
                'SAFE'


            LBVampire.ClientState.sunReason =
                'NOT_VAMPIRE'


            SendSunState(
                'SAFE'
            )


            TriggerEvent(
                'lb-vampire:client:sunStateUpdated',
                'SAFE'
            )
        end
    end
)


---------------------------------------------------------
-- DEBUG COMMAND
---------------------------------------------------------

RegisterCommand(
    'vampsun',
    function()

        local state =
            LBVampire.ClientState.sunState
            or 'UNKNOWN'


        local reason =
            LBVampire.ClientState.sunReason
            or 'UNKNOWN'


        local weather =
            LBVampire.Weather
            and LBVampire.Weather.GetCurrent
            and LBVampire.Weather.GetCurrent()
            or 'UNKNOWN'


        local message =
            (
                'Sun: %s | Reason: %s | Weather: %s | Cover: %d/%d | %02d:%02d'
            ):format(
                state,
                reason,
                weather,

                coverCache.hits,
                coverCache.total,

                GetClockHours(),
                GetClockMinutes()
            )


        print(
            '^5[LB-VAMPIRE]^7 '
            .. message
        )


        TriggerEvent(
            'QBCore:Notify',
            message,
            'primary',
            7000
        )
    end,
    false
)