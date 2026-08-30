LBVampire = LBVampire or {}

LBVampire.ClientState =
    LBVampire.ClientState or {}

LBVampire.HUDClient =
    LBVampire.HUDClient or {}


local ClientState =
    LBVampire.ClientState

local HUD =
    LBVampire.HUDClient


---------------------------------------------------------
-- STATE
---------------------------------------------------------

HUD.Ready =
    HUD.Ready
    or false

HUD.EditorOpen =
    false

HUD.PendingBloodState =
    nil

HUD.PendingHumanBloodState =
    nil

HUD.CurrentSunState =
    'SAFE'


---------------------------------------------------------
-- Spawn bridge READY diyene kadar hiçbir gameplay HUD
-- göstermiyoruz.
---------------------------------------------------------

HUD.SuppressGameplayHUD =
    true

HUD.IdentityResolved =
    ClientState.bloodStateReceived
        == true

HUD.EditorOriginalLayout =
    nil


---------------------------------------------------------
-- KVP
---------------------------------------------------------

local KVP_KEY =
    'lb-vampire:hud-layout:v1'


---------------------------------------------------------
-- UTILS
---------------------------------------------------------

local function Clamp(
    value,
    minimum,
    maximum
)
    value =
        tonumber(value)
        or minimum


    if value < minimum then
        return minimum
    end


    if value > maximum then
        return maximum
    end


    return value
end


local function DeepCopy(
    value
)
    if type(value)
        ~= 'table' then

        return value
    end


    local copy = {}


    for key,
        item in pairs(
            value
        ) do


        copy[
            key
        ] =
            DeepCopy(
                item
            )
    end


    return copy
end


---------------------------------------------------------
-- LIMITS
---------------------------------------------------------

local function GetEditorLimits()
    local hudConfig =
        Config.HUD
        or {}


    local editor =
        hudConfig.Editor
        or hudConfig.Limits
        or {}


    return {
        minScale =
            tonumber(
                editor.MinScale
                or editor.minScale
            )
            or 0.65,

        maxScale =
            tonumber(
                editor.MaxScale
                or editor.maxScale
            )
            or 1.50,

        minOpacity =
            tonumber(
                editor.MinOpacity
                or editor.minOpacity
            )
            or 0.35,

        maxOpacity =
            tonumber(
                editor.MaxOpacity
                or editor.maxOpacity
            )
            or 1.00
    }
end


---------------------------------------------------------
-- DEFAULT LAYOUT
---------------------------------------------------------

local function BuildDefaultLayout()
    local layout =
        {}


    local elements =
        Config.HUD
        and Config.HUD.Elements
        or {}


    for elementName,
        elementConfig in pairs(
            elements
        ) do


        layout[
            elementName
        ] = {
            left =
                tonumber(
                    elementConfig.Left
                )
                or 0,

            bottom =
                tonumber(
                    elementConfig.Bottom
                )
                or 0,

            scale =
                tonumber(
                    elementConfig.Scale
                )
                or 1.0,

            opacity =
                tonumber(
                    elementConfig.Opacity
                )
                or 1.0
        }
    end


    return layout
end


HUD.DefaultLayout =
    BuildDefaultLayout()


---------------------------------------------------------
-- SANITIZE
---------------------------------------------------------

local function SanitizeElementLayout(
    incoming,
    fallback
)
    incoming =
        incoming
        or {}


    fallback =
        fallback
        or {
            left = 0,
            bottom = 0,
            scale = 1,
            opacity = 1
        }


    local limits =
        GetEditorLimits()


    return {
        left =
            Clamp(
                incoming.left
                    or fallback.left,
                0,
                100
            ),

        bottom =
            Clamp(
                incoming.bottom
                    or fallback.bottom,
                0,
                100
            ),

        scale =
            Clamp(
                incoming.scale
                    or fallback.scale,
                limits.minScale,
                limits.maxScale
            ),

        opacity =
            Clamp(
                incoming.opacity
                    or fallback.opacity,
                limits.minOpacity,
                limits.maxOpacity
            )
    }
end


