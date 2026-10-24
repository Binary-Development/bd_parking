local impounds = {}

local plates = {}

function impounds.load()
    local rows = MySQL.query.await('SELECT `plate` FROM `bd_parking_impound`') or {}

    for i = 1, #rows do
        plates[rows[i].plate] = true
    end
end

---@param plate string
---@return boolean
function impounds.has(plate)
    return plates[plate] == true
end

---@param plate string
---@param officer string?
function impounds.add(plate, officer)
    plates[plate] = true

    MySQL.prepare.await(
        'INSERT INTO `bd_parking_impound` (`plate`, `impounded_by`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `impounded_by` = VALUES(`impounded_by`), `created_at` = CURRENT_TIMESTAMP',
        { plate, officer })
end

---@param plate string
function impounds.remove(plate)
    if not plates[plate] then return end

    plates[plate] = nil

    MySQL.prepare.await('DELETE FROM `bd_parking_impound` WHERE `plate` = ?', { plate })
end

return impounds
