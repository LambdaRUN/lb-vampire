LBVampire = LBVampire or {}
LBVampire.Torpor = LBVampire.Torpor or {}

local Torpor = LBVampire.Torpor

local STAGE_NORMAL = 0
local STAGE_ACTIVE = 1
local STAGE_PARTIAL = 2

local function GetConfig()
    return Config.Torpor or {}
end

local function GetRecoveryBlood()
    return math.max(tonumber(GetConfig().RecoveryBlood) or 15, 0)
end

local function ClampStage(stage)
    stage = math.floor(tonumber(stage) or 0)
    if stage < STAGE_NORMAL then return STAGE_NORMAL end
    if stage > STAGE_PARTIAL then return STAGE_PARTIAL end
    return stage
end

local function Save(state)
    if not state then return false end
    state.dirty = true
    if LBVampire.Persistence and LBVampire.Persistence.SaveRuntimeState then
        local ok = LBVampire.Persistence.SaveRuntimeState(state)
        if ok then state.dirty = false end
        return ok
    end
    return false
end

function Torpor.Sync(source)
    source = tonumber(source)
    if not source then return end

    local state = LBVampire.Vampires.GetState(source)
    if not state then
        TriggerClientEvent('lb-vampire:client:torporSync', source, { stage = STAGE_NORMAL })
        return
    end

    TriggerClientEvent('lb-vampire:client:torporSync', source, {
        stage = ClampStage(state.torporStage),
        kinCalls = tonumber(state.kinCalls) or 0,
        maxKinCalls = tonumber((GetConfig().KinCall or {}).MaxCallsPerCollapse) or 1,
        blood = tonumber(state.blood) or 0,
        recoveryBlood = GetRecoveryBlood()
    })
end

local function SetStage(source, stage, reason)
    source = tonumber(source)
    stage = ClampStage(stage)
    if not source then return false, 'invalid_source' end
    if stage > STAGE_NORMAL and GetConfig().Enabled ~= true then return false, 'disabled' end

    local state = LBVampire.Vampires.GetState(source)
    if not state then return false, 'not_vampire' end

    local previous = ClampStage(state.torporStage)
    if previous == stage then
        Torpor.Sync(source)
        return true, state
    end

    if stage == STAGE_NORMAL then
        state.torporStage = STAGE_NORMAL
        state.collapseStartedAt = nil
        state.kinCalls = 0
    elseif stage == STAGE_ACTIVE then
        state.torporStage = STAGE_ACTIVE
        if previous == STAGE_NORMAL then
            state.collapseStartedAt = os.time()
            state.kinCalls = 0
        else
            state.collapseStartedAt = tonumber(state.collapseStartedAt) or os.time()
        end
    else
        -- PARTIAL_TORPOR keeps the same collapse identity and Kin Call usage.
        state.torporStage = STAGE_PARTIAL
        state.collapseStartedAt = tonumber(state.collapseStartedAt) or os.time()
    end

    Save(state)
    Torpor.Sync(source)

    if Config.Debug or (Config.VampireDamage and Config.VampireDamage.Debug) then
        print(('^5[LB-VAMPIRE]^7 Torpor state %d -> %d | %s | %s'):format(
            previous, stage, tostring(state.citizenId), tostring(reason or 'state_change')
        ))
    end

    return true, state
end

function Torpor.GetStage(source)
    local state = LBVampire.Vampires.GetState(source)
    return state and ClampStage(state.torporStage) or STAGE_NORMAL
end

function Torpor.EnterActive(source, reason)
    return SetStage(source, STAGE_ACTIVE, reason or 'blood_zero')
end

function Torpor.EnterPartial(source, reason)
    return SetStage(source, STAGE_PARTIAL, reason or 'revived_from_torpor')
end

function Torpor.Recover(source, reason)
    source = tonumber(source)
    if not source then return false, 'invalid_source' end

    local state = LBVampire.Vampires.GetState(source)
    if not state then return false, 'not_vampire' end
    if ClampStage(state.torporStage) == STAGE_NORMAL then return true, state end

    return SetStage(source, STAGE_NORMAL, reason or 'blood_recovered')
end

function Torpor.OnBloodChanged(source, previousBlood, newBlood)
    source = tonumber(source)
    newBlood = tonumber(newBlood) or 0
    if not source or GetConfig().Enabled ~= true then return end

    local state = LBVampire.Vampires.GetState(source)
    if not state then return end

    local stage = ClampStage(state.torporStage)
    if stage > STAGE_NORMAL and newBlood >= GetRecoveryBlood() then
        Torpor.Recover(source, 'blood_recovery')
        return
    end

    if newBlood > 0 or stage > STAGE_NORMAL then return end
    Torpor.EnterActive(source, 'blood_zero')
