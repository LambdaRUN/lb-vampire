LBVampire = LBVampire or {}
LBVampire.NPCFeeding = LBVampire.NPCFeeding or {}
LBVampire.Runtime = LBVampire.Runtime or {}
LBVampire.Runtime.NPCFeedingSessions = LBVampire.Runtime.NPCFeedingSessions or {}
LBVampire.Runtime.NPCFeedingByNetId = LBVampire.Runtime.NPCFeedingByNetId or {}
LBVampire.Runtime.NPCFeedingIncidentHistory = LBVampire.Runtime.NPCFeedingIncidentHistory or {}
LBVampire.Runtime.Interactions = LBVampire.Runtime.Interactions or {}

local NPCFeeding = LBVampire.NPCFeeding
local Sessions = LBVampire.Runtime.NPCFeedingSessions
local ByNetId = LBVampire.Runtime.NPCFeedingByNetId
local IncidentHistory = LBVampire.Runtime.NPCFeedingIncidentHistory
local sequence = 0

local function GetConfig()
    return Config.NPCFeeding or {}
end

local function GetTransferConfig()
    return GetConfig().Transfer or {}
end

local function GetStatusConfig()
    return GetConfig().StatusUI or {}
end

local function GetPartialIncidentConfig()
    local dispatch = GetConfig().Dispatch or {}
    return dispatch.PartialIncident or {}
end

local function GetInterruptConfig()
    return Config.Feeding and Config.Feeding.Interrupts or {}
end

local function IsPlayerOnline(src)
    src = tonumber(src)
    return src and src > 0 and GetPlayerName(src) ~= nil
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

        if timeout <= 0 or GetGameTimer() >= expires then
            break
        end

        Wait(25)
    until false

    return nil
end

local function IsPlayerPedEntity(entity)
    if not entity or entity == 0 then return false end

    for _, playerId in ipairs(GetPlayers()) do
        local playerPed = GetPlayerPed(tonumber(playerId))
        if playerPed and playerPed ~= 0 and playerPed == entity then
            return true
        end
    end

    return false
end

local function IsHumanPed(entity)
    if not Config.NPCFeeding
        or not Config.NPCFeeding.Witness
        or Config.NPCFeeding.Witness.HumanOnly == false then

        return true
    end

    if type(IsPedHuman) == 'function' then
        local ok, result = pcall(IsPedHuman, entity)
        if ok then return result == true end
    end

    if type(GetPedType) == 'function' then
        local ok, pedType = pcall(GetPedType, entity)
        if ok and tonumber(pedType) == 28 then return false end
    end

    return true
end

