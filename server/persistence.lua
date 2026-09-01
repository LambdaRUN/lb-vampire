LBVampire = LBVampire or {}
LBVampire.Persistence = LBVampire.Persistence or {}

local function ToBoolean(value)
    return tonumber(value) == 1
        or value == true
end

local schemaReady = false

local function Ensure5DSchema()
    if schemaReady then return true end

    local ok, err = pcall(function()
        MySQL.query.await([[
            ALTER TABLE vampire_characters
                ADD COLUMN IF NOT EXISTS torpor_stage TINYINT NOT NULL DEFAULT 0 AFTER can_embrace,
                ADD COLUMN IF NOT EXISTS collapse_started_at BIGINT NULL AFTER torpor_stage,
                ADD COLUMN IF NOT EXISTS kin_calls TINYINT NOT NULL DEFAULT 0 AFTER collapse_started_at
        ]])
    end)

    if not ok then
        print(('^1[LB-VAMPIRE]^7 5D schema migration failed: %s'):format(tostring(err)))
        return false
    end

    schemaReady = true
    return true
end

LBVampire.Persistence.Ensure5DSchema = Ensure5DSchema

function LBVampire.Persistence.GetVampire(citizenId)
    if not citizenId then
        return nil
    end

    Ensure5DSchema()

    local result = MySQL.single.await([[
        SELECT
            citizenid,
            is_vampire,
            sire_citizenid,
            blood,
            can_embrace,
            torpor_stage,
            collapse_started_at,
            kin_calls,
            embraced_at,
            created_at,
            updated_at
        FROM vampire_characters
        WHERE citizenid = ?
        LIMIT 1
    ]], {
        citizenId
    })

    if not result then
        return nil
    end

    result.is_vampire =
        ToBoolean(result.is_vampire)

    result.can_embrace =
        ToBoolean(result.can_embrace)

    result.blood =
        tonumber(result.blood)
        or Config.Blood.Default

    result.torpor_stage = tonumber(result.torpor_stage) or 0
    result.collapse_started_at = tonumber(result.collapse_started_at)
    result.kin_calls = tonumber(result.kin_calls) or 0

    return result
end

function LBVampire.Persistence.ActivateVampire(
    citizenId
)
    if not citizenId then
        return false
    end

    Ensure5DSchema()

    local defaultBlood =
        tonumber(Config.Blood.Default)
        or 100

    MySQL.query.await([[
        INSERT INTO vampire_characters (
            citizenid,
            is_vampire,
            sire_citizenid,
            blood,
            can_embrace,
            torpor_stage,
            collapse_started_at,
            kin_calls,
            embraced_at
        )
        VALUES (?, 1, NULL, ?, 0, 0, NULL, 0, NULL)

        ON DUPLICATE KEY UPDATE
            is_vampire = 1,
            sire_citizenid = NULL,
            blood = ?,
            can_embrace = 0,
            torpor_stage = 0,
            collapse_started_at = NULL,
            kin_calls = 0,
            embraced_at = NULL
    ]], {
        citizenId,
        defaultBlood,
        defaultBlood
    })

    return true
end

function LBVampire.Persistence.DeactivateVampire(
    citizenId
)
    if not citizenId then
        return false
    end

    Ensure5DSchema()

    local affectedRows =
        MySQL.update.await([[
            UPDATE vampire_characters
            SET
                is_vampire = 0,
                can_embrace = 0
            WHERE citizenid = ?
        ]], {
            citizenId
        })

    return affectedRows ~= nil
end

function LBVampire.Persistence.UpdateBlood(
    citizenId,
    blood
)
    if not citizenId then
        return false
    end

    blood = tonumber(blood)

    if not blood then
        return false
    end

    local affectedRows =
        MySQL.update.await([[
            UPDATE vampire_characters
            SET blood = ?
            WHERE citizenid = ?
              AND is_vampire = 1
        ]], {
            blood,
            citizenId
        })

    return affectedRows ~= nil
end

function LBVampire.Persistence.UpdateCanEmbrace(
    citizenId,
    enabled
)
    if not citizenId then
        return false
    end

    local affectedRows =
        MySQL.update.await([[
            UPDATE vampire_characters
            SET can_embrace = ?
            WHERE citizenid = ?
              AND is_vampire = 1
        ]], {
            enabled and 1 or 0,
            citizenId
        })

    return affectedRows ~= nil
end

function LBVampire.Persistence.SaveRuntimeState(
    state
)
    if not state
        or not state.citizenId then
        return false
    end

    Ensure5DSchema()

    local affectedRows =
        MySQL.update.await([[
            UPDATE vampire_characters
            SET
                blood = ?,
                can_embrace = ?,
                torpor_stage = ?,
                collapse_started_at = ?,
                kin_calls = ?
            WHERE citizenid = ?
              AND is_vampire = 1
        ]], {
            state.blood,
            state.canEmbrace and 1 or 0,
            tonumber(state.torporStage) or 0,
            tonumber(state.collapseStartedAt),
            tonumber(state.kinCalls) or 0,
            state.citizenId
        })

    return affectedRows ~= nil
end