---------------------------------------------------------
-- LOAD LAYOUT
---------------------------------------------------------

local function LoadLayout()
    local layout =
        DeepCopy(
            HUD.DefaultLayout
        )


    local raw =
        GetResourceKvpString(
            KVP_KEY
        )


    if not raw
        or raw == '' then

        return layout
    end


    local success,
        decoded =
        pcall(
            json.decode,
            raw
        )


    if not success
        or type(decoded)
            ~= 'table' then

        return layout
    end


    for elementName,
        defaultElement in pairs(
            HUD.DefaultLayout
        ) do


        if type(
            decoded[
                elementName
            ]
        ) == 'table' then


            layout[
                elementName
            ] =
                SanitizeElementLayout(
                    decoded[
                        elementName
                    ],
                    defaultElement
                )
        end
    end


    return layout
end


HUD.Layout =
    LoadLayout()


---------------------------------------------------------
-- SAVE
---------------------------------------------------------

local function SaveLayout()
    SetResourceKvp(
        KVP_KEY,
        json.encode(
            HUD.Layout
        )
    )
end


---------------------------------------------------------
-- GET ELEMENT LAYOUT
---------------------------------------------------------

local function GetElementLayout(
    elementName
)
    return HUD.Layout[
        elementName
    ]
        or HUD.DefaultLayout[
            elementName
        ]
end


---------------------------------------------------------
-- EDITABLE ELEMENTS
---------------------------------------------------------

local function GetEditableElements()
    local elements =
        {}


    if not Config.HUD
        or not Config.HUD.Elements then

        return elements
    end


    local isVampire =
        ClientState.isVampire
            == true


    if isVampire then

        local bloodConfig =
            Config.HUD.Elements.Blood


        if bloodConfig
            and bloodConfig.Enabled == true
            and bloodConfig.EditorVisible == true then


            elements[
                #elements + 1
            ] =
                'Blood'
        end


        local sunConfig =
            Config.HUD.Elements.Sun


        if sunConfig
            and sunConfig.Enabled == true
            and sunConfig.EditorVisible == true then


            elements[
                #elements + 1
            ] =
                'Sun'
        end


    else

        local humanConfig =
            Config.HUD.Elements.HumanBlood


        if humanConfig
            and humanConfig.Enabled == true
            and humanConfig.EditorVisible == true then


            elements[
                #elements + 1
            ] =
                'HumanBlood'
        end
    end


    return elements
end


---------------------------------------------------------
-- HIDE HELPERS
---------------------------------------------------------

local function HideBlood()
    if LBVampire.HUD
        and LBVampire.HUD.Hide then

        LBVampire.HUD.Hide()
    end
end


local function HideSun()
    if LBVampire.HUD
        and LBVampire.HUD.HideSun then

        LBVampire.HUD.HideSun()
    end
end


local function HideHumanBlood()
    if LBVampire.HUD
        and LBVampire.HUD.HideHumanBlood then

        LBVampire.HUD.HideHumanBlood()
    end
end


local function HideAll()
    HideBlood()
    HideSun()
    HideHumanBlood()
end


---------------------------------------------------------
-- BLOOD
---------------------------------------------------------

local function UpdateBlood(
    state
)
    HUD.PendingBloodState =
        state


    if HUD.Ready ~= true
        or HUD.SuppressGameplayHUD == true
        or HUD.IdentityResolved ~= true then

        HideBlood()

        return
    end


    if ClientState.isVampire
        ~= true then

        HideBlood()

        return
    end


    if not state then

        HideBlood()

        return
    end


    if LBVampire.HUD
        and LBVampire.HUD.UpdateBlood then


        LBVampire.HUD.UpdateBlood(
            state,
            GetElementLayout(
                'Blood'
            )
        )
    end
end


---------------------------------------------------------
-- SUN
---------------------------------------------------------

local function NormalizeSunState(
    state
)
    if type(state)
        == 'table' then


        state =
            state.state
            or state.sunState
    end


    state =
        string.upper(
            tostring(
                state
                or 'SAFE'
            )
        )


    if state ~= 'SAFE'
        and state ~= 'REDUCED'
        and state ~= 'DIRECT' then


        state =
            'SAFE'
    end


    return state
