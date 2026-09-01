LBVampire = LBVampire or {}

LBVampire.Items =
    LBVampire.Items or {}

LBVampire.BloodBags =
    LBVampire.BloodBags or {}


local BloodBags =
    LBVampire.BloodBags


---------------------------------------------------------
-- QBCORE
---------------------------------------------------------

local QBCore =
    exports['qb-core']
        :GetCoreObject()


---------------------------------------------------------
-- CONFIG
---------------------------------------------------------

local function GetConfig()
    return Config.Items
        and Config.Items.BloodBag
        or {}
end


---------------------------------------------------------
-- NOTIFY
---------------------------------------------------------

local function Notify(
    source,
    message,
    notifyType,
    duration
)
    TriggerClientEvent(
        'QBCore:Notify',

        source,

        message,

        notifyType
            or 'primary',

        duration
            or 5000
    )
end


---------------------------------------------------------
-- PLAYER
---------------------------------------------------------

local function GetPlayer(
    source
)
    source =
        tonumber(source)


    if not source then
        return nil
    end


    return QBCore.Functions.GetPlayer(
        source
    )
end


---------------------------------------------------------
-- INVENTORY PERSISTENCE
---------------------------------------------------------

local function SaveInventoryNow(
    source
)
    source =
        tonumber(source)


    if not source then
        return false
    end


    if GetResourceState(
        'qb-inventory'
    ) ~= 'started' then

        return false
    end


    local success,
        result =
        pcall(
            function()

                return exports[
                    'qb-inventory'
                ]:SaveInventory(
                    source
                )
            end
        )


    if not success then

        if Config.Debug then

            print(
                (
                    '^1[LB-VAMPIRE]^7 Inventory save failed | Source: %s | Error: %s'
                ):format(
                    tostring(source),
                    tostring(result)
                )
            )
        end


        return false
    end


    return true
end

---------------------------------------------------------
-- BLOOD TYPE
---------------------------------------------------------

local function NormalizeBloodType(
    bloodType
)
    if bloodType == nil then
        return nil
    end


    bloodType =
        string.upper(
            tostring(
                bloodType
            )
        )


    bloodType =
        bloodType:gsub(
            '%s+',
            ''
        )


    if bloodType == '' then
        return nil
    end


    return bloodType
end


local function IsValidBloodType(
    bloodType
)
    bloodType =
        NormalizeBloodType(
            bloodType
        )


    if not bloodType then
        return false
    end


    local types =
        Config.BloodAffinity
        and Config.BloodAffinity.BloodTypes
        or {
            'O+',
            'O-',
            'A+',
            'A-',
            'B+',
            'B-',
            'AB+',
            'AB-'
        }


    for i = 1,
        #types do


        if NormalizeBloodType(
            types[i]
        ) == bloodType then


            return true
        end
    end


    return false
end


---------------------------------------------------------
-- PLAYER BLOOD TYPE
---------------------------------------------------------

local function GetPlayerBloodType(
    source
)
    -----------------------------------------------------
    -- BloodAffinity bridge.
    -----------------------------------------------------

    if LBVampire.BloodAffinity
        and LBVampire.BloodAffinity.GetHumanBloodType then


        local bloodType =
            LBVampire.BloodAffinity
                .GetHumanBloodType(
                    source
                )


        if IsValidBloodType(
            bloodType
        ) then


            return NormalizeBloodType(
                bloodType
            )
        end
    end


    -----------------------------------------------------
    -- Stock QB fallback.
    -----------------------------------------------------

    local Player =
        GetPlayer(
            source
        )


    if not Player
        or not Player.PlayerData then

        return nil
    end


    local metadata =
        Player.PlayerData.metadata
        or {}


    local bloodType =
        NormalizeBloodType(
            metadata.bloodtype
        )


    if not IsValidBloodType(
        bloodType
    ) then

        return nil
    end


    return bloodType
end


---------------------------------------------------------
-- VAMPIRE STATE
---------------------------------------------------------

local function GetVampireState(
    source
)
    if not LBVampire.Vampires
        or not LBVampire.Vampires.GetState then

        return nil
    end


    return LBVampire.Vampires.GetState(
        source
    )
end


