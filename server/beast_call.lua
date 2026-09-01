LBVampire = LBVampire or {}
LBVampire.BeastCall = LBVampire.BeastCall or {}
LBVampire.Runtime = LBVampire.Runtime or {}
LBVampire.Runtime.BeastCallSessions = LBVampire.Runtime.BeastCallSessions or {}
LBVampire.Runtime.BeastCallByNetId = LBVampire.Runtime.BeastCallByNetId or {}
LBVampire.Runtime.BeastCallCooldowns = LBVampire.Runtime.BeastCallCooldowns or {}
LBVampire.Runtime.Interactions = LBVampire.Runtime.Interactions or {}

local BeastCall = LBVampire.BeastCall
local Sessions = LBVampire.Runtime.BeastCallSessions
local ByNetId = LBVampire.Runtime.BeastCallByNetId
local Cooldowns = LBVampire.Runtime.BeastCallCooldowns
local sequence = 0

local function GetConfig()
    return Config.BeastCall or {}
end

local function GetFeedingConfig()
    return GetConfig().Feeding or {}
end

local function GetTransferConfig()
    return GetFeedingConfig().Transfer or {}
end

local function IsPlayerOnline(src)
    src = tonumber(src)
    return src and src > 0 and GetPlayerName(src) ~= nil
end

local function IsVampire(src)
    return LBVampire.Vampires
        and LBVampire.Vampires.IsVampire
        and LBVampire.Vampires.IsVampire(src) == true
end

local function GetVampireState(src)
    if not LBVampire.Vampires or not LBVampire.Vampires.GetState then
        return nil
    end
    return LBVampire.Vampires.GetState(src)
end

local function GetCitizenId(src)
    if LBVampire.Framework and LBVampire.Framework.GetCitizenId then
        return LBVampire.Framework.GetCitizenId(src)
    end
    return nil
end

local function Notify(src, message, notifyType, duration)
    if not IsPlayerOnline(src) then return end

    if LBVampire.Notify and LBVampire.Notify.Send then
        LBVampire.Notify.Send(src, message, notifyType or 'primary', duration or 5000)
        return
    end

    TriggerClientEvent('QBCore:Notify', src, message, notifyType or 'primary', duration or 5000)
end

local function Clamp(value, minimum, maximum)
    value = tonumber(value) or 0
    minimum = tonumber(minimum) or 0
    maximum = tonumber(maximum) or minimum

    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

local function RandomBetween(minimum, maximum)
    minimum = math.floor(tonumber(minimum) or 0)
    maximum = math.floor(tonumber(maximum) or minimum)
    if maximum < minimum then minimum, maximum = maximum, minimum end
    if maximum == minimum then return minimum end
    return math.random(minimum, maximum)
end

local function NewToken(src)
    sequence = sequence + 1
    return ('beast:%s:%s:%s'):format(
        tostring(src),
        tostring(GetGameTimer()),
        tostring(sequence)
    )
end

local function GetEntityFromNetId(netId, timeout)
    netId = tonumber(netId)
    if not netId or netId <= 0 then return nil end

    timeout = math.max(tonumber(timeout) or 0, 0)
    local expires = GetGameTimer() + timeout

    repeat
        local entity = NetworkGetEntityFromNetworkId(netId)
        if entity and entity ~= 0 and DoesEntityExist(entity) then
            return entity
        end

        if timeout <= 0 or GetGameTimer() >= expires then break end
        Wait(25)
    until false

    return nil
end

local function GetPlayerCoords(src)
    local ped = GetPlayerPed(tonumber(src))
    if not ped or ped == 0 or not DoesEntityExist(ped) then return nil end

    local coords = GetEntityCoords(ped)
    if not coords then return nil end

    return {
        x = tonumber(coords.x) or 0.0,
        y = tonumber(coords.y) or 0.0,
        z = tonumber(coords.z) or 0.0
    }
end

