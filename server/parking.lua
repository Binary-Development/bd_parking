local serverConfig = require 'config.server'
local framework = require 'bridge.framework'
local garage = require 'bridge.garage'
local vehicles = require 'server.modules.vehicles'
local spots = require 'server.modules.spots'
local impounds = require 'server.modules.impounds'
local world = require 'server.modules.world'
local spawner = require 'server.modules.spawner'
local players = require 'server.modules.players'
local locks = require 'server.modules.locks'
local logs = require 'server.modules.logs'
local notify = require 'server.modules.notify'
local types = require 'shared.types'

local spotClearance = 2.5

local statusOrder = {
    stored = 1,
    out = 2,
    impounded = 3,
    lost = 4,
    held = 5
}

---@class ListedVehicle
---@field plate string
---@field model integer?
---@field status 'stored' | 'out' | 'impounded' | 'lost' | 'held'
---@field props? table
---@field coords? vector3

---@param source integer
---@param spot vector4
local function pointToSpot(source, spot)
    TriggerClientEvent('bd_parking:client:markedWaypoint', source, spot.xyz)
    notify.send(source, 'inform', 'notify.too_far')
end

---@param source integer
---@param owner string
---@return vector4 | false spot false after telling the player to buy one
local function requireSpot(source, owner)
    return spots.get(owner) or notify.fail(source, 'notify.no_spot', serverConfig.commands.parking)
end

---@param vehicle OwnedVehicle?
---@param owner string
---@return boolean
local function canPark(vehicle, owner)
    if vehicle then return vehicle.owner == owner end

    return framework.claimsOnPark == true
end

---@param source integer
---@param entity integer
---@return table?
local function readProperties(source, entity)
    local props = lib.callback.await('bd_parking:client:getProperties', source, NetworkGetNetworkIdFromEntity(entity))
    if type(props) ~= 'table' then return end

    local samePlate = world.normalizePlate(props.plate) == world.normalizePlate(GetVehicleNumberPlateText(entity))
    local sameModel = world.toModelHash(props.model) == world.toModelHash(GetEntityModel(entity))

    return samePlate and sameModel and props or nil
end

---@param source integer
local function buySpot(source)
    local owner = players.requireOwner(source)
    if not owner or players.isBlockedByProperty(source, owner) then return end

    if not framework.claimsOnPark and not vehicles.hasAny(owner) then
        return notify.fail(source, 'notify.no_vehicles')
    end

    local ped = GetPlayerPed(source)
    local vehicle = GetVehiclePedIsIn(ped, false)
    local anchor = vehicle ~= 0 and vehicle or ped
    local coords = GetEntityCoords(anchor)
    local price = serverConfig.prices.spot

    if not players.charge(source, price, 'parking spot') then return end

    local moved = spots.set(owner, vec4(coords.x, coords.y, coords.z, GetEntityHeading(anchor)))

    notify.send(source, 'success', moved and 'notify.spot_moved' or 'notify.spot_bought', price)
    logs.send(source, { action = moved and 'log.moved' or 'log.bought', color = 'success', price = price, coords = coords })
end

---@param source integer
local function parkVehicle(source)
    local owner = players.requireOwner(source)
    if not owner or players.isBlockedByProperty(source, owner) then return end

    local spot = requireSpot(source, owner)
    if not spot then return end

    local entity = world.getDrivenVehicle(source)
    if not entity then return notify.fail(source, 'notify.not_driving') end
    if #(GetEntityCoords(entity) - spot.xyz) > serverConfig.parkRadius then return pointToSpot(source, spot) end
    if not types.isAllowed(GetVehicleType(entity)) then return notify.fail(source, 'notify.type_blocked') end

    local plate = world.normalizePlate(GetVehicleNumberPlateText(entity))
    local model = world.toModelHash(GetEntityModel(entity))
    local vehicle = plate ~= '' and vehicles.get(plate) or nil

    if plate == '' or not canPark(vehicle, owner) then return notify.fail(source, 'notify.not_owner') end

    if vehicle and vehicle.model and vehicle.model ~= model then
        lib.print.warn(('%s tried to park plate %s on a different model than registered'):format(owner, plate))

        return notify.fail(source, 'notify.not_owner')
    end

    local props = readProperties(source, entity)
    if not props then return notify.fail(source, 'notify.read_failed') end
    if world.getDrivenVehicle(source) ~= entity then return notify.fail(source, 'notify.not_driving') end

    local key = vehicle and vehicle.key or plate

    props.plate = key
    spawner.rememberType(entity)

    if not vehicle then
        vehicles.register(owner, plate, model, props)
    end

    if framework.beforeDespawn then
        framework.beforeDespawn(entity)
    end

    vehicles.store(key, props)
    impounds.remove(plate)
    garage.onRemoved(plate)

    if DoesEntityExist(entity) then
        DeleteEntity(entity)
    end

    notify.send(source, 'success', 'notify.parked')
    logs.send(source, { action = 'log.parked', color = 'info', plate = plate, model = model })