---------------------------------------------------------
-- DISTANCE
---------------------------------------------------------

local function DistanceBetweenPlayers(
    firstSource,
    secondSource
)
    if firstSource ==
        secondSource then

        return 0.0
    end


    local firstPed =
        GetPlayerPed(
            firstSource
        )


    local secondPed =
        GetPlayerPed(
            secondSource
        )


    if not firstPed
        or firstPed == 0
        or not secondPed
        or secondPed == 0 then

        return nil
    end


    local firstCoords =
        GetEntityCoords(
            firstPed
        )


    local secondCoords =
        GetEntityCoords(
            secondPed
        )


    local dx =
        firstCoords.x -
        secondCoords.x


    local dy =
        firstCoords.y -
        secondCoords.y


    local dz =
        firstCoords.z -
        secondCoords.z


    return math.sqrt(
        dx * dx
        +
        dy * dy
        +
        dz * dz
    )
end

---------------------------------------------------------
-- BLOOD BAG DISPLAY
---------------------------------------------------------

local function FormatBagDate(
    timestamp
)
    timestamp =
        tonumber(timestamp)


    if not timestamp then
        return 'Bilinmiyor'
    end


    return os.date(
        '%d.%m.%Y %H:%M',
        timestamp
    )
end


local function BuildBagDescription(
    bloodType,
    bloodAmount,
    collectedAt,
    expiresAt
)
    local maximum =
        tonumber(
            GetConfig().MaxAmount
        )
        or 35


    return (
        'Kan Grubu: %s\n'
        ..
        'Kan Miktarı: %.1f / %.1f\n'
        ..
        'Toplanma Tarihi: %s\n'
        ..
        'Son Kullanma Tarihi: %s'
    ):format(

        tostring(
            bloodType
            or 'Bilinmiyor'
        ),

        tonumber(
            bloodAmount
        )
        or 0,

        maximum,

        FormatBagDate(
            collectedAt
        ),

        FormatBagDate(
            expiresAt
        )
    )
end

---------------------------------------------------------
-- BAG INFO CREATION
---------------------------------------------------------

local function CreateBagInfo(
    bloodType,
    bloodAmount,
    options
)
    options =
        options or {}


    bloodType =
        NormalizeBloodType(
            bloodType
        )


    bloodAmount =
        tonumber(
            bloodAmount
        )


    if not IsValidBloodType(
        bloodType
    ) then

        return nil,
            'invalid_blood_type'
    end


    if not bloodAmount
        or bloodAmount <= 0 then

        return nil,
            'invalid_blood_amount'
    end


    local config =
        GetConfig()


    local maximum =
        tonumber(
            config.MaxAmount
        )
        or 35


    if bloodAmount >
        maximum then

        return nil,
            'blood_amount_too_large'
    end


    local now =
        os.time()


    local collectedAt =
        tonumber(
            options.collectedAt
        )
        or now


    local expiresAt =
        tonumber(
            options.expiresAt
        )
        or (
            collectedAt
            +
            (
                tonumber(
                    config.ShelfLife
                )
                or (
                    7
                    *
                    24
                    *
                    60
                    *
                    60
                )
            )
        )


    return {
        -------------------------------------------------
        -- Metadata schema.
        -------------------------------------------------

        schemaVersion =
            1,


        bloodType =
            bloodType,


        bloodAmount =
            bloodAmount,


        collectedAt =
            collectedAt,


        expiresAt =
            expiresAt,


        donorCitizenId =
            options.donorCitizenId,

        description =
            BuildBagDescription(
                bloodType,
                bloodAmount,
                collectedAt,
                expiresAt
            ),
        -------------------------------------------------
        -- Raw metadata'yı stock inventory tooltipinde
        -- göstermiyoruz.
        -------------------------------------------------

        display =
            false
    }
end


---------------------------------------------------------
-- PARSE EXISTING BAG
---------------------------------------------------------