local function IsValidNPC(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        return false, 'npc_not_found'
    end

    if GetEntityType(entity) ~= 1 then
        return false, 'not_a_ped'
    end

    if IsPlayerPedEntity(entity) then
        return false, 'player_ped'
    end

    if GetEntityHealth(entity) <= 0 then
        return false, 'npc_dead'
    end

    if not IsHumanPed(entity) then
        return false, 'not_human'
    end

    return true
end

local function Distance(a, b)
    if not a or not b then return math.huge end

    local dx = a.x - b.x
    local dy = a.y - b.y
    local dz = a.z - b.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function IsWithinDistance(src, entity, maximum)
    if not IsPlayerOnline(src) or not entity or entity == 0 then return false end

    local playerPed = GetPlayerPed(src)
    if not playerPed or playerPed == 0 or not DoesEntityExist(playerPed) then
        return false
    end

    return Distance(GetEntityCoords(playerPed), GetEntityCoords(entity)) <= maximum
end

local function GenerateToken(src, netId)
    sequence = sequence + 1
    if sequence > 999999 then sequence = 1 end

    return ('npc:%s:%s:%s:%s'):format(
        tostring(src),
        tostring(netId),
        tostring(GetGameTimer()),
        tostring(sequence)
    )
end

local function IsVampire(src)
    return LBVampire.Vampires
        and LBVampire.Vampires.IsVampire
        and LBVampire.Vampires.IsVampire(src) == true
end

local function GetSharedInteraction(src)
    local citizenId = GetCitizenId(src)
    if not citizenId then return nil end
    return LBVampire.Runtime.Interactions[citizenId]
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

    if LBVampire.Vampires and LBVampire.Vampires.GetState then
        local state = LBVampire.Vampires.GetState(src)
        if state then
            state.interactionState = stateName
        end
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

local function GetReactionSource(entity, fallbackSource)
    if entity and entity ~= 0 and DoesEntityExist(entity) and type(NetworkGetEntityOwner) == 'function' then
        local ok, owner = pcall(NetworkGetEntityOwner, entity)
        owner = tonumber(owner)
        if ok and owner and owner > 0 and GetPlayerName(owner) then
            return owner
        end
    end

    return tonumber(fallbackSource)
end

local function SendReleasedReaction(session, remainingBlood, incidentResult)
    local entity = GetEntityFromNetId(session.netId)
    if not entity or GetEntityHealth(entity) <= 0 then return end

    local reactionSource = GetReactionSource(entity, session.source)
    if not reactionSource then return end

    incidentResult = type(incidentResult) == 'table' and incidentResult or {}

    TriggerClientEvent('lb-vampire:client:npcFeedingReleased', reactionSource, {
        netId = session.netId,
        remainingBlood = remainingBlood,
        caller = incidentResult.victimCaller == true,
        severity = incidentResult.severity,
        dispatched = incidentResult.dispatched == true
    })
end

local function PruneIncidentHistory(netId, now)
    netId = tonumber(netId)
    if not netId then return 0.0 end

    now = tonumber(now) or GetGameTimer()

    local config = GetPartialIncidentConfig()
    local memoryWindow = math.max(tonumber(config.MemoryWindow) or 60000, 1000)
    local history = IncidentHistory[netId]

    if type(history) ~= 'table' then
        IncidentHistory[netId] = nil
        return 0.0
    end

    local kept = {}
    local total = 0.0

    for i = 1, #history do
        local entry = history[i]
        local at = entry and tonumber(entry.at) or nil
        local amount = entry and tonumber(entry.amount) or 0.0

        if at and amount > 0 and now - at <= memoryWindow then
            kept[#kept + 1] = entry
            total = total + amount
        end
    end

    if #kept > 0 then
        IncidentHistory[netId] = kept
    else
        IncidentHistory[netId] = nil
    end

    return total
end

local function RecordIncidentDrain(netId, amount)
    netId = tonumber(netId)
    amount = tonumber(amount) or 0.0
    if not netId or amount <= 0 then
        return PruneIncidentHistory(netId, GetGameTimer())
    end

    local now = GetGameTimer()
    PruneIncidentHistory(netId, now)

    local history = IncidentHistory[netId] or {}
    history[#history + 1] = {
        at = now,
        amount = amount
    }
    IncidentHistory[netId] = history

    return PruneIncidentHistory(netId, now)
end

local function SaveVampire(src)
    if not IsPlayerOnline(src) then return end
    if not LBVampire.Vampires or not LBVampire.Vampires.GetState then return end
    if not LBVampire.Persistence or not LBVampire.Persistence.SaveRuntimeState then return end

    local state = LBVampire.Vampires.GetState(src)
    if not state then return end

    local success = LBVampire.Persistence.SaveRuntimeState(state)
    if success then state.dirty = false end
end

local function StopSession(src, reason, options)
    src = tonumber(src)
    local session = src and Sessions[src] or nil
    if not session then return false end

    options = options or {}
    reason = tostring(reason or 'cancelled')

    Sessions[src] = nil
    if ByNetId[session.netId] == src then
        ByNetId[session.netId] = nil
    end

    local bloodState = LBVampire.NPCBlood and LBVampire.NPCBlood.GetState
        and LBVampire.NPCBlood.GetState(session.netId)
        or nil

    if LBVampire.NPCBlood and LBVampire.NPCBlood.ClearFeedingToken then
        LBVampire.NPCBlood.ClearFeedingToken(session.netId, session.token)
    end

    SetSharedInteraction(src, 'IDLE', session.token)
    SaveVampire(src)

    if IsPlayerOnline(src) then
        TriggerClientEvent('lb-vampire:client:npcFeedingStopped', src, {
            reason = reason,
            token = session.token,
            netId = session.netId
        })
    end

    local remainingBlood = bloodState and tonumber(bloodState.blood) or nil
    local drained = bloodState and bloodState.drained == true or false

    if options.releaseAlive == true and remainingBlood and remainingBlood > 0 and not drained then
        local incidentResult = nil
        local partialConfig = GetPartialIncidentConfig()
        local recentLoss = RecordIncidentDrain(session.netId, session.totalDrained)

        if partialConfig.Enabled == true
            and LBVampire.NPCWitness
            and LBVampire.NPCWitness.HandleRelease then

            local handled, result = LBVampire.NPCWitness.HandleRelease(src, session.netId, {
                reason = reason,
                sessionLoss = tonumber(session.totalDrained) or 0.0,
                recentLoss = recentLoss,
                remainingBlood = remainingBlood,
                maxBlood = tonumber(GetConfig().Blood and GetConfig().Blood.Max) or 100
            })

            if handled == true and type(result) == 'table' then
                incidentResult = result
            end
        end

        SendReleasedReaction(session, remainingBlood, incidentResult)
    end

    if options.handleDepletion == true and drained then
        IncidentHistory[session.netId] = nil

        if LBVampire.NPCWitness and LBVampire.NPCWitness.HandleDepletion then
            LBVampire.NPCWitness.HandleDepletion(src, session.netId)
        end
    end

    if Config.Debug then
        print((
            '^5[LB-VAMPIRE]^7 NPC feeding STOP | Source:%s | NetID:%s | Reason:%s | Drained:%.2f | Gained:%.2f | Remaining:%s'
        ):format(
            tostring(src),
            tostring(session.netId),
            reason,
            tonumber(session.totalDrained) or 0,
            tonumber(session.totalGained) or 0,
            tostring(remainingBlood)
        ))
    end

    return true
end

local function SendStatus(session, blood)
    if not session or not IsPlayerOnline(session.source) then return end

    local status = GetStatusConfig()
    local thresholds = status.Thresholds or {}

    TriggerClientEvent('lb-vampire:client:npcFeedingStatusUpdate', session.source, {
        token = session.token,
        blood = tonumber(blood) or 0,
        maxBlood = tonumber(GetConfig().Blood and GetConfig().Blood.Max) or 100,
        lowThreshold = tonumber(thresholds.Low) or 70,
        criticalThreshold = tonumber(thresholds.Critical) or 40,
        severeThreshold = tonumber(thresholds.Severe) or 20
    })
end

local function GetAffinity(src, bloodType)
    if Config.BloodAffinity
        and Config.BloodAffinity.Enabled == true
        and LBVampire.BloodAffinity
        and LBVampire.BloodAffinity.GetMultiplierForBloodType then

        local multiplier, details = LBVampire.BloodAffinity.GetMultiplierForBloodType(src, bloodType)
        multiplier = tonumber(multiplier) or 1.0
        if multiplier <= 0 then multiplier = 1.0 end
        return multiplier, details or {}
    end

    return 1.0, { tier = 'DISABLED' }
end

function NPCFeeding.Start(src, netId)
    src = tonumber(src)
    netId = tonumber(netId)

    local config = GetConfig()
    if config.Enabled ~= true then return false, 'disabled' end
    if not src or not IsPlayerOnline(src) then return false, 'invalid_source' end
    if not netId or netId <= 0 then return false, 'invalid_net_id' end
    if not IsVampire(src) then return false, 'not_vampire' end
    if Sessions[src] then return false, 'already_feeding' end
    if ByNetId[netId] then return false, 'npc_busy' end

    local interaction = GetSharedInteraction(src)
    if interaction and interaction.state and interaction.state ~= 'IDLE' then
        return false, 'player_busy'
    end

    local entity = GetEntityFromNetId(netId, 1500)
    local valid, reason = IsValidNPC(entity)
    if not valid then return false, reason end

    local requestDistance = tonumber(config.Interaction and config.Interaction.Distance) or 2.5
    local maximumStartDistance = math.max(requestDistance + 0.75, requestDistance)

    if not IsWithinDistance(src, entity, maximumStartDistance) then
        return false, 'too_far'
    end

    if not LBVampire.NPCBlood or not LBVampire.NPCBlood.GetOrCreate then
        return false, 'npc_blood_unavailable'
    end

    local bloodState, bloodReason = LBVampire.NPCBlood.GetOrCreate(netId)
    if not bloodState then return false, bloodReason or 'npc_blood_failed' end
    if bloodState.drained == true or tonumber(bloodState.blood) <= 0 then
        return false, 'npc_drained'
    end
    if bloodState.feedingToken then return false, 'npc_busy' end

    local vampireBlood = LBVampire.Blood and LBVampire.Blood.Get and LBVampire.Blood.Get(src)
    local vampireMax = tonumber(Config.Blood and Config.Blood.Max) or 100
    if vampireBlood == nil then return false, 'vampire_blood_unavailable' end
    if tonumber(vampireBlood) >= vampireMax - 0.001 then return false, 'vampire_full' end

    local token = GenerateToken(src, netId)
    local affinityMultiplier, affinityDetails = GetAffinity(src, bloodState.bloodType)

    local session = {
        source = src,
        citizenId = GetCitizenId(src),
        netId = netId,
        token = token,
        startedAtMs = GetGameTimer(),
        lastTickAtMs = GetGameTimer(),
        bloodType = bloodState.bloodType,
        affinityMultiplier = affinityMultiplier,
        affinityTier = affinityDetails.tier or 'OTHER',
        totalDrained = 0.0,
        totalGained = 0.0
    }

    local tokenSet, tokenReason = LBVampire.NPCBlood.SetFeedingToken(netId, token)
    if tokenSet ~= true then return false, tokenReason or 'npc_token_failed' end

    Sessions[src] = session
    ByNetId[netId] = src
    SetSharedInteraction(src, 'NPC_FEEDING', token)

    TriggerClientEvent('lb-vampire:client:npcFeedingStarted', src, {
        token = token,
        netId = netId,
        blood = bloodState.blood,
        maxBlood = bloodState.maxBlood,
        bloodType = bloodState.bloodType
    })

    SendStatus(session, bloodState.blood)

    if Config.Debug then
        print((
            '^2[LB-VAMPIRE]^7 NPC feeding START | Source:%s | NetID:%s | Blood:%.2f | Type:%s | Affinity:%s x%.2f'
        ):format(
            tostring(src),
            tostring(netId),
            tonumber(bloodState.blood) or 0,
            tostring(bloodState.bloodType),
            tostring(session.affinityTier),
            tonumber(session.affinityMultiplier) or 1.0
        ))
    end

    return true, session
end

local function TickSession(session)
    if not session then return end

    local src = session.source
    if not IsPlayerOnline(src) then
        StopSession(src, 'player_left')
        return
    end

    if not IsVampire(src) then
        StopSession(src, 'not_vampire', { releaseAlive = true })
        return
    end

    local entity = GetEntityFromNetId(session.netId)
    local valid = IsValidNPC(entity)
    if not valid then
        StopSession(src, 'npc_unavailable')
        return
    end

    local maxDistance = tonumber(GetInterruptConfig().MaxDistance) or 3.5
    if not IsWithinDistance(src, entity, maxDistance) then
        StopSession(src, 'distance', { releaseAlive = true })
        return
    end

    local blood, stateOrReason = LBVampire.NPCBlood.Get(session.netId)
    if blood == nil then
        StopSession(src, stateOrReason or 'npc_blood_unavailable')
        return
    end

    if tonumber(blood) <= 0 or (stateOrReason and stateOrReason.drained == true) then
        StopSession(src, 'npc_empty', { handleDepletion = true })
        return
    end

    local vampireBlood = LBVampire.Blood.Get(src)
    local vampireMax = tonumber(Config.Blood and Config.Blood.Max) or 100
    if vampireBlood == nil then
        StopSession(src, 'vampire_blood_unavailable', { releaseAlive = true })
        return
    end

    if tonumber(vampireBlood) >= vampireMax - 0.001 then
        StopSession(src, 'vampire_full', { releaseAlive = true })
        return
    end

    local now = GetGameTimer()
    local deltaMs = now - (tonumber(session.lastTickAtMs) or now)
    if deltaMs <= 0 then return end
    session.lastTickAtMs = now

    local transfer = GetTransferConfig()
    local durationMs = math.max(tonumber(transfer.Duration) or 30000, 1000)
    local npcMax = tonumber(GetConfig().Blood and GetConfig().Blood.Max) or 100
    local requestedDrain = (npcMax / (durationMs / 1000.0)) * (deltaMs / 1000.0)

    local gainRatio = tonumber(transfer.GainRatio) or 1.0
    if gainRatio <= 0 then
        StopSession(src, 'invalid_gain_ratio', { releaseAlive = true })
        return
    end

    local affinity = tonumber(session.affinityMultiplier) or 1.0
    if affinity <= 0 then affinity = 1.0 end
    local effectiveGainRatio = gainRatio * affinity

    local vampireCapacity = vampireMax - tonumber(vampireBlood)
    local maximumNPCDrainForCapacity = vampireCapacity / effectiveGainRatio
    local amount = math.min(requestedDrain, tonumber(blood), maximumNPCDrainForCapacity)

    if amount <= 0 then
        StopSession(src, 'nothing_to_transfer', { releaseAlive = true })
        return
    end

    local removed, newNPCBlood = LBVampire.NPCBlood.Remove(session.netId, amount)
    if removed ~= true then
        StopSession(src, newNPCBlood or 'npc_transfer_failed', { releaseAlive = true })
        return
    end

    local vampireGain = amount * effectiveGainRatio
    local added, addStateOrReason = LBVampire.Blood.Add(src, vampireGain, false)

    if added ~= true then
        -- NPC 0'a ulaştıysa permanent drained olur ve geri eklenemez.
        -- Bu nedenle vampire add başarısızlığı teorik olarak yalnız normal
        -- runtime sorunlarında görülür. Session güvenli şekilde sonlandırılır.
        StopSession(src, addStateOrReason or 'vampire_transfer_failed', {
            handleDepletion = tonumber(newNPCBlood) <= 0
        })
        return
    end

    local newVampireBlood = LBVampire.Blood.Get(src)

    session.totalDrained = session.totalDrained + amount
    session.totalGained = session.totalGained + vampireGain

    SendStatus(session, newNPCBlood)

    if Config.Debug then
        print((
            '^5[LB-VAMPIRE]^7 NPC feeding tick | NetID:%s | NPC:%.2f | Vampire:%.2f | Drain:%.2f | Gain:%.2f | Affinity:%s x%.2f'
        ):format(
            tostring(session.netId),
            tonumber(newNPCBlood) or 0,
            tonumber(newVampireBlood) or 0,
            amount,
            vampireGain,
            tostring(session.affinityTier),
            affinity
        ))
    end

    if tonumber(newNPCBlood) <= 0.001 then
        StopSession(src, 'npc_empty', { handleDepletion = true })
        return
    end

    if tonumber(newVampireBlood) >= vampireMax - 0.001 then
        StopSession(src, 'vampire_full', { releaseAlive = true })
        return
    end

    if now - session.startedAtMs >= durationMs then
        StopSession(src, 'duration_complete', { releaseAlive = true })
    end
end

CreateThread(function()
    while true do
        local interval = math.max(tonumber(GetTransferConfig().TickInterval) or 500, 100)
        Wait(interval)

        if GetConfig().Enabled == true and GetTransferConfig().Enabled ~= false then
            local sources = {}
            for src in pairs(Sessions) do
                sources[#sources + 1] = src
            end

            for i = 1, #sources do
                local session = Sessions[sources[i]]
                if session then TickSession(session) end
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(60 * 1000)

        local now = GetGameTimer()
        local netIds = {}

        for netId in pairs(IncidentHistory) do
            netIds[#netIds + 1] = netId
        end

        for i = 1, #netIds do
            PruneIncidentHistory(netIds[i], now)
        end
    end
end)

RegisterNetEvent('lb-vampire:server:requestNPCFeeding', function(netId)
    local src = source

    if Config.Debug then
        print(('^5[LB-VAMPIRE]^7 NPC feeding request received | Source:%s | NetID:%s'):format(
            tostring(src), tostring(netId)
        ))
    end
    local success, reason = NPCFeeding.Start(src, netId)

    if success ~= true then
        local messages = {
            disabled = 'NPC beslenmesi şu anda kapalı.',
            not_vampire = 'Bu etkileşimi yalnız vampirken kullanabilirsin.',
            already_feeding = 'Zaten bir beslenme içindesin.',
            npc_busy = 'Bu kişiyle şu anda beslenemezsin.',
            player_busy = 'Şu anda başka bir etkileşim içindesin.',
            npc_dead = 'Ölü bir NPC ile beslenemezsin.',
            npc_drained = 'Bu NPC tamamen kansız kalmış.',
            too_far = 'NPC çok uzakta.',
            vampire_full = 'Kan rezervin zaten dolu.'
        }

        Notify(src, messages[reason] or ('NPC beslenmesi başlatılamadı: %s'):format(tostring(reason)), 'error', 4500)

        if Config.Debug then
            print(('^3[LB-VAMPIRE]^7 NPC feeding rejected | Source:%s | NetID:%s | Reason:%s'):format(
                tostring(src), tostring(netId), tostring(reason)
            ))
        end
    end
end)

RegisterNetEvent('lb-vampire:server:cancelNPCFeeding', function(reason)
    local src = source
    local session = Sessions[src]
    if not session then return end

    StopSession(src, tostring(reason or 'manual_cancel'), { releaseAlive = true })
end)

AddEventHandler('playerDropped', function()
    local src = source
    if Sessions[src] then
        StopSession(src, 'player_dropped', { releaseAlive = true })
    end
end)

exports('IsNPCFeeding', function(src)
    src = tonumber(src)
    return src and Sessions[src] ~= nil or false
end)

exports('StopNPCFeeding', function(src, reason)
    return StopSession(tonumber(src), reason or 'export_stop', { releaseAlive = true })
end)
