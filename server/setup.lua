local serverConfig = require 'config.server'
local sharedConfig = require 'config.shared'
local framework = require 'bridge.framework'
local vehicles = require 'server.modules.vehicles'
local impounds = require 'server.modules.impounds'
local world = require 'server.modules.world'

---@param value any
---@param path string
local function assertNumber(value, path)
    assert(type(value) == 'number' and value >= 0, ('%s must be a number of 0 or more'):format(path))
end

local function validateConfig()
    assert(type(serverConfig.commands) == 'table', 'config/server.lua: commands is missing')
    assert(type(serverConfig.prices) == 'table', 'config/server.lua: prices is missing')
    assertNumber(serverConfig.prices.spot, 'config/server.lua: prices.spot')
    assertNumber(serverConfig.prices.impound, 'config/server.lua: prices.impound')
    assertNumber(serverConfig.parkRadius, 'config/server.lua: parkRadius')
    assertNumber(serverConfig.takeOutRange, 'config/server.lua: takeOutRange')
    assert(serverConfig.payWith == 'cash' or serverConfig.payWith == 'bank', "config/server.lua: payWith must be 'cash' or 'bank'")
    assertNumber(sharedConfig.impoundTime, 'config/shared.lua: impoundTime')
    assertNumber(sharedConfig.impoundRadius, 'config/shared.lua: impoundRadius')

    for i = 1, #sharedConfig.impoundLots do
        local lot = sharedConfig.impoundLots[i]

        assert(type(lot.coords) == 'vector3', ('config/shared.lua: impoundLots[%d].coords must be a vec3'):format(i))
        assert(type(lot.spawn) == 'vector4', ('config/shared.lua: impoundLots[%d].spawn must be a vec4 with heading'):format(i))
    end

    if serverConfig.takeOutRange > 400 then
        lib.print.warn('config/server.lua: takeOutRange is over 400, cars taken out from further away may spawn without their mods')
    end
end

local function createTables()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `bd_parking_spots` (
            `owner` VARCHAR(100) NOT NULL,
            `x` DOUBLE NOT NULL,
            `y` DOUBLE NOT NULL,
            `z` DOUBLE NOT NULL,
            `heading` DOUBLE NOT NULL,
            `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`owner`)
        )
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `bd_parking_impound` (
            `plate` VARCHAR(16) NOT NULL,
            `impounded_by` VARCHAR(100) NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`plate`)
        )
    ]])

    if framework.setupQuery then
        MySQL.query.await(framework.setupQuery)
    end
end

local function returnLeftoverVehicles()
    local inWorld = world.indexPlates()

    ---@param plate string
    ---@return boolean
    local function shouldStayOut(plate)
        return inWorld[plate] ~= nil or impounds.has(plate)
    end

    local returned = vehicles.returnAllOut(shouldStayOut)

    if returned > 0 then
        lib.print.info(('returned %d vehicles to parking'):format(returned))
    end
end

local function setupDatabase()
    createTables()
    vehicles.init()
    impounds.load()

    if serverConfig.returnOnRestart then
        returnLeftoverVehicles()
    end
end

validateConfig()
MySQL.ready(setupDatabase)