end

function Torpor.InitializePlayer(source)
    source = tonumber(source)
    if not source then return end

    local state = LBVampire.Vampires.GetState(source)
    if GetConfig().Enabled ~= true then
        if state and ClampStage(state.torporStage) > STAGE_NORMAL then
            SetStage(source, STAGE_NORMAL, 'torpor_disabled')
        else
            Torpor.Sync(source)
        end
        return
    end

    if not state then
        Torpor.Sync(source)
        return
    end

    state.torporStage = ClampStage(state.torporStage)
    state.kinCalls = math.max(math.floor(tonumber(state.kinCalls) or 0), 0)

    local blood = tonumber(state.blood) or 0
    if state.torporStage > STAGE_NORMAL and blood >= GetRecoveryBlood() then
        Torpor.Recover(source, 'load_recovery')
        return
    end

    if state.torporStage == STAGE_NORMAL and blood <= 0 then
        Torpor.EnterActive(source, 'load_zero_blood')
        return
    end

    Torpor.Sync(source)
end

RegisterNetEvent('lb-vampire:server:torpor:revivedFromTorpor', function()
    local src = tonumber(source)
    if not src or GetConfig().Enabled ~= true then return end

    local state = LBVampire.Vampires.GetState(src)
    if not state then return end

    local stage = ClampStage(state.torporStage)
    if stage <= STAGE_NORMAL then return end

    local blood = tonumber(state.blood) or 0
    if blood >= GetRecoveryBlood() then
        Torpor.Recover(src, 'revived_with_blood')
        return
    end

    if stage == STAGE_ACTIVE then
        Torpor.EnterPartial(src, 'revived_from_torpor')
    else
        Torpor.Sync(src)
    end
end)

RegisterNetEvent('lb-vampire:server:torpor:requestSync', function()
    Torpor.InitializePlayer(tonumber(source))
end)

RegisterNetEvent('lb-vampire:server:torpor:kinCall', function()
    local src = tonumber(source)
    local config = GetConfig().KinCall or {}
    if not src or config.Enabled ~= true then return end

    local state = LBVampire.Vampires.GetState(src)
    if not state or ClampStage(state.torporStage) <= STAGE_NORMAL then return end

    local maximum = math.max(math.floor(tonumber(config.MaxCallsPerCollapse) or 1), 1)
    state.kinCalls = tonumber(state.kinCalls) or 0
    if state.kinCalls >= maximum then
        LBVampire.Notify.Send(src, 'Kan bağını bu çöküşte zaten kullandın.', 'error', 4000)
        return
    end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    local coords = GetEntityCoords(ped)

    local offsetMin = tonumber(config.OffsetMin) or 35.0
    local offsetMax = math.max(tonumber(config.OffsetMax) or 65.0, offsetMin)
    local angle = math.random() * math.pi * 2.0
    local distance = offsetMin + (math.random() * (offsetMax - offsetMin))
    local approximate = {
        x = coords.x + math.cos(angle) * distance,
        y = coords.y + math.sin(angle) * distance,
        z = coords.z
    }

    state.kinCalls = state.kinCalls + 1
    Save(state)
    Torpor.Sync(src)

    for _, vampire in pairs(LBVampire.Runtime.Vampires or {}) do
        local target = vampire and tonumber(vampire.source)
        if target and target ~= src and GetPlayerName(target) then
            TriggerClientEvent('lb-vampire:client:torpor:kinSignal', target, {
                coords = approximate,
                radius = tonumber(config.AreaRadius) or 90.0,
                duration = tonumber(config.BlipDuration) or 75000,
                colour = tonumber(config.BlipColour) or 1,
                alpha = tonumber(config.BlipAlpha) or 105,
                label = tostring(config.Label or 'Zayıf Kan Bağı')
            })
            LBVampire.Notify.Send(target, 'Bir soydaşının yaşam gücü tükeniyor. Kan bağı yaklaşık bölgeyi işaretledi.', 'error', 6500)
        end
    end

    LBVampire.Notify.Send(src, 'Kan bağın soydaşlarına ulaştı.', 'primary', 4500)
end)

AddEventHandler('lb-vampire:server:frameworkPlayerLoaded', function(source)
    CreateThread(function()
        Wait(350)
        Torpor.InitializePlayer(source)
    end)
end)

exports('GetTorporStage', function(source)
    return Torpor.GetStage(source)
end)