local function ParseBag(
    item
)
    if not item then

        return nil,
            'item_missing'
    end


    local info =
        item.info


    if type(info) ~= 'table' then

        return nil,
            'metadata_missing'
    end


    local bloodType =
        NormalizeBloodType(
            info.bloodType
        )


    -----------------------------------------------------
    -- Eski development örnekleriyle ufak backward
    -- compatibility.
    -----------------------------------------------------

    local bloodAmount =
        tonumber(
            info.bloodAmount
            or info.amount
        )


    local collectedAt =
        tonumber(
            info.collectedAt
        )


    local expiresAt =
        tonumber(
            info.expiresAt
        )


    if not IsValidBloodType(
        bloodType
    ) then

        return nil,
            'invalid_blood_type'
    end


    if not bloodAmount
        or bloodAmount <= 0 then

        return nil,
            'empty_bag'
    end


    if not expiresAt then

        return nil,
            'expiry_missing'
    end


    return {
        bloodType =
            bloodType,

        bloodAmount =
            bloodAmount,

        collectedAt =
            collectedAt,

        expiresAt =
            expiresAt,

        donorCitizenId =
            info.donorCitizenId,

        rawInfo =
            info
    }
end


---------------------------------------------------------
-- GET ITEM BY SLOT
---------------------------------------------------------

local function GetBagItem(
    source,
    slot
)
    local Player =
        GetPlayer(
            source
        )


    if not Player
        or not Player.PlayerData then

        return nil,
            'player_not_found'
    end


    slot =
        tonumber(slot)


    if not slot then

        return nil,
            'invalid_slot'
    end


    local item =
        Player.PlayerData.items
        and Player.PlayerData.items[
            slot
        ]


    if not item then

        return nil,
            'item_not_found'
    end


    local config =
        GetConfig()


    local expectedName =
        tostring(
            config.Name
            or 'lb_bloodbag'
        )


    if string.lower(
        tostring(
            item.name
            or ''
        )
    ) ~= string.lower(
        expectedName
    ) then


        return nil,
            'wrong_item'
    end


    return item
end


---------------------------------------------------------
-- CREATE BLOOD BAG
---------------------------------------------------------

function BloodBags.Create(
    holderSource,
    bloodType,
    bloodAmount,
    options
)
    holderSource =
        tonumber(
            holderSource
        )


    if not holderSource then

        return false,
            'invalid_holder'
    end


    local Player =
        GetPlayer(
            holderSource
        )


    if not Player then

        return false,
            'holder_not_found'
    end


    local config =
        GetConfig()


    if config.Enabled ~= true then

        return false,
            'bloodbag_disabled'
    end


    local info,
        reason =
        CreateBagInfo(
            bloodType,
            bloodAmount,
            options
        )


    if not info then

        return false,
            reason
    end


    local itemName =
        tostring(
            config.Name
            or 'lb_bloodbag'
        )


    -----------------------------------------------------
    -- unique=true olduğu için her çağrı ayrı slot/item.
    -----------------------------------------------------

    local added =
        exports['qb-inventory']:AddItem(

            holderSource,

            itemName,

            1,

            false,

            info,

            'lb-vampire:create-blood-bag'
        )


    if not added then

        return false,
            'inventory_add_failed'
    end

    -----------------------------------------------------
    -- Persist immediately.
    -----------------------------------------------------

    SaveInventoryNow(
        holderSource
    )

    if Config.Debug then

        print(
            (
                '^2[LB-VAMPIRE]^7 Blood bag created | Holder: %s | Type: %s | Amount: %.2f'
            ):format(

                tostring(
                    holderSource
                ),

                info.bloodType,

                info.bloodAmount
            )
        )
    end


    return true,
        info
end


---------------------------------------------------------
-- CREATE FROM DONOR
---------------------------------------------------------

function BloodBags.CreateFromDonor(
    holderSource,
    donorSource,
    bloodAmount
)
    holderSource =
        tonumber(
            holderSource
        )


    donorSource =
        tonumber(
            donorSource
        )


    if not holderSource
        or not donorSource then

        return false,
            'invalid_player'
    end


    local donor =
        GetPlayer(
            donorSource
        )


    if not donor
        or not donor.PlayerData then

        return false,
            'donor_not_found'
    end


    local bloodType =
        GetPlayerBloodType(
            donorSource
        )


    if not bloodType then

        return false,
            'donor_blood_type_unknown'
    end


    local donorCitizenId =
        donor.PlayerData.citizenid


    return BloodBags.Create(
        holderSource,

        bloodType,

        bloodAmount,

        {
            donorCitizenId =
                donorCitizenId
        }
    )
