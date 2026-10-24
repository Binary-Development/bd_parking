local pick = require 'bridge.pick'
local serverConfig = require 'config.server'

---@class GarageStateColumn
---@field column string
---@field storedValue any
---@field outValue any

---@class GarageBridge
---@field stateColumn? GarageStateColumn
---@field onSpawned fun(plate: string, vehicle: integer)
---@field onRemoved fun(plate: string)

local function ignore() end

---@param plate string
---@param netId integer
local function registerOutside(plate, netId)
    exports['jg-advancedgarages']:registerVehicleOutside(plate, netId)
end

---@param plate string
local function deleteOutside(plate)
    exports['jg-advancedgarages']:deleteOutsideVehicle(plate)
end

---@param plate string
---@param vehicle integer
local function trackJgVehicle(plate, vehicle)
    local ok, err = pcall(registerOutside, plate, NetworkGetNetworkIdFromEntity(vehicle))

    if not ok then
        lib.print.warn(('jg-advancedgarages registerVehicleOutside failed for %s: %s'):format(plate, err))
    end
end

---@param plate string
local function untrackJgVehicle(plate)
    local ok, err = pcall(deleteOutside, plate)

    if not ok then
        lib.print.warn(('jg-advancedgarages deleteOutsideVehicle failed for %s: %s'):format(plate, err))
    end
end

---@type table<string, GarageBridge>
local bridges = {
    jg = {
        stateColumn = { column = 'in_garage', storedValue = 1, outValue = 0 },
        onSpawned = trackJgVehicle,
        onRemoved = untrackJgVehicle
    },
    none = {
        onSpawned = ignore,
        onRemoved = ignore
    }
}

local name = pick.choose({
    kind = 'garage',
    setting = serverConfig.garage,
    options = { 'jg', 'none' },
    detection = {
        { resource = 'jg-advancedgarages', name = 'jg' },
    },
    fallback = 'none'
})

---@type GarageBridge
return bridges[name]
