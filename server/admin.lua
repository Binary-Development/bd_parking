local serverConfig = require 'config.server'
local garage = require 'bridge.garage'
local vehicles = require 'server.modules.vehicles'
local impounds = require 'server.modules.impounds'
local world = require 'server.modules.world'
local locks = require 'server.modules.locks'
local logs = require 'server.modules.logs'
local notify = require 'server.modules.notify'

---@param source integer
---@param args { plate: string }
local function runAdminPark(source, args)
    local plate = world.normalizePlate(args.plate)
    local vehicle = plate ~= '' and vehicles.get(plate) or nil

    if not vehicle then
        return notify.send(source, 'error', 'notify.admin_not_found', plate)
    end

    local removed = world.removeCopies(plate)

    vehicles.release(vehicle.key)
    impounds.remove(plate)
    garage.onRemoved(plate)

    notify.send(source, 'success', 'notify.admin_parked', plate)
    logs.send(source, {
        action = 'log.admin_parked',
        color = 'danger',
        plate = plate,
        model = vehicle.model,
        vehicleOwner = vehicle.owner,
        copiesRemoved = removed
    })
end

lib.addCommand(serverConfig.commands.adminPark, {
    help = locale('command.admin_park'),
    params = {
        { name = 'plate', type = 'longString', help = locale('command.admin_park_plate') }
    },
    restricted = serverConfig.adminGroups
}, locks.perPlayer(runAdminPark))