end


---------------------------------------------------------
-- UPDATE / CONSUME BAG
---------------------------------------------------------

local function ConsumeBagBlood(
    holderSource,
    item,
    amount
)
    amount =
        tonumber(
            amount
        )


    if not amount
        or amount <= 0 then

        return false,
            'invalid_consume_amount'
    end


    local bag,
        reason =
        ParseBag(
            item
        )


    if not bag then

        return false,
            reason
    end


    local remaining =
        bag.bloodAmount
        -
        amount


    local itemName =
        tostring(
            GetConfig().Name
            or 'lb_bloodbag'
        )


    -----------------------------------------------------
    -- EMPTY → REMOVE ITEM
    -----------------------------------------------------

    if remaining <=
        0.001 then


        local removed =
            exports['qb-inventory']
                :RemoveItem(

                    holderSource,

                    itemName,

                    1,

                    item.slot,

                    'lb-vampire:blood-bag-empty'
                )


        if not removed then

            return false,
                'item_remove_failed'
        end

        SaveInventoryNow(
            holderSource
        )

        return true,
            0.0
    end


    -----------------------------------------------------
    -- PARTIAL BAG
    -----------------------------------------------------

    local newInfo =
        bag.rawInfo


    newInfo.schemaVersion =
        1


    newInfo.bloodType =
        bag.bloodType


    newInfo.bloodAmount =
        remaining

    newInfo.description =
        BuildBagDescription(
            bag.bloodType,
            remaining,
            bag.collectedAt,
            bag.expiresAt
        )
    -----------------------------------------------------
    -- Eski development alanı varsa temizle.
    -----------------------------------------------------

    newInfo.amount =
        nil


    newInfo.display =
        false


    local updated =
        exports['qb-inventory']
            :SetItemData(

                holderSource,

                itemName,

                'info',

                newInfo,

                item.slot
            )


    if updated ~= true then

        return false,
            'metadata_update_failed'
    end

    SaveInventoryNow(
        holderSource
    )

    return true,
        remaining
end


---------------------------------------------------------
-- HUMAN COMPATIBILITY
---------------------------------------------------------

local function IsHumanCompatible(
    targetSource,
    bagBloodType
)
    local mode =
        string.lower(
            tostring(
                GetConfig()
                    .HumanCompatibilityMode
                or 'exact'
            )
        )


    if mode == 'off'
        or mode == 'disabled' then

        return true
    end


    local targetBloodType =
        GetPlayerBloodType(
            targetSource
        )


    if not targetBloodType then

        return false,
            'target_blood_type_unknown'
    end


    -----------------------------------------------------
    -- Phase 4:
    -- exact match only.
    -----------------------------------------------------

    if mode == 'exact' then

        if targetBloodType ~=
            bagBloodType then


            return false,
                'blood_type_incompatible'
        end


        return true
    end


    -----------------------------------------------------
    -- Unknown future mode = fail safe.
    -----------------------------------------------------

    return false,
        'unsupported_compatibility_mode'
end


---------------------------------------------------------
-- APPLY TO HUMAN
---------------------------------------------------------