end


local function UpdateSun(
    state
)
    state =
        NormalizeSunState(
            state
        )


    HUD.CurrentSunState =
        state


    if HUD.Ready ~= true
        or HUD.SuppressGameplayHUD == true
        or HUD.IdentityResolved ~= true then


        HideSun()

        return
    end


    if ClientState.isVampire
        ~= true then

        HideSun()

        return
    end


    if LBVampire.HUD
        and LBVampire.HUD.UpdateSun then


        LBVampire.HUD.UpdateSun(
            state,
            GetElementLayout(
                'Sun'
            )
        )
    end
end


---------------------------------------------------------
-- HUMAN BLOOD
---------------------------------------------------------

local function UpdateHumanBlood(
    state
)
    HUD.PendingHumanBloodState =
        state


    if HUD.Ready ~= true
        or HUD.SuppressGameplayHUD == true
        or HUD.IdentityResolved ~= true then


        HideHumanBlood()

        return
    end


    -----------------------------------------------------
    -- Vampire doesn't see human blood.
    -----------------------------------------------------

    if ClientState.isVampire
        == true then


        HideHumanBlood()

        return
    end


    if not state then

        HideHumanBlood()

        return
    end


    local hudConfig =
        Config.HumanBlood
        and Config.HumanBlood.HUD
        or {}


    if hudConfig.Enabled
        ~= true then


        HideHumanBlood()

        return
    end


    local blood =
        tonumber(
            state.blood
        )
        or 100


    local maxBlood =
        tonumber(
            state.maxBlood
        )
        or 100


    local isHumanFeeding =
        ClientState.interactionState
            == 'FEEDING'
        and ClientState.feedingRole
            == 'HUMAN'


    local shouldShow =
        hudConfig.ShowAtFull == true
        or blood < maxBlood
        or (
            hudConfig.ShowWhileFeeding
                == true
            and isHumanFeeding
        )


    if not shouldShow then

        HideHumanBlood()

        return
    end


    if LBVampire.HUD
        and LBVampire.HUD.UpdateHumanBlood then


        LBVampire.HUD.UpdateHumanBlood(
            state,
            GetElementLayout(
                'HumanBlood'
            )
        )
    end
end


---------------------------------------------------------
-- REFRESH
---------------------------------------------------------

local function RefreshHUD()
    if HUD.Ready ~= true then
        return
    end


    if HUD.SuppressGameplayHUD
        == true then


        HideAll()

        return
    end


    -----------------------------------------------------
    -- Vampire/Human henüz serverdan resolve olmadıysa
    -- hiçbir şey göstermiyoruz.
    -----------------------------------------------------

    if HUD.IdentityResolved
        ~= true then


        HideAll()

        return
    end


    -----------------------------------------------------
    -- VAMPIRE
    -----------------------------------------------------

    if ClientState.isVampire
        == true then


        HideHumanBlood()


        if HUD.PendingBloodState then

            UpdateBlood(
                HUD.PendingBloodState
            )

        else

            HideBlood()
        end


        UpdateSun(
            ClientState.sunState
            or HUD.CurrentSunState
            or 'SAFE'
        )


    -----------------------------------------------------
    -- HUMAN
    -----------------------------------------------------

    else

        HideBlood()

        HideSun()


        local humanState =
            HUD.PendingHumanBloodState
            or ClientState.humanBloodState


        if humanState then

            UpdateHumanBlood(
                humanState
            )

        else

            HideHumanBlood()
        end
    end
end


---------------------------------------------------------
-- SUPPRESSION
---------------------------------------------------------

local function SetGameplayHUDSuppressed(
    suppressed,
    reason
)
    suppressed =
        suppressed == true


    HUD.SuppressGameplayHUD =
        suppressed


    if Config.Debug then

        print(
            (
                '^5[LB-VAMPIRE]^7 HUD suppression: %s | Reason: %s'
            ):format(

                tostring(
                    suppressed
                ),

                tostring(
                    reason
                )
            )
        )
    end


    if suppressed then

        -------------------------------------------------
        -- Editor açık kalmasın.
        -------------------------------------------------

        if HUD.EditorOpen then

            HUD.EditorOpen =
                false


            SetNuiFocus(
                false,
                false
            )


            if LBVampire.HUD
                and LBVampire.HUD.CloseEditor then


                LBVampire.HUD.CloseEditor()
            end
        end


        HideAll()


    else

        RefreshHUD()
    end
