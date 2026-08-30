LBVampire = LBVampire or {}

-- Kritik:
-- HUD namespace'i bridge yüklenirken garanti oluşturulmalı.
LBVampire.HUD = LBVampire.HUD or {}


---------------------------------------------------------
-- BLOOD
---------------------------------------------------------

function LBVampire.HUD.UpdateBlood(
    state,
    layout
)
    if not state then
        return
    end

    if not Config.HUD
        or Config.HUD.Enabled ~= true then

        return
    end

    if not Config.HUD.Elements
        or not Config.HUD.Elements.Blood
        or Config.HUD.Elements.Blood.Enabled ~= true then

        return
    end


    local maxBlood =
        tonumber(
            state.maxBlood
        )
        or (
            Config.Blood
            and tonumber(
                Config.Blood.Max
            )
        )
        or 100


    local lowThreshold =
        (
            Config.Blood
            and Config.Blood.Thresholds
            and tonumber(
                Config.Blood.Thresholds.Low
            )
        )
        or 25


    local criticalThreshold =
        (
            Config.Blood
            and Config.Blood.Thresholds
            and tonumber(
                Config.Blood.Thresholds.Critical
            )
        )
        or 10


    SendNUIMessage({
        action =
            'blood:update',

        visible =
            true,

        blood =
            tonumber(
                state.blood
            )
            or 0,

        maxBlood =
            maxBlood,

        lowThreshold =
            lowThreshold,

        criticalThreshold =
            criticalThreshold,

        layout =
            layout
    })
end


function LBVampire.HUD.Hide()
    SendNUIMessage({
        action =
            'blood:hide'
    })
end


---------------------------------------------------------
-- SUN
---------------------------------------------------------

function LBVampire.HUD.UpdateSun(
    state,
    layout
)
    if not Config.HUD
        or Config.HUD.Enabled ~= true then

        return
    end

    if not Config.HUD.Elements
        or not Config.HUD.Elements.Sun
        or Config.HUD.Elements.Sun.Enabled ~= true then

        return
    end


    state =
        string.upper(
            tostring(
                state or 'SAFE'
            )
        )


    if state ~= 'SAFE'
        and state ~= 'REDUCED'
        and state ~= 'DIRECT' then

        state =
            'SAFE'
    end


    SendNUIMessage({
        action =
            'sun:update',

        state =
            state,

        layout =
            layout
    })
end


function LBVampire.HUD.HideSun()
    SendNUIMessage({
        action =
            'sun:hide'
    })
end

---------------------------------------------------------
-- HUMAN BLOOD
---------------------------------------------------------

function LBVampire.HUD.UpdateHumanBlood(
    state,
    layout
)
    if not state then
        return
    end

    if not Config.HUD
        or Config.HUD.Enabled ~= true then

        return
    end

    if not Config.HUD.Elements
        or not Config.HUD.Elements.HumanBlood
        or Config.HUD.Elements.HumanBlood.Enabled
            ~= true then

        return
    end


    SendNUIMessage({
        action =
            'humanblood:update',

        visible =
            true,

        blood =
            tonumber(
                state.blood
            )
            or 100,

        maxBlood =
            tonumber(
                state.maxBlood
            )
            or 100,

        lowThreshold =
            tonumber(
                state.lowThreshold
            )
            or 70,

        criticalThreshold =
            tonumber(
                state.criticalThreshold
            )
            or 40,

        severeThreshold =
            tonumber(
                state.severeThreshold
            )
            or 20,

        layout =
            layout
    })
end


function LBVampire.HUD.HideHumanBlood()
    SendNUIMessage({
        action =
            'humanblood:hide'
    })
end


---------------------------------------------------------
-- EDITOR
---------------------------------------------------------

function LBVampire.HUD.OpenEditor(
    layout,
    defaults,
    elements,
    limits
)
    SendNUIMessage({
        action =
            'hud:editor:open',

        layout =
            layout or {},

        defaults =
            defaults or {},

        elements =
            elements or {},

        limits =
            limits or {}
    })
end


function LBVampire.HUD.CloseEditor()
    SendNUIMessage({
        action =
            'hud:editor:close'
    })
end