local function ApplyToHuman(
    holderSource,
    targetSource,
    item,
    bag
)
    local config =
        GetConfig()


    if config.HumanUse ~= true then

        return false,
            'human_use_disabled'
    end


    local compatible,
        reason =
        IsHumanCompatible(
            targetSource,
            bag.bloodType
        )


    if not compatible then

        return false,
            reason
    end


    if not LBVampire.HumanBlood
        or not LBVampire.HumanBlood.Get
        or not LBVampire.HumanBlood.Add then

        return false,
            'humanblood_unavailable'
    end


    local current =
        LBVampire.HumanBlood.Get(
            targetSource
        )


    if current == nil then

        return false,
            'humanblood_unavailable'
    end


    current =
        tonumber(current)
        or 100


    local maximum =
        tonumber(
            Config.HumanBlood
            and Config.HumanBlood.Max
        )
        or 100


    if current >= maximum then

        return false,
            'human_blood_full'
    end


    local capacity =
        maximum -
        current


    local consumed =
        math.min(
            bag.bloodAmount,
            capacity
        )


    if consumed <= 0 then

        return false,
            'nothing_to_restore'
    end


    local added,
        newBlood =
        LBVampire.HumanBlood.Add(

            targetSource,

            consumed,

            true
        )


    if not added then

        return false,
            'human_restore_failed'
    end


    local consumedSuccess,
        remaining =
        ConsumeBagBlood(
            holderSource,
            item,
            consumed
        )


    if not consumedSuccess then

        -------------------------------------------------
        -- HumanBlood değişti ama inventory update
        -- başarısız oldu.
        --
        -- Rollback.
        -------------------------------------------------

        LBVampire.HumanBlood.Remove(
            targetSource,
            consumed,
            true
        )


        return false,
            remaining
    end


    return true,
        {
            targetType =
                'HUMAN',

            bloodType =
                bag.bloodType,

            consumed =
                consumed,

            gained =
                consumed,

            remaining =
                remaining,

            newBlood =
                newBlood
        }
end


---------------------------------------------------------
-- APPLY TO VAMPIRE
---------------------------------------------------------

local function ApplyToVampire(
    holderSource,
    targetSource,
    item,
    bag,
    vampireState
)
    local config =
        GetConfig()


    if config.VampireUse ~= true then

        return false,
            'vampire_use_disabled'
    end


    if not LBVampire.Blood
        or not LBVampire.Blood.Add then

        return false,
            'blood_system_unavailable'
    end


    local current =
        tonumber(
            vampireState.blood
        )
        or 0


    local maximum =
        tonumber(
            Config.Blood
            and Config.Blood.Max
        )
        or 100


    if current >= maximum then

        return false,
            'vampire_blood_full'
    end


    -----------------------------------------------------
    -- BLOOD TYPE AFFINITY
    -----------------------------------------------------

    local affinityMultiplier =
        1.0


    local affinityDetails =
        {
            tier =
                'OTHER'
        }


    if LBVampire.BloodAffinity
        and LBVampire.BloodAffinity
            .GetMultiplierForBloodType then


        affinityMultiplier,
            affinityDetails =
            LBVampire.BloodAffinity
                .GetMultiplierForBloodType(

                    targetSource,

                    bag.bloodType
                )
    end


    affinityMultiplier =
        tonumber(
            affinityMultiplier
        )
        or 1.0


    if affinityMultiplier <= 0 then
        affinityMultiplier = 1.0
    end


    affinityDetails =
        affinityDetails
        or {}


    -----------------------------------------------------
    -- CAPACITY
    -----------------------------------------------------

    local capacity =
        maximum -
        current


    -----------------------------------------------------
    -- Bag amount × affinity = Blood gain.
    --
    -- Vampire'ın yalnızca 5 Blood kapasitesi varsa ve
    -- affinity x1.20 ise:
    --
    -- 5 / 1.20 = 4.166 bag blood yeterlidir.
    -----------------------------------------------------

    local maximumBagConsumption =
        capacity /
        affinityMultiplier


    local consumed =
        math.min(

            bag.bloodAmount,

            maximumBagConsumption
        )


    if consumed <= 0 then

        return false,
            'nothing_to_restore'
    end


    local gain =
        consumed
        *
        affinityMultiplier


    local added,
        newBlood =
        LBVampire.Blood.Add(

            targetSource,

            gain,

            true
        )


    if not added then

        return false,
            'vampire_restore_failed'
    end


    -----------------------------------------------------
    -- BAG CONSUMPTION
    -----------------------------------------------------

    local consumedSuccess,
        remaining =
        ConsumeBagBlood(

            holderSource,

            item,

            consumed
        )


    if not consumedSuccess then

        -------------------------------------------------
        -- Inventory update failed.
        -- Vampire Blood rollback.
        -------------------------------------------------

        LBVampire.Blood.Remove(
            targetSource,
            gain,
            true
        )


        return false,
            remaining
    end


    -----------------------------------------------------
    -- EXACT AFFINITY
    -----------------------------------------------------

    if affinityDetails.tier ==
        'EXACT'
        and Config.BloodAffinity
        and Config.BloodAffinity.NotifyExactMatch
            == true then


        Notify(
            targetSource,

            'Bu kan sende alışılmadık derecede güçlü bir etki bırakıyor.',

            'success',

            6500
        )
    end


    return true,
        {
            targetType =
                'VAMPIRE',

            bloodType =
                bag.bloodType,

            consumed =
                consumed,

            gained =
                gain,

            remaining =
                remaining,

            newBlood =
                newBlood,

            affinity =
                affinityMultiplier,

            affinityTier =
                tostring(
                    affinityDetails.tier
                    or 'OTHER'
                )
        }