end


---------------------------------------------------------
-- BLOOD STATE
---------------------------------------------------------

AddEventHandler(
    'lb-vampire:client:bloodStateUpdated',
    function(state)

        -------------------------------------------------
        -- Server artık bu karakterin vampire/human
        -- durumunu cevapladı.
        -------------------------------------------------

        HUD.IdentityResolved =
            true


        HUD.PendingBloodState =
            state


        RefreshHUD()
    end
)


---------------------------------------------------------
-- HUMAN BLOOD STATE
---------------------------------------------------------

AddEventHandler(
    'lb-vampire:client:humanBloodStateUpdated',
    function(state)

        HUD.PendingHumanBloodState =
            state


        RefreshHUD()
    end
)


---------------------------------------------------------
-- SUN STATE
---------------------------------------------------------

AddEventHandler(
    'lb-vampire:client:sunStateUpdated',
    function(state)

        HUD.CurrentSunState =
            NormalizeSunState(
                state
            )


        RefreshHUD()
    end
)


---------------------------------------------------------
-- FEEDING ROLE
---------------------------------------------------------

AddEventHandler(
    'lb-vampire:client:feedingRoleUpdated',
    function()

        RefreshHUD()
    end
)


---------------------------------------------------------
-- FEEDING STATE
---------------------------------------------------------

AddEventHandler(
    'lb-vampire:client:feedingStateUpdated',
    function()

        RefreshHUD()
    end
)


---------------------------------------------------------
-- SPAWN BRIDGE: SELECTION START
---------------------------------------------------------

AddEventHandler(
    'lb-vampire:client:spawnSelectionStarted',
    function(reason)

        HUD.IdentityResolved =
            false


        HUD.PendingBloodState =
            nil


        HUD.PendingHumanBloodState =
            nil


        HUD.CurrentSunState =
            'SAFE'


        SetGameplayHUDSuppressed(
            true,
            reason
            or 'spawn_selection'
        )
    end
)


---------------------------------------------------------
-- SPAWN BRIDGE: READY
---------------------------------------------------------

AddEventHandler(
    'lb-vampire:client:spawnReady',
    function(reason)

        -------------------------------------------------
        -- Spawn ekranı sona erdi.
        --
        -- Ancak henüz vampire/human identity state'ini
        -- güvenilir kabul etmiyoruz.
        -------------------------------------------------

        SetGameplayHUDSuppressed(
            false,
            reason
            or 'spawn_ready'
        )


        -------------------------------------------------
        -- VAMPIRE / HUMAN IDENTITY REFRESH
        --
        -- blood.lua'daki server authoritative sync
        -- tekrar istenir.
        --
        -- İnsan karakterde bu cevap isVampire=false
        -- olarak gelir ve IdentityResolved=true olur.
        --
        -- Vampirde Blood state gelir ve aynı şekilde
        -- identity resolve edilir.
        -------------------------------------------------

        TriggerServerEvent(
            'lb-vampire:server:requestBloodSync'
        )


        -------------------------------------------------
        -- HUMAN BLOOD REFRESH
        -------------------------------------------------

        TriggerEvent(
            'lb-vampire:client:requestHumanBloodRefresh'
        )


        -------------------------------------------------
        -- İlk cevaplar için kısa refresh penceresi.
        -------------------------------------------------

        CreateThread(function()

            Wait(
                350
            )


            RefreshHUD()


            -------------------------------------------------
            -- İlk server request herhangi bir load race'e
            -- denk geldiyse Blood'ı bir kez daha iste.
            -------------------------------------------------

            if HUD.IdentityResolved
                ~= true then


                TriggerServerEvent(
                    'lb-vampire:server:requestBloodSync'
                )
            end


            Wait(
                750
            )


            RefreshHUD()


            -------------------------------------------------
            -- Son güvenlik retry'sı.
            -------------------------------------------------

            if HUD.IdentityResolved
                ~= true then


                TriggerServerEvent(
                    'lb-vampire:server:requestBloodSync'
                )


                TriggerEvent(
                    'lb-vampire:client:requestHumanBloodRefresh'
                )
            end


            Wait(
                1000
            )


            RefreshHUD()
        end)
    end
)


