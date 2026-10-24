local serverConfig = require 'config.server'
local sharedConfig = require 'config.shared'
local framework = require 'bridge.framework'
local garage = require 'bridge.garage'
local vehicles = require 'server.modules.vehicles'
local impounds = require 'server.modules.impounds'
local world = require 'server.modules.world'
local spawner = require 'server.modules.spawner'
local players = require 'server.modules.players'
local locks = require 'server.modules.locks'
local logs = require 'server.modules.logs'
local notify = require 'server.modules.notify'
local types = require 'shared.types'

local lotSlack = 5.0
local lotClearance = 2.5
local impoundReach = 6.0
local closestVehicleRadius = 4.0

---@class RecoverableVehicle
---@field plate string
---@field model integer
---@field status 'recoverable' | 'in_use'

---@param source integer
---@param lotIndex any
---@return table | false lot false after telling the player they aren't at a lot
local function requireLot(source, lotIndex)
    local lot = type(lotIndex) == 'number' and sharedConfig.impoundLots[lotIndex]

    if not lot or not world.isPlayerNear(source, lot.coords, sharedConfig.impoundRadius + lotSlack) then
        return notify.fail(source, 'notify.lot_far')
    end

    return lot
end

---@param vehicle OwnedVehicle
---@param inWorld table<string, integer>
---@return RecoverableVehicle?
local function describeRecoverable(vehicle, inWorld)
    if vehicle.status ~= 'out' or not vehicle.model then return end

    local entity = inWorld[vehicle.plate]
    local inUse = entity ~= nil and world.hasPlayerInside(entity)

    return { plate = vehicle.plate, model = vehicle.model, status = inUse and 'in_use' or 'recoverable' }
end

---@param source integer
---@param lotIndex any
---@return { price: number, vehicles: RecoverableVehicle[] }?
local function listRecoverable(source, lotIndex)
    if not requireLot(source, lotIndex) then return end

    local owner = players.requireOwner(source)
    if not owner then return end

    local owned = vehicles.getOwned(owner)
    local inWorld = world.indexPlates()
    local listed = {}

    for i = 1, #owned do
        listed[#listed + 1] = describeRecoverable(owned[i], inWorld)
    end

    if #listed == 0 then
        notify.fail(source, 'notify.lot_empty')

        return
    end

    return { price = serverConfig.prices.impound, vehicles = listed }
end

---@param source integer
---@param owner string
---@param plate string
---@return OwnedVehicle | false vehicle false after telling the player why
local function requireRecoverableVehicle(source, owner, plate)
    local vehicle = vehicles.get(plate)

    if not vehicle or vehicle.owner ~= owner then return notify.fail(source, 'notify.not_owner') end
    if vehicle.status ~= 'out' or not vehicle.model then return notify.fail(source, 'notify.lot_empty') end

    return vehicle
end

---@param source integer
---@param lotIndex any
---@param plate any
---@return boolean
local function recoverVehicle(source, lotIndex, plate)
    plate = world.normalizePlate(plate)
    if plate == '' then return false end

    local lot = requireLot(source, lotIndex)
    if not lot then return false end
    if not world.isOnFoot(source) then return notify.fail(source, 'notify.lot_in_vehicle') end

    local owner = players.requireOwner(source)
    if not owner then return false end

    local vehicle = requireRecoverableVehicle(source, owner, plate)
    if not vehicle then return false end

    local vehicleType = spawner.requireType(source, vehicle.model)
    if not vehicleType then return false end

    if world.isPlateInUse(plate) then return notify.fail(source, 'notify.in_use') end
    if world.isAreaBlocked(lot.spawn.xyz, lotClearance) then return notify.fail(source, 'notify.lot_blocked') end

    local entity = spawner.spawn({
        source = source,
        model = vehicle.model,
        vehicleType = vehicleType,
        plate = plate,
        props = vehicle.props,
        coords = lot.spawn
    })

    if not entity then return notify.fail(source, 'notify.spawn_failed') end

    local price = serverConfig.prices.impound

    if not players.charge(source, price, 'impound') then
        DeleteEntity(entity)

        return false
    end

    local removed = world.removeCopies(plate, entity)

    impounds.remove(plate)
    vehicles.markOut(vehicle.key)
    spawner.warpInto(source, entity)
    spawner.handOver(source, entity, plate)

    notify.send(source, 'success', 'notify.recovered', price)
    logs.send(source, {
        action = 'log.recovered',
        color = 'info',
        plate = plate,
        model = vehicle.model,
        price = price,
        copiesRemoved = removed
    })

    return true
end

---@param source integer
---@param entity integer?
---@return boolean
local function canReach(source, entity)
    return entity ~= nil and entity ~= 0 and DoesEntityExist(entity) and GetEntityType(entity) == 2
        and world.isPlayerNear(source, GetEntityCoords(entity), impoundReach)
end

---@param source integer
---@return boolean finished false when the player cancelled or skipped the progress bar
local function playImpoundProgress(source)
    local startedAt = GetGameTimer()
    local finished = lib.callback.await('bd_parking:client:impounding', source, sharedConfig.impoundTime)

    return finished == true and GetGameTimer() - startedAt >= sharedConfig.impoundTime * 900
end

---@param source integer
---@param entity integer?
---@return boolean
local function impoundVehicle(source, entity)
    if not players.canImpound(source, sharedConfig.impoundJobs) then return notify.fail(source, 'notify.impound_denied') end
    if not world.isOnFoot(source) then return notify.fail(source, 'notify.lot_in_vehicle') end
    if not canReach(source, entity) then return notify.fail(source, 'notify.impound_none') end
    if world.hasPlayerInside(entity) then return notify.fail(source, 'notify.impound_occupied') end
    if not types.isAllowed(GetVehicleType(entity)) then return notify.fail(source, 'notify.type_blocked') end

    local plate = world.normalizePlate(GetVehicleNumberPlateText(entity))

    if not playImpoundProgress(source) then return false end

    local unchanged = canReach(source, entity) and world.normalizePlate(GetVehicleNumberPlateText(entity)) == plate
    if not unchanged then return notify.fail(source, 'notify.impound_none') end
    if world.hasPlayerInside(entity) then return notify.fail(source, 'notify.impound_occupied') end

    local model = world.toModelHash(GetEntityModel(entity))
    local vehicle = plate ~= '' and vehicles.get(plate) or nil

    if vehicle and vehicle.status == 'out' then
        impounds.add(plate, framework.getOwner(source))
        garage.onRemoved(plate)
    end

    DeleteEntity(entity)

    notify.send(source, 'success', 'notify.impounded')
    logs.send(source, {
        action = 'log.impounded',
        color = 'warning',
        plate = plate,
        model = model,
        vehicleOwner = vehicle and vehicle.owner or 'Not registered'
    })

    return true
end

local lockedImpound = locks.perPlayer(impoundVehicle)

---@param source integer
local function runImpoundCommand(source)
    if source == 0 then return end

    lockedImpound(source, world.getClosestVehicle(source, closestVehicleRadius))
end

---@param netId any
local function impoundTargetedVehicle(netId)
    if GetInvokingResource() or type(netId) ~= 'number' then return end

    lockedImpound(source, NetworkGetEntityFromNetworkId(netId))
end

lib.addCommand(serverConfig.commands.impound, {
    help = locale('command.impound')
}, runImpoundCommand)

lib.callback.register('bd_parking:server:getImpounded', listRecoverable)
lib.callback.register('bd_parking:server:recover', locks.perPlayer(recoverVehicle))
RegisterNetEvent('bd_parking:server:requestedImpound', impoundTargetedVehicle)