end


---------------------------------------------------------
-- ADMINISTER BAG
---------------------------------------------------------

function BloodBags.Administer(
    holderSource,
    targetSource,
    slot
)
    holderSource =
        tonumber(
            holderSource
        )


    targetSource =
        tonumber(
            targetSource
        )


    slot =
        tonumber(
            slot
        )


    if not holderSource
        or not targetSource
        or not slot then

        return false,
            'invalid_arguments'
    end


    local holder =
        GetPlayer(
            holderSource
        )


    local target =
        GetPlayer(
            targetSource
        )


    if not holder
        or not target then

        return false,
            'player_not_found'
    end


    local config =
        GetConfig()


    if config.Enabled ~= true then

        return false,
            'bloodbag_disabled'
    end


    -----------------------------------------------------
    -- SERVER DISTANCE
    -----------------------------------------------------

    if holderSource ~=
        targetSource then


        local distance =
            DistanceBetweenPlayers(
                holderSource,
                targetSource
            )


        if not distance then

            return false,
                'distance_unavailable'
        end


        local maximumDistance =
            tonumber(
                config.AdministrationDistance
            )
            or 3.0


        if distance >
            maximumDistance then


            return false,
                'too_far'
        end
    end


    -----------------------------------------------------
    -- ITEM
    -----------------------------------------------------

    local item,
        itemReason =
        GetBagItem(
            holderSource,
            slot
        )


    if not item then

        return false,
            itemReason
    end


    -----------------------------------------------------
    -- METADATA
    -----------------------------------------------------

    local bag,
        bagReason =
        ParseBag(
            item
        )


    if not bag then

        return false,
            bagReason
    end


    -----------------------------------------------------
    -- EXPIRY
    -----------------------------------------------------

    if bag.expiresAt <=
        os.time() then


        return false,
            'blood_bag_expired'
    end


    -----------------------------------------------------
    -- VAMPIRE / HUMAN
    -----------------------------------------------------

    local vampireState =
        GetVampireState(
            targetSource
        )


    if vampireState then

        return ApplyToVampire(

            holderSource,

            targetSource,

            item,

            bag,

            vampireState
        )
    end


    return ApplyToHuman(

        holderSource,

        targetSource,

        item,

        bag
    )
end


---------------------------------------------------------
-- USABLE ITEM
---------------------------------------------------------

BloodBags.UseSessions = BloodBags.UseSessions or {}

local function GetBloodBagUseConfig()
    local config = GetConfig()
    return config.Use or {}
end

local function BloodBagUseMessage(reason)
    local messages = {
        metadata_missing = 'Bu kan torbasında geçerli kan verisi bulunmuyor.',
        invalid_blood_type = 'Kan torbasının kan grubu geçersiz.',
        empty_bag = 'Kan torbası boş.',
        expiry_missing = 'Kan torbasının son kullanma bilgisi bulunmuyor.',
        blood_bag_expired = 'Kan torbasının son kullanma tarihi geçmiş.',
        human_blood_full = 'Kan rezervin zaten normal seviyede.',
        vampire_blood_full = 'Kan rezervin zaten dolu.',
        target_blood_type_unknown = 'Kan grubun belirlenemedi.',
        blood_type_incompatible = 'Bu kan torbasının kan grubu seninle uyumlu değil.',
        item_not_found = 'Kan torbası artık üzerinde bulunmuyor.',
        invalid_use_session = 'Kan torbası kullanım oturumu geçersiz.',
        use_too_early = 'Kan torbası kullanımı tamamlanmadı.'
    }

    return messages[reason] or ('Kan torbası kullanılamadı: ' .. tostring(reason))