---------------------------------------------------------
-- OPEN EDITOR
---------------------------------------------------------

local function OpenEditor()
    if HUD.SuppressGameplayHUD
        == true
        or HUD.IdentityResolved
            ~= true then


        TriggerEvent(
            'QBCore:Notify',

            'Karakter yüklenmeden HUD düzenlenemez.',

            'error'
        )


        return
    end


    if HUD.EditorOpen then
        return
    end


    local editableElements =
        GetEditableElements()


    if #editableElements <= 0 then


        TriggerEvent(
            'QBCore:Notify',

            'Düzenlenebilir HUD elementi bulunamadı.',

            'error'
        )


        return
    end


    HUD.EditorOpen =
        true


    HUD.EditorOriginalLayout =
        DeepCopy(
            HUD.Layout
        )


    local limits =
        GetEditorLimits()


    SetNuiFocus(
        true,
        true
    )


    if LBVampire.HUD
        and LBVampire.HUD.OpenEditor then


        LBVampire.HUD.OpenEditor(
            HUD.Layout,
            HUD.DefaultLayout,
            editableElements,
            limits
        )


    else


        SendNUIMessage({
            action =
                'hud:editor:open',

            layout =
                HUD.Layout,

            defaults =
                HUD.DefaultLayout,

            elements =
                editableElements,

            limits =
                limits
        })
    end
end


---------------------------------------------------------
-- COMMAND
---------------------------------------------------------

RegisterCommand(
    'vamhud',
    function()

        OpenEditor()
    end,
    false
)


---------------------------------------------------------
-- NUI READY
---------------------------------------------------------

RegisterNUICallback(
    'hudReady',
    function(
        _,
        cb
    )

        HUD.Ready =
            true


        RefreshHUD()


        cb(
            'ok'
        )
    end
)


---------------------------------------------------------
-- SAVE
---------------------------------------------------------

RegisterNUICallback(
    'hudSave',
    function(
        data,
        cb
    )

        data =
            data
            or {}


        local incoming =
            data.layout
            or {}


        -------------------------------------------------
        -- Full saved layout korunuyor.
        --
        -- Human sadece HumanBlood düzenlese bile
        -- Vampire Blood/Sun KVP değerleri kaybolmaz.
        -------------------------------------------------

        local merged =
            DeepCopy(
                HUD.Layout
            )


        for elementName,
            defaultElement in pairs(
                HUD.DefaultLayout
            ) do


            if type(
                incoming[
                    elementName
                ]
            ) == 'table' then


                merged[
                    elementName
                ] =
                    SanitizeElementLayout(
                        incoming[
                            elementName
                        ],
                        defaultElement
                    )
            end
        end


        HUD.Layout =
            merged


        SaveLayout()


        HUD.EditorOriginalLayout =
            nil


        HUD.EditorOpen =
            false


        SetNuiFocus(
            false,
            false
        )


        RefreshHUD()


        cb({
            success =
                true
        })
    end
)


---------------------------------------------------------
-- CANCEL
---------------------------------------------------------

RegisterNUICallback(
    'hudCancel',
    function(
        _,
        cb
    )

        if HUD.EditorOriginalLayout then

            HUD.Layout =
                DeepCopy(
                    HUD.EditorOriginalLayout
                )
        end


        HUD.EditorOriginalLayout =
            nil


        HUD.EditorOpen =
            false


        SetNuiFocus(
            false,
            false
        )


        RefreshHUD()


        cb({
            success =
                true
        })
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


        SetNuiFocus(
            false,
            false
        )


        HideAll()
    end
)