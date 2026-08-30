LBVampire = LBVampire or {}
LBVampire.Persistence = LBVampire.Persistence or {}

local function ToBoolean(value)
    return tonumber(value) == 1
        or value == true
end

function LBVampire.Persistence.GetVampire(citizenId)
    if not citizenId then
        return nil
    end

    local result = MySQL.single.await([[
        SELECT
            citizenid,
            is_vampire,
            sire_citizenid,
            blood,
            can_embrace,
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

    return result
end

function LBVampire.Persistence.ActivateVampire(
    citizenId
)
    if not citizenId then
        return false
    end

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
            embraced_at
        )
        VALUES (?, 1, NULL, ?, 0, NULL)

        ON DUPLICATE KEY UPDATE
            is_vampire = 1,
            sire_citizenid = NULL,
            blood = ?,
            can_embrace = 0,
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

    local affectedRows =
        MySQL.update.await([[
            UPDATE vampire_characters
            SET
                blood = ?,
                can_embrace = ?
            WHERE citizenid = ?
              AND is_vampire = 1
        ]], {
            state.blood,
            state.canEmbrace and 1 or 0,
            state.citizenId
        })

    return affectedRows ~= nil
end