end

local function NotifyBloodBagResult(source, result)
    if result.targetType == 'VAMPIRE' then
        Notify(
            source,
            ('%s kan torbasından %.1f Blood kazandın.'):format(
                result.bloodType,
                tonumber(result.gained) or 0
            ),
            'success',
            5000
        )
    else
        Notify(
            source,
            ('%s kan torbası uygulandı. Kan rezervin %.1f arttı.'):format(
                result.bloodType,
                tonumber(result.gained) or 0
            ),
            'success',
            5000
        )
    end
end

local function ValidateBloodBagUse(source, slot)
    local item, itemReason = GetBagItem(source, slot)
    if not item then return false, itemReason end

    local bag, bagReason = ParseBag(item)
    if not bag then return false, bagReason end
    if bag.expiresAt <= os.time() then return false, 'blood_bag_expired' end

    return true, item, bag
end

local function ClearBloodBagUseSession(source, token)
    source = tonumber(source)
    if not source then return false end

    local session = BloodBags.UseSessions[source]
    if not session then return false end
    if token and tostring(session.token) ~= tostring(token) then return false end

    BloodBags.UseSessions[source] = nil
    return true
end

CreateThread(function()
    Wait(500)

    local config = GetConfig()
    if config.Enabled ~= true then return end

    local itemName = tostring(config.Name or 'lb_bloodbag')

    QBCore.Functions.CreateUseableItem(itemName, function(source, item)
        source = tonumber(source)
        if not source or not item or not item.slot then
            if source then Notify(source, 'Kan torbası verisi okunamadı.', 'error') end
            return
        end

        if BloodBags.UseSessions[source] then
            Notify(source, 'Zaten bir kan torbası kullanıyorsun.', 'error', 3500)
            return
        end

        local valid, reason = ValidateBloodBagUse(source, item.slot)
        if not valid then
            Notify(source, BloodBagUseMessage(reason), 'error', 6000)
            return
        end

        local useConfig = GetBloodBagUseConfig()
        local duration = math.max(math.floor(tonumber(useConfig.Duration) or 6000), 500)
        local token = ('%s:%s:%s:%s'):format(
            tostring(source),
            tostring(item.slot),
            tostring(GetGameTimer()),
            tostring(math.random(100000, 999999))
        )

        BloodBags.UseSessions[source] = {
            token = token,
            slot = tonumber(item.slot),
            startedAt = GetGameTimer(),
            duration = duration
        }

        TriggerClientEvent('lb-vampire:client:bloodbag:startUse', source, {
            token = token,
            duration = duration,
            label = tostring(useConfig.Label or 'Kan torbası kullanılıyor...')
        })
    end)

    if Config.Debug then
        print(('^2[LB-VAMPIRE]^7 Blood bag usable registered: %s'):format(itemName))
    end
end)

RegisterNetEvent('lb-vampire:server:bloodbag:cancelUse', function(token)
    local src = tonumber(source)
    if not src then return end
    ClearBloodBagUseSession(src, token)
end)

RegisterNetEvent('lb-vampire:server:bloodbag:completeUse', function(token)
    local src = tonumber(source)
    if not src then return end

    local session = BloodBags.UseSessions[src]
    if not session or tostring(session.token) ~= tostring(token or '') then
        Notify(src, BloodBagUseMessage('invalid_use_session'), 'error', 4000)
        return
    end

    local useConfig = GetBloodBagUseConfig()
    local tolerance = math.max(math.floor(tonumber(useConfig.CompletionTolerance) or 350), 0)
    local elapsed = GetGameTimer() - (tonumber(session.startedAt) or GetGameTimer())
    if elapsed + tolerance < (tonumber(session.duration) or 6000) then
        ClearBloodBagUseSession(src, token)
        TriggerClientEvent('lb-vampire:client:bloodbag:forceCancel', src)
        Notify(src, BloodBagUseMessage('use_too_early'), 'error', 4000)
        return
    end

    local slot = tonumber(session.slot)
    ClearBloodBagUseSession(src, token)

    -- Final authoritative validation + inventory mutation happens only here,
    -- after the progressbar has actually completed.
    local success, result = BloodBags.Administer(src, src, slot)
    if not success then
        Notify(src, BloodBagUseMessage(result), 'error', 6000)
        return
    end

    NotifyBloodBagResult(src, result)
end)

