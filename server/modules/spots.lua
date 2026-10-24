local spots = {}

---@param owner string
---@return vector4?
function spots.get(owner)
    local row = MySQL.single.await('SELECT `x`, `y`, `z`, `heading` FROM `bd_parking_spots` WHERE `owner` = ?', { owner })

    return row and vec4(row.x, row.y, row.z, row.heading)
end

---@param owner string
---@param spot vector4
---@return boolean moved true when the owner already had a spot
function spots.set(owner, spot)
    local affected = MySQL.update.await(
        'INSERT INTO `bd_parking_spots` (`owner`, `x`, `y`, `z`, `heading`) VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE `x` = VALUES(`x`), `y` = VALUES(`y`), `z` = VALUES(`z`), `heading` = VALUES(`heading`)',
        { owner, spot.x, spot.y, spot.z, spot.w })

    return affected ~= 1
end

return spots
