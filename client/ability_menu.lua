LBVampire = LBVampire or {}
LBVampire.ClientState = LBVampire.ClientState or {}
LBVampire.AbilityMenu = LBVampire.AbilityMenu or {}

local Menu = LBVampire.AbilityMenu

Menu.open = false
Menu.selectedId = nil
Menu.requestId = nil
Menu.lastStates = Menu.lastStates or {}
Menu.generation = Menu.generation or 0

local function GetConfig()
    return Config.AbilityMenu or {}
end

local function GetInputConfig()
    return GetConfig().Input or {}
end

local function Notify(message, notifyType, duration)
    TriggerEvent('QBCore:Notify', message, notifyType or 'primary', duration or 3500)
end

local function SetMenuScreenBlur(enabled)
    if enabled == true then
        TriggerScreenblurFadeIn(160.0)
        return
    end

    TriggerScreenblurFadeOut(160.0)
end

local function NewRequestId()
    Menu.generation = Menu.generation + 1
    return ('ability-menu:%s:%s'):format(tostring(GetGameTimer()), tostring(Menu.generation))
end

local function GetEntries()
    if not LBVampire.Abilities or not LBVampire.Abilities.BuildMenuEntries then return {} end
    return LBVampire.Abilities.BuildMenuEntries()
end

local function GetEntryIds(entries)
    local ids = {}
    for _, entry in ipairs(entries or {}) do
        if entry.id then ids[#ids + 1] = tostring(entry.id) end
    end
    return ids
end

local function CanOpen()
    local config = GetConfig()
    if config.Enabled ~= true then return false, 'Menü devre dışı.' end
    if LBVampire.ClientState.isVampire ~= true then return false, nil end
    if Menu.open == true then return false, nil end
    if IsPauseMenuActive() then return false, nil end
    if (tonumber(LBVampire.ClientState.torporStage) or 0) > 0 then
        return false, 'Torpor sırasında vampire ability kullanamazsın.'
    end

    local playerPed = PlayerPedId()
    if not playerPed or playerPed == 0 or IsEntityDead(playerPed) then
        return false, nil
    end

    if (LBVampire.ClientState.interactionState or 'IDLE') ~= 'IDLE' then
        return false, 'Başka bir etkileşim sürerken ability menüsü açılamaz.'
    end

    return true
end

local function SendOpen(entries)
    local input = GetInputConfig()
    SendNUIMessage({
        action = 'ability:open',
        entries = entries,
        states = Menu.lastStates,
        currentBlood = tonumber(LBVampire.ClientState.blood) or 0,
        maxBlood = tonumber(LBVampire.ClientState.maxBlood) or tonumber(Config.Blood and Config.Blood.Max) or 100,
        layout = {
            deadzone = tonumber(input.Deadzone) or 70,
            cursorRadius = tonumber(input.CursorRadius) or 260,
            minimumSlots = math.floor(tonumber(input.MinimumSlots) or 6),
            maxSlots = math.floor(tonumber(input.MaxSlots) or 10)
        }
    })
end

local function OpenMenu()
    local allowed, reason = CanOpen()
    if not allowed then
        if reason then Notify(reason, 'error') end
        return false
    end

    local entries = GetEntries()
    if #entries == 0 then return false end

    Menu.open = true
    Menu.selectedId = nil
    Menu.requestId = NewRequestId()
    LBVampire.ClientState.abilityMenuOpen = true

    SetMenuScreenBlur(true)
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true)
    SetCursorLocation(0.5, 0.5)
    SendOpen(entries)

    TriggerServerEvent(
        'lb-vampire:server:abilityMenu:requestStates',
        Menu.requestId,
        GetEntryIds(entries)
    )

    return true
end

local function ReleaseFocus()
    SetNuiFocusKeepInput(false)
    SetNuiFocus(false, false)
end

local function CloseMenu(activate)
    if Menu.open ~= true then return end

    local selectedId = Menu.selectedId
    local selectedState = selectedId and Menu.lastStates[selectedId] or nil

    Menu.open = false
    Menu.selectedId = nil
    Menu.requestId = nil
    LBVampire.ClientState.abilityMenuOpen = false

    SendNUIMessage({ action = 'ability:close' })
    ReleaseFocus()
    SetMenuScreenBlur(false)

    if activate ~= true or not selectedId then return end

    if selectedState and selectedState.available == false then
        Notify(tostring(selectedState.reason or 'Bu ability şu anda kullanılamaz.'), 'error')
        return
    end

    if not LBVampire.Abilities or not LBVampire.Abilities.Execute then return end

    local ok, reason = LBVampire.Abilities.Execute(selectedId)
    if ok ~= true and reason == 'missing_client_provider' then
        Notify('Bu ability henüz kullanıma açık değil.', 'error')
    end
end

RegisterCommand('+lbvampire_ability_menu', function()
    OpenMenu()
end, false)

RegisterCommand('-lbvampire_ability_menu', function()
    CloseMenu(true)
end, false)

RegisterKeyMapping(
    '+lbvampire_ability_menu',
    tostring(GetConfig().KeyDescription or 'LB Vampire - Ability Menu'),
    'keyboard',
    tostring(GetConfig().DefaultKey or 'LMENU')
)

RegisterNUICallback('ability:hover', function(data, cb)
    if Menu.open ~= true then
        cb({ ok = false })
        return
    end

    local id = data and data.id and tostring(data.id) or nil
    if id == '' then id = nil end
    Menu.selectedId = id
    cb({ ok = true })
end)

RegisterNUICallback('ability:cancel', function(_, cb)
    CloseMenu(false)
    cb({ ok = true })
end)

RegisterNetEvent('lb-vampire:client:abilityMenu:states', function(data)
    data = data or {}
    if Menu.open ~= true then return end
    if tostring(data.requestId or '') ~= tostring(Menu.requestId or '') then return end
    if type(data.states) ~= 'table' then return end

    Menu.lastStates = data.states

    SendNUIMessage({
        action = 'ability:states',
        states = Menu.lastStates,
        currentBlood = tonumber(LBVampire.ClientState.blood) or 0,
        maxBlood = tonumber(LBVampire.ClientState.maxBlood) or tonumber(Config.Blood and Config.Blood.Max) or 100
    })
end)

CreateThread(function()
    while true do
        if Menu.open == true then
            local ped = PlayerPedId()
            DisablePlayerFiring(PlayerId(), true)
            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 37, true)
            DisableControlAction(0, 44, true)
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)

            if not ped or ped == 0 or IsEntityDead(ped) or LBVampire.ClientState.isVampire ~= true then
                CloseMenu(false)
            end

            Wait(0)
        else
            Wait(250)
        end
    end
end)

RegisterNetEvent('lb-vampire:client:abilityMenu:forceClose', function()
    if Menu.open then CloseMenu(false) end
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    if Menu.open then CloseMenu(false) end
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if Menu.open then
        Menu.open = false
        SendNUIMessage({ action = 'ability:close' })
        ReleaseFocus()
        SetMenuScreenBlur(false)
    end
end)

exports('OpenAbilityMenu', function()
    return OpenMenu()
end)