AddEventHandler('playerDropped', function()
    local src = tonumber(source)
    if src then BloodBags.UseSessions[src] = nil end
end)




---------------------------------------------------------
-- EXPORTS
---------------------------------------------------------

exports(
    'CreateBloodBag',
    function(
        holderSource,
        bloodType,
        bloodAmount,
        options
    )

        return BloodBags.Create(

            holderSource,

            bloodType,

            bloodAmount,

            options
        )
    end
)


exports(
    'CreateBloodBagFromDonor',
    function(
        holderSource,
        donorSource,
        bloodAmount
    )

        return BloodBags.CreateFromDonor(

            holderSource,

            donorSource,

            bloodAmount
        )
    end
)


exports(
    'AdministerBloodBag',
    function(
        holderSource,
        targetSource,
        slot
    )

        return BloodBags.Administer(

            holderSource,

            targetSource,

            slot
        )
    end
)


---------------------------------------------------------
-- DEBUG COMMANDS
---------------------------------------------------------

if Config.Debug then

    -----------------------------------------------------
    -- OWN BLOOD TYPE
    -----------------------------------------------------

    RegisterCommand(
        'vambloodtype',
        function(source)

            if source <= 0 then
                return
            end


            local bloodType =
                GetPlayerBloodType(
                    source
                )


            Notify(
                source,

                (
                    'Blood Type: %s'
                ):format(
                    tostring(
                        bloodType
                        or 'UNKNOWN'
                    )
                ),

                'primary',

                5000
            )
        end,

        false
    )


    -----------------------------------------------------
    -- CREATE TEST BAG
    --
    -- /vambloodbag O+ 35
    -----------------------------------------------------

    RegisterCommand(
        'vambloodbag',
        function(
            source,
            args
        )

            if source <= 0 then
                return
            end


            local bloodType =
                args[1]


            local amount =
                tonumber(
                    args[2]
                )
                or tonumber(
                    GetConfig().DefaultAmount
                )
                or 35


            if not bloodType then

                Notify(
                    source,

                    'Usage: /vambloodbag [bloodtype] [amount]',

                    'error'
                )


                return
            end


            local success,
                result =
                BloodBags.Create(

                    source,

                    bloodType,

                    amount
                )


            if not success then

                Notify(
                    source,

                    (
                        'Blood bag create failed: %s'
                    ):format(
                        tostring(result)
                    ),

                    'error'
                )


                return
            end


            Notify(
                source,

                (
                    'Test kan torbası oluşturuldu: %s / %.1f'
                ):format(

                    result.bloodType,

                    result.bloodAmount
                ),

                'success'
            )
        end,

        false
    )


    -----------------------------------------------------
    -- INSPECT SLOT
    --
    -- /vambloodbaginfo 12
    -----------------------------------------------------

    RegisterCommand(
        'vambloodbaginfo',
        function(
            source,
            args
        )

            if source <= 0 then
                return
            end


            local slot =
                tonumber(
                    args[1]
                )


            if not slot then

                Notify(
                    source,

                    'Usage: /vambloodbaginfo [slot]',

                    'error'
                )


                return
            end


            local item,
                reason =
                GetBagItem(
                    source,
                    slot
                )


            if not item then

                Notify(
                    source,

                    tostring(reason),

                    'error'
                )


                return
            end


            local bag,
                parseReason =
                ParseBag(
                    item
                )


            if not bag then

                Notify(
                    source,

                    tostring(
                        parseReason
                    ),

                    'error'
                )


                return
            end


            local message =
                (
                    'Bag | Type: %s | Amount: %.2f | Expires: %s'
                ):format(

                    bag.bloodType,

                    bag.bloodAmount,

                    os.date(
                        '%d.%m.%Y %H:%M',
                        bag.expiresAt
                    )
                )


            Notify(
                source,

                message,

                'primary',

                8000
            )


            print(
                '^5[LB-VAMPIRE]^7 '
                .. message
            )
        end,

        false
    )
end