local sharedConfig = require 'config.shared'

local types = {}

local toggles = {
    boat = 'allowBoats',
    submarine = 'allowBoats',
    heli = 'allowAircraft',
    plane = 'allowAircraft'
}

---@param vehicleType string?
---@return boolean
function types.isAllowed(vehicleType)
    if not vehicleType then return false end

    local toggle = toggles[vehicleType]

    return not toggle or sharedConfig[toggle] == true
end

return types