local function Distance(a, b)
    if not a or not b then return math.huge end
    local dx = (tonumber(a.x) or 0.0) - (tonumber(b.x) or 0.0)
    local dy = (tonumber(a.y) or 0.0) - (tonumber(b.y) or 0.0)
    local dz = (tonumber(a.z) or 0.0) - (tonumber(b.z) or 0.0)
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function IsInsideSafeZone(coords)
    if not coords then return false, nil end

    for _, zone in ipairs((Config.BeastCall and Config.BeastCall.SafeZones) or {}) do
        local zoneCoords = zone.Coords or zone.coords
        local radius = tonumber(zone.Radius or zone.radius) or 0.0

        if zoneCoords and radius > 0.0 and Distance(coords, zoneCoords) <= radius then
            return true, tostring(zone.Name or zone.name or 'Wilderness Safezone')
        end
    end

    return false, nil
end

local function SetSharedInteraction(src, stateName, token)
    local citizenId = GetCitizenId(src)
    if not citizenId then return false end

    if stateName == 'IDLE' then
        local current = LBVampire.Runtime.Interactions[citizenId]
        if not token or not current or current.token == token then
            LBVampire.Runtime.Interactions[citizenId] = nil
        end
    else
        LBVampire.Runtime.Interactions[citizenId] = {
            source = src,
            citizenId = citizenId,
            state = stateName,
            token = token,
            partnerSource = nil
        }
    end

    local vampireState = GetVampireState(src)
    if vampireState then
        vampireState.interactionState = stateName
    end

    if IsPlayerOnline(src) then
        TriggerClientEvent('lb-vampire:client:feedingState', src, {
            state = stateName,
            token = token,
            partnerSource = nil
        })
    end

    return true
end

local function SaveVampire(src)
    if not IsPlayerOnline(src) then return end
    local state = GetVampireState(src)
    if not state then return end
    if not LBVampire.Persistence or not LBVampire.Persistence.SaveRuntimeState then return end

    local success = LBVampire.Persistence.SaveRuntimeState(state)
    if success then state.dirty = false end
end

