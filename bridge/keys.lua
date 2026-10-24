local pick = require 'bridge.pick'
local serverConfig = require 'config.server'

---@alias KeyGiver fun(source: integer, vehicle: integer, plate: string)

---@type table<string, KeyGiver>
local givers = {}

function givers.bd(source, _, plate)
    exports.bd_carkeys:GiveKeys(source, plate)
end

function givers.wasabi(source, _, plate)
    exports.wasabi_carlock:GiveKey(source, plate)
end

function givers.mk(source, vehicle)
    exports.mk_vehiclekeys:AddKey(vehicle, source)
end

function givers.brutal(source, _, plate)
    TriggerEvent('brutal_keys:server:addVehicleKey', source, plate, plate)
end

function givers.okok(source, _, plate)
    TriggerClientEvent('bd_parking:client:receivedVehicle', source, plate)
end

function givers.qbox(source, vehicle)
    exports.qbx_vehiclekeys:GiveKeys(source, vehicle)
end

function givers.qbcore(source, _, plate)
    exports['qb-vehiclekeys']:GiveKeys(source, plate)
end

function givers.nd(source, vehicle)
    exports.ND_Core:giveVehicleAccess(source, vehicle, true)
end

function givers.none() end

local name = pick.choose({
    kind = 'keys',
    setting = serverConfig.keys,
    options = { 'bd', 'wasabi', 'mk', 'brutal', 'okok', 'qbox', 'qbcore', 'nd', 'none' },
    detection = {
        { resource = 'bd_carkeys', name = 'bd' },
        { resource = 'wasabi_carlock', name = 'wasabi' },
        { resource = 'mk_vehiclekeys', name = 'mk' },
        { resource = 'brutal_keys', name = 'brutal' },
        { resource = 'okokGarage', name = 'okok' },
        { resource = 'qbx_vehiclekeys', name = 'qbox' },
        { resource = 'qb-vehiclekeys', name = 'qbcore' },
        { resource = 'ND_Core', name = 'nd' },
    },
    fallback = 'none'
})

return {
    give = givers[name]
}