end

---@param a ListedVehicle
---@param b ListedVehicle
---@return boolean
local function sortListed(a, b)
    if a.status ~= b.status then return statusOrder[a.status] < statusOrder[b.status] end

    return a.plate < b.plate
end

---@param vehicle OwnedVehicle
---@param inWorld table<string, integer>
---@return ListedVehicle
local function describeVehicle(vehicle, inWorld)
    local listed = { plate = vehicle.plate, model = vehicle.model, status = vehicle.status }
    local entity = inWorld[vehicle.plate]

    if vehicle.status == 'stored' then
        listed.props = vehicle.props
    elseif vehicle.status == 'out' and entity then
        listed.coords = GetEntityCoords(entity)
    elseif vehicle.status == 'out' then
        listed.status = impounds.has(vehicle.plate) and 'impounded' or 'lost'
    end

    return listed
end

---@param source integer
local function listVehicles(source)
    local owner = players.requireOwner(source)
    if not owner then return end

    local spot = requireSpot(source, owner)
    if not spot then return end

    local owned = vehicles.getOwned(owner)
    if #owned == 0 then return notify.fail(source, 'notify.no_vehicles') end

    local inWorld = world.indexPlates()
    local listed = {}

    for i = 1, #owned do
        listed[i] = describeVehicle(owned[i], inWorld)
    end

    table.sort(listed, sortListed)

    TriggerClientEvent('bd_parking:client:openedList', source, { spot = spot, vehicles = listed })
end

---@param source integer
---@param owner string
---@param plate string
---@return OwnedVehicle | false vehicle false after telling the player why
local function requireStoredVehicle(source, owner, plate)
    local vehicle = vehicles.get(plate)

    if not vehicle or vehicle.owner ~= owner then return notify.fail(source, 'notify.not_owner') end
    if vehicle.status ~= 'stored' or not vehicle.model then return notify.fail(source, 'notify.not_parked') end

    return vehicle
end

---@param source integer
---@param plate any
---@return boolean
local function takeOut(source, plate)
    plate = world.normalizePlate(plate)
    if plate == '' then return false end

    local owner = players.requireOwner(source)
    if not owner or players.isBlockedByProperty(source, owner) then return false end

    local spot = requireSpot(source, owner)
    if not spot then return false end

    if not world.isPlayerNear(source, spot.xyz, serverConfig.takeOutRange) then
        pointToSpot(source, spot)

        return false
    end

    local vehicle = requireStoredVehicle(source, owner, plate)
    if not vehicle then return false end

    local vehicleType = spawner.requireType(source, vehicle.model)
    if not vehicleType then return false end

    if world.isPlateInUse(plate) then return notify.fail(source, 'notify.in_use') end

    local removed = world.removeCopies(plate)

    if world.isAreaBlocked(spot.xyz, spotClearance) then return notify.fail(source, 'notify.spot_blocked') end
    if not vehicles.claimOut(vehicle.key) then return notify.fail(source, 'notify.not_parked') end

    local entity = spawner.spawn({
        source = source,
        model = vehicle.model,
        vehicleType = vehicleType,
        plate = plate,
        props = vehicle.props,
        coords = spot
    })

    if not entity then
        vehicles.store(vehicle.key, vehicle.props)

        return notify.fail(source, 'notify.spawn_failed')
    end

    spawner.handOver(source, entity, plate)
    notify.send(source, 'success', 'notify.taken_out')
    logs.send(source, {
        action = 'log.took_out',
        color = 'info',
        plate = plate,
        model = vehicle.model,
        coords = spot.xyz,
        copiesRemoved = removed
    })

    return true
end

local actions = {
    buy = buySpot,
    park = parkVehicle,
    list = listVehicles
}

---@param source integer
---@param args { action?: string }
local function runParkingCommand(source, args)
    if source == 0 then return end

    local command = serverConfig.commands.parking
    local action = actions[(args.action or 'list'):lower()]

    if not action then
        return notify.send(source, 'inform', 'notify.usage', command, command, command)
    end

    action(source)
end

lib.addCommand(serverConfig.commands.parking, {
    help = locale('command.parking'),
    params = {
        { name = 'action', type = 'string', help = locale('command.parking_action'), optional = true }
    }
}, locks.perPlayer(runParkingCommand))

lib.callback.register('bd_parking:server:takeOut', locks.perPlayer(takeOut))