local function SelectWeightedAnimal()
    local animals = GetConfig().Animals or {}
    local candidates = {}
    local totalWeight = 0

    for key, data in pairs(animals) do
        local weight = math.max(math.floor(tonumber(data.Weight) or 0), 0)
        local blood = tonumber(data.Blood) or 0
        local model = tostring(data.Model or '')

        if weight > 0 and blood > 0 and model ~= '' then
            totalWeight = totalWeight + weight
            candidates[#candidates + 1] = {
                key = tostring(key),
                data = data,
                cumulative = totalWeight
            }
        end
    end

    if totalWeight <= 0 or #candidates == 0 then
        return nil
    end

    local roll = math.random(1, totalWeight)
    for _, entry in ipairs(candidates) do
        if roll <= entry.cumulative then
            return entry.key, entry.data, roll, totalWeight
        end
    end

    local fallback = candidates[#candidates]
    return fallback.key, fallback.data, roll, totalWeight
end

local function ScheduleEntityDelete(netId, delay)
    netId = tonumber(netId)
    if not netId or netId <= 0 then return end

    CreateThread(function()
        Wait(math.max(tonumber(delay) or 0, 0) + 4000)

        local entity = GetEntityFromNetId(netId, 500)
        if entity and DoesEntityExist(entity) then
            DeleteEntity(entity)
        end
    end)
end

local function ClearSession(src)
    src = tonumber(src)
    local session = src and Sessions[src] or nil
    if not session then return nil end

    Sessions[src] = nil
    if session.netId and ByNetId[session.netId] == src then
        ByNetId[session.netId] = nil
    end

    return session
end

local function StopSession(src, reason, outcome, options)
    src = tonumber(src)
    local session = src and Sessions[src] or nil
    if not session then return false end

    reason = tostring(reason or 'stopped')
    options = options or {}

    local remainingBlood = math.max(tonumber(session.blood) or 0.0, 0.0)

    if not outcome then
        if remainingBlood <= 0.001 then
            outcome = 'drained'
        elseif session.state == 'FEEDING' then
            outcome = 'released'
        else
            outcome = 'lost'
        end
    end

    ClearSession(src)
    SetSharedInteraction(src, 'IDLE', session.token)

    if IsPlayerOnline(src) then
        TriggerClientEvent('lb-vampire:client:beastFeedingStopped', src, {
            token = session.token,
            netId = session.netId,
            reason = reason,
            outcome = outcome,
            remainingBlood = remainingBlood,
            maxBlood = session.maxBlood,
            label = session.label,
            releaseDespawnDelay = tonumber(GetConfig().Cleanup and GetConfig().Cleanup.ReleaseDespawnDelay) or 12000,
            drainedDespawnDelay = tonumber(GetConfig().Cleanup and GetConfig().Cleanup.DrainedDespawnDelay) or 15000,
            lostDespawnDelay = tonumber(GetConfig().Cleanup and GetConfig().Cleanup.LostDespawnDelay) or 1500
        })
    end

    if session.netId then
        local cleanup = GetConfig().Cleanup or {}
        local delay = tonumber(cleanup.LostDespawnDelay) or 1500
        if outcome == 'released' then
            delay = tonumber(cleanup.ReleaseDespawnDelay) or 12000
        elseif outcome == 'drained' then
            delay = tonumber(cleanup.DrainedDespawnDelay) or 15000
        end
        ScheduleEntityDelete(session.netId, delay)
    end

    if options.save ~= false then
        SaveVampire(src)
    end

    if Config.Debug then
        print((
            '^5[LB-VAMPIRE]^7 Beast session STOP | Source:%s | Animal:%s | Reason:%s | Outcome:%s | Remaining:%.2f'
        ):format(
            tostring(src),
            tostring(session.animalKey),
            reason,
            tostring(outcome),
            remainingBlood
        ))
    end

    return true
end

local function RefundSpawnFailure(src, token, reason)
    local session = Sessions[tonumber(src)]
    if not session or session.token ~= token or session.state ~= 'PENDING_SPAWN' then return false end

    local vampireState = GetVampireState(src)
    if LBVampire.Blood and LBVampire.Blood.Add then
        LBVampire.Blood.Add(src, session.cost, false)
    end

    if vampireState then
        vampireState.beastCallCooldown = 0
        vampireState.beastCallCooldownDuration = 0
    end

    local citizenId = GetCitizenId(src)
    if citizenId then
        Cooldowns[citizenId] = nil
    end

    ClearSession(src)
    Notify(src, 'Beast Call av oluşturamadı; harcanan kan geri verildi.', 'error', 5000)

    if Config.Debug then
        print(('^3[LB-VAMPIRE]^7 Beast spawn refunded | Source:%s | Reason:%s'):format(
            tostring(src), tostring(reason or 'spawn_failed')
        ))
    end

    return true
end

local function EvaluateDispatch(session, coords)
    if session.dispatchEvaluated == true then return end
    session.dispatchEvaluated = true

    local config = GetConfig().Dispatch or {}
    if config.Enabled ~= true or Config.Dispatch == nil or Config.Dispatch.Enabled ~= true then
        return
    end

    local insideSafeZone, zoneName = IsInsideSafeZone(coords)
    local chance = insideSafeZone
        and tonumber(config.SafezoneChance)
        or tonumber(config.OutsideChance)

    chance = Clamp(chance or 0, 0, 100)
    local roll = math.random(1, 100)
    local success = roll <= chance

    session.dispatchInsideSafeZone = insideSafeZone
    session.dispatchZone = zoneName
    session.dispatchChance = chance
    session.dispatchRoll = roll
    session.dispatchSuccessful = success

    if Config.Debug then
        print((
            '^5[LB-VAMPIRE]^7 Beast Dispatch Roll | Source:%s | Animal:%s | Safezone:%s | Zone:%s | Chance:%s%% | Roll:%s | Dispatch:%s'
        ):format(
            tostring(session.source),
            tostring(session.animalKey),
            tostring(insideSafeZone),
            tostring(zoneName),
            tostring(chance),
            tostring(roll),
            tostring(success)
        ))
    end

    if not success then return end

    local delayConfig = config.Delay or {}
    local delay = RandomBetween(delayConfig.Min or 5000, delayConfig.Max or 12000)
    local capturedSource = session.source
    local capturedCoords = {
        x = tonumber(coords.x) or 0.0,
        y = tonumber(coords.y) or 0.0,
        z = tonumber(coords.z) or 0.0
    }

    CreateThread(function()
        Wait(delay)

        if not LBVampire.Dispatch or not LBVampire.Dispatch.Send then
            if Config.Debug then
                print('^1[LB-VAMPIRE]^7 Beast dispatch skipped: dispatch manager unavailable.')
            end
            return
        end

        LBVampire.Dispatch.Send({
            source = capturedSource,
            kind = 'beast_call',
            coords = capturedCoords
        })
    end)
end

local function SendStatus(src, session)
    if not IsPlayerOnline(src) then return end

    local statusConfig = GetFeedingConfig().StatusUI or {}
    if statusConfig.Enabled ~= true then return end

    local thresholds = statusConfig.Thresholds or {}
    local maxBlood = math.max(tonumber(session.maxBlood) or 1.0, 1.0)

    TriggerClientEvent('lb-vampire:client:beastFeedingStatusUpdate', src, {
        blood = math.max(tonumber(session.blood) or 0.0, 0.0),
        maxBlood = maxBlood,
        lowThreshold = maxBlood * ((tonumber(thresholds.Low) or 70) / 100.0),
        criticalThreshold = maxBlood * ((tonumber(thresholds.Critical) or 40) / 100.0),
        severeThreshold = maxBlood * ((tonumber(thresholds.Severe) or 20) / 100.0)
    })
end

local function StartTransferThread(src, token)
    CreateThread(function()
        local transfer = GetTransferConfig()
        local interval = math.max(math.floor(tonumber(transfer.TickInterval) or 500), 100)
        local ratePerSecond = math.max(tonumber(transfer.RatePerSecond) or 2.0, 0.01)
        local gainRatio = math.max(tonumber(transfer.GainRatio) or 1.0, 0.01)
        local drainPerTick = ratePerSecond * (interval / 1000.0)

        local session = Sessions[src]
        if not session or session.token ~= token or session.state ~= 'FEEDING' then return end
        SendStatus(src, session)

        while true do
            Wait(interval)

            session = Sessions[src]
            if not session or session.token ~= token or session.state ~= 'FEEDING' then return end
            if not IsPlayerOnline(src) or not IsVampire(src) then
                StopSession(src, 'player_unavailable', 'released', { save = false })
                return
            end

            local prey = GetEntityFromNetId(session.netId, 250)
            if not prey or not DoesEntityExist(prey) or GetEntityHealth(prey) <= 0 then
                StopSession(src, 'prey_unavailable', 'lost')
                return
            end

            local playerCoords = GetPlayerCoords(src)
            local preyCoordsRaw = GetEntityCoords(prey)
            local preyCoords = preyCoordsRaw and {
                x = preyCoordsRaw.x,
                y = preyCoordsRaw.y,
                z = preyCoordsRaw.z
            } or nil

            if not playerCoords or not preyCoords then
                StopSession(src, 'coords_unavailable', 'released')
                return
            end

            local maximumDistance = tonumber(GetFeedingConfig().Interrupts and GetFeedingConfig().Interrupts.MaxDistance) or 3.5
            if Distance(playerCoords, preyCoords) > maximumDistance then
                StopSession(src, 'distance', 'released')
                return
            end

            local vampireBlood = tonumber(LBVampire.Blood and LBVampire.Blood.Get and LBVampire.Blood.Get(src)) or 0.0
            local vampireMax = tonumber(Config.Blood and Config.Blood.Max) or 100.0
            local room = math.max(vampireMax - vampireBlood, 0.0)

            if room <= 0.001 then
                StopSession(src, 'vampire_full', 'released')
                return
            end

            local possibleDrain = math.min(
                math.max(tonumber(session.blood) or 0.0, 0.0),
                drainPerTick,
                room / gainRatio
            )

            if possibleDrain <= 0.001 then
                StopSession(src, 'no_transfer', 'released')
                return
            end

            local added, addReason = LBVampire.Blood.Add(src, possibleDrain * gainRatio, false)
            if added ~= true then
                if Config.Debug then
                    print(('^1[LB-VAMPIRE]^7 Beast blood gain failed: %s'):format(tostring(addReason)))
                end
                StopSession(src, 'blood_add_failed', 'released')
                return
            end

            session.blood = math.max((tonumber(session.blood) or 0.0) - possibleDrain, 0.0)

            -- İlk gerçek blood transfer tick'i = tek dispatch değerlendirmesi.
            EvaluateDispatch(session, preyCoords)
            SendStatus(src, session)

            if session.blood <= 0.001 then
                session.blood = 0.0
                StopSession(src, 'drained', 'drained')
                return
            end
        end
    end)
end

RegisterNetEvent('lb-vampire:server:requestBeastCall', function()
    local src = tonumber(source)
    local config = GetConfig()

    if config.Enabled ~= true then
        Notify(src, 'Beast Call şu anda devre dışı.', 'error')
        return
    end

    if not IsVampire(src) then
        Notify(src, 'Bu yeteneği yalnız vampirler kullanabilir.', 'error')
        return
    end

    if Sessions[src] then
        Notify(src, 'Zaten aktif bir Beast Call avın var.', 'error')
        return
    end

    local state = GetVampireState(src)
    if not state then return end

    local interaction = LBVampire.Runtime.Interactions[GetCitizenId(src) or '']
    if interaction or (state.interactionState and state.interactionState ~= 'IDLE') then
        Notify(src, 'Başka bir etkileşim sürerken Beast Call kullanamazsın.', 'error')
        return
    end

    local now = os.time()
    local citizenId = GetCitizenId(src)
    local stateCooldown = tonumber(state.beastCallCooldown) or 0
    local runtimeCooldown = citizenId and tonumber(Cooldowns[citizenId]) or 0
    local cooldownUntil = math.max(stateCooldown, runtimeCooldown or 0)

    if cooldownUntil > now then
        state.beastCallCooldown = cooldownUntil
        Notify(src, ('Beast Call tekrar kullanıma %s saniye sonra hazır.'):format(cooldownUntil - now), 'error')
        return
    end

    local cost = math.max(tonumber(config.BloodCost) or 10, 0)
    local currentBlood = tonumber(LBVampire.Blood and LBVampire.Blood.Get and LBVampire.Blood.Get(src)) or 0.0
    if currentBlood + 0.001 < cost then
        Notify(src, ('Beast Call için en az %s Blood gerekli.'):format(cost), 'error')
        return
    end

    local animalKey, animal, roll, totalWeight = SelectWeightedAnimal()
    if not animalKey or not animal then
        Notify(src, 'Beast Call için geçerli hayvan konfigürasyonu bulunamadı.', 'error')
        return
    end

    local removed, removeReason = LBVampire.Blood.Remove(src, cost, false)
    if removed ~= true then
        Notify(src, ('Beast Call Blood maliyeti uygulanamadı: %s'):format(tostring(removeReason)), 'error')
        return
    end

    local cooldown = config.Cooldown or {}
    local cooldownSeconds = RandomBetween(cooldown.Min or 600, cooldown.Max or 900)
    state.beastCallCooldown = now + cooldownSeconds
    state.beastCallCooldownDuration = cooldownSeconds
    if citizenId then
        Cooldowns[citizenId] = state.beastCallCooldown
    end

    local token = NewToken(src)
    local maxBlood = math.max(tonumber(animal.Blood) or 1.0, 1.0)

    Sessions[src] = {
        source = src,
        token = token,
        state = 'PENDING_SPAWN',
        animalKey = animalKey,
        model = tostring(animal.Model),
        label = tostring(animal.Label or animalKey),
        animationProfile = tostring(animal.AnimationProfile or 'deer'),
        maxBlood = maxBlood,
        blood = maxBlood,
        cost = cost,
        netId = nil,
        dispatchEvaluated = false,
        createdAt = GetGameTimer()
    }

    TriggerClientEvent('lb-vampire:client:beastCallAuthorized', src, {
        token = token,
        animalKey = animalKey,
        model = tostring(animal.Model),
        label = tostring(animal.Label or animalKey),
        animationProfile = tostring(animal.AnimationProfile or 'deer'),
        maxBlood = maxBlood
    })

    if Config.Debug then
        print((
            '^2[LB-VAMPIRE]^7 Beast Call authorized | Source:%s | Animal:%s | WeightRoll:%s/%s | Cost:%s | Cooldown:%ss'
        ):format(
            tostring(src), animalKey, tostring(roll), tostring(totalWeight), tostring(cost), tostring(cooldownSeconds)
        ))
    end

    local timeout = math.max(tonumber(config.Spawn and config.Spawn.SessionTimeout) or 300000, 30000)
    CreateThread(function()
        Wait(timeout)
        local active = Sessions[src]
        if active and active.token == token then
            StopSession(src, 'session_timeout', active.state == 'FEEDING' and 'released' or 'lost')
        end
    end)
end)

RegisterNetEvent('lb-vampire:server:beastSpawnFailed', function(token, reason)
    RefundSpawnFailure(tonumber(source), tostring(token or ''), reason)
end)

RegisterNetEvent('lb-vampire:server:registerBeastPrey', function(token, netId)
    local src = tonumber(source)
    token = tostring(token or '')
    netId = tonumber(netId)

    local session = Sessions[src]
    if not session or session.token ~= token or session.state ~= 'PENDING_SPAWN' then return end
    if not netId or netId <= 0 then
        RefundSpawnFailure(src, token, 'invalid_netid')
        return
    end

    local entity = GetEntityFromNetId(netId, 2500)
    if not entity or not DoesEntityExist(entity) then
        RefundSpawnFailure(src, token, 'entity_unavailable')
        return
    end

    local expectedModel = joaat(session.model)
    local actualModel = GetEntityModel(entity)
    if expectedModel ~= 0 and actualModel ~= expectedModel then
        RefundSpawnFailure(src, token, 'model_mismatch')
        DeleteEntity(entity)
        return
    end

    session.netId = netId
    session.state = 'TRACKING'
    ByNetId[netId] = src

    TriggerClientEvent('lb-vampire:client:beastTrackingStarted', src, {
        token = token,
        netId = netId,
        animalKey = session.animalKey,
        label = session.label,
        animationProfile = session.animationProfile,
        blood = session.blood,
        maxBlood = session.maxBlood
    })

    Notify(src, 'Koku izini aldın. Avını takip et.', 'success', 4000)

    if Config.Debug then
        print(('^2[LB-VAMPIRE]^7 Beast prey registered | Source:%s | NetID:%s | Animal:%s'):format(
            tostring(src), tostring(netId), tostring(session.animalKey)
        ))
    end
end)

RegisterNetEvent('lb-vampire:server:requestBeastFeeding', function(token, netId)
    local src = tonumber(source)
    token = tostring(token or '')
    netId = tonumber(netId)

    local session = Sessions[src]
    if not session or session.token ~= token or session.state ~= 'TRACKING' then return end
    if session.netId ~= netId or ByNetId[netId] ~= src then return end
    if not IsVampire(src) then return end

    local state = GetVampireState(src)
    if not state or (state.interactionState and state.interactionState ~= 'IDLE') then
        Notify(src, 'Şu anda bu avdan beslenemezsin.', 'error')
        return
    end

    local prey = GetEntityFromNetId(netId, 1000)
    if not prey or not DoesEntityExist(prey) or GetEntityHealth(prey) <= 0 then
        StopSession(src, 'prey_unavailable', 'lost')
        return
    end

    local playerCoords = GetPlayerCoords(src)
    local preyCoordsRaw = GetEntityCoords(prey)
    local preyCoords = preyCoordsRaw and { x = preyCoordsRaw.x, y = preyCoordsRaw.y, z = preyCoordsRaw.z } or nil
    local maxDistance = tonumber(GetFeedingConfig().Interaction and GetFeedingConfig().Interaction.Distance) or 2.5

    if not playerCoords or not preyCoords or Distance(playerCoords, preyCoords) > maxDistance + 0.75 then
        Notify(src, 'Av beslenmek için çok uzakta.', 'error')
        return
    end

    local currentBlood = tonumber(LBVampire.Blood and LBVampire.Blood.Get and LBVampire.Blood.Get(src)) or 0.0
    local vampireMax = tonumber(Config.Blood and Config.Blood.Max) or 100.0
    if currentBlood >= vampireMax - 0.001 then
        Notify(src, 'Kan rezervin zaten dolu.', 'error')
        return
    end

    session.state = 'FEEDING'
    session.feedingStartedAt = GetGameTimer()
    SetSharedInteraction(src, 'BEAST_FEEDING', token)

    TriggerClientEvent('lb-vampire:client:beastFeedingStarted', src, {
        token = token,
        netId = netId,
        animalKey = session.animalKey,
        label = session.label,
        animationProfile = session.animationProfile,
        blood = session.blood,
        maxBlood = session.maxBlood
    })

    if Config.Debug then
        print(('^2[LB-VAMPIRE]^7 Beast feeding START | Source:%s | Animal:%s | Blood:%.2f/%.2f'):format(
            tostring(src), tostring(session.animalKey), session.blood, session.maxBlood
        ))
    end

    StartTransferThread(src, token)
end)

RegisterNetEvent('lb-vampire:server:cancelBeastFeeding', function(reason)
    local src = tonumber(source)
    local session = Sessions[src]
    if not session or session.state ~= 'FEEDING' then return end
    StopSession(src, tostring(reason or 'manual_cancel'), 'released')
end)

RegisterNetEvent('lb-vampire:server:beastPreyLost', function(token, reason)
    local src = tonumber(source)
    local session = Sessions[src]
    if not session or session.token ~= tostring(token or '') then return end

    if session.state == 'FEEDING' then
        StopSession(src, tostring(reason or 'prey_lost'), 'released')
    else
        StopSession(src, tostring(reason or 'prey_lost'), 'lost')
    end
end)

AddEventHandler('lb-vampire:server:frameworkPlayerUnloaded', function(src)
    src = tonumber(src)
    if Sessions[src] then
        StopSession(src, 'player_unload', Sessions[src].state == 'FEEDING' and 'released' or 'lost', { save = false })
    end
end)

AddEventHandler('playerDropped', function()
    local src = tonumber(source)
    if not Sessions[src] then return end

    local session = ClearSession(src)
    if session and session.netId then
        ScheduleEntityDelete(session.netId, 0)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    for src, session in pairs(Sessions) do
        if session.netId then
            local entity = GetEntityFromNetId(session.netId)
            if entity and DoesEntityExist(entity) then
                DeleteEntity(entity)
            end
        end
        Sessions[src] = nil
    end

    for netId in pairs(ByNetId) do
        ByNetId[netId] = nil
    end
end)

exports('GetBeastCallSession', function(src)
    return Sessions[tonumber(src)]
end)

if LBVampire.Abilities and LBVampire.Abilities.RegisterStatusProvider then
    LBVampire.Abilities.RegisterStatusProvider('beast_call', function(src)
        src = tonumber(src)
        local config = GetConfig()
        local cost = math.max(tonumber(config.BloodCost) or 10, 0)
        local vampireState = GetVampireState(src)
        local blood = tonumber(LBVampire.Blood and LBVampire.Blood.Get and LBVampire.Blood.Get(src)) or 0.0
        local maxBlood = tonumber(Config.Blood and Config.Blood.Max) or 100.0

        local result = {
            available = true,
            locked = false,
            active = false,
            reason = nil,
            bloodCost = cost,
            blood = blood,
            maxBlood = maxBlood,
            cooldownRemaining = 0,
            cooldownDuration = 0
        }

        if config.Enabled ~= true then
            result.available = false
            result.locked = true
            result.reason = 'Beast Call devre dışı'
            return result
        end

        if not IsVampire(src) or not vampireState then
            result.available = false
            result.locked = true
            result.reason = 'Yalnız vampirler kullanabilir'
            return result
        end

        if Sessions[src] then
            result.available = false
            result.active = true
            result.reason = 'Av zaten aktif'
            return result
        end

        local interaction = LBVampire.Runtime.Interactions[GetCitizenId(src) or '']
        if interaction or (vampireState.interactionState and vampireState.interactionState ~= 'IDLE') then
            result.available = false
            result.reason = 'Başka bir etkileşim sürüyor'
            return result
        end

        local now = os.time()
        local citizenId = GetCitizenId(src)
        local stateCooldown = tonumber(vampireState.beastCallCooldown) or 0
        local runtimeCooldown = citizenId and tonumber(Cooldowns[citizenId]) or 0
        local cooldownUntil = math.max(stateCooldown, runtimeCooldown or 0)
        local remaining = math.max(cooldownUntil - now, 0)

        result.cooldownRemaining = remaining
        result.cooldownDuration = math.max(
            tonumber(vampireState.beastCallCooldownDuration) or 0,
            remaining
        )

        if remaining > 0 then
            result.available = false
            result.reason = 'Cooldown'
            return result
        end

        if blood + 0.001 < cost then
            result.available = false
            result.reason = 'Yetersiz Kan'
            return result
        end

        return result
    end)
end

