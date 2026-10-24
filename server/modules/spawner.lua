local keys = require 'bridge.keys'
local garage = require 'bridge.garage'
local world = require 'server.modules.world'
local notify = require 'server.modules.notify'
local types = require 'shared.types'

local spawner = {}

local vehicleTypes = {
    automobile = true,
    bike = true,
    boat = true,
    heli = true,
    plane = true,
    submarine = true,
    trailer = true,
    train = true
}

local modelTypes = {}

---@class SpawnRequest
---@field source integer
---@field model integer
---@field vehicleType string
---@field plate string
---@field props table
---@field coords vector4

---@param vehicle integer
function spawner.rememberType(vehicle)
    local model = world.toModelHash(GetEntityModel(vehicle))
    local vehicleType = GetVehicleType(vehicle)

    if model and vehicleTypes[vehicleType] then
        modelTypes[model] = vehicleType
    end
end

---@param source integer
---@param model integer
---@return string?
local function resolveType(source, model)
    local known = modelTypes[model]
    if known then return known end

    local vehicleType = lib.callback.await('bd_parking:client:getVehicleType', source, model)

    return vehicleTypes[vehicleType] and vehicleType or nil
end

---@param source integer
---@param model integer
---@return string | false vehicleType false after telling the player why it can't spawn
function spawner.requireType(source, model)
    local vehicleType = resolveType(source, model)

    if not vehicleType then return notify.fail(source, 'notify.spawn_failed') end
    if not types.isAllowed(vehicleType) then return notify.fail(source, 'notify.type_blocked') end

    return vehicleType
end

---@param vehicle integer
---@return boolean
local function awaitExists(vehicle)
    local deadline = GetGameTimer() + 2000

    while not DoesEntityExist(vehicle) do
        if GetGameTimer() > deadline then return false end

        Wait(50)
    end

    return true
end

---@param vehicle integer
---@return boolean
local function awaitOwner(vehicle)
    local deadline = GetGameTimer() + 5000

    while NetworkGetEntityOwner(vehicle) == -1 do
        if GetGameTimer() > deadline then return false end

        Wait(50)
    end

    return true
end

---@param request SpawnRequest
---@return integer?
function spawner.spawn(request)
    local coords = request.coords
    local vehicle = CreateVehicleServerSetter(request.model, request.vehicleType, coords.x, coords.y, coords.z, coords.w)

    if not vehicle or vehicle == 0 or not awaitExists(vehicle) then return end

    SetEntityOrphanMode(vehicle, 2)
    SetEntityRoutingBucket(vehicle, GetPlayerRoutingBucket(request.source))
    SetVehicleNumberPlateText(vehicle, request.plate)

    if not awaitOwner(vehicle) then
        DeleteEntity(vehicle)

        return
    end

    local props = request.props
    props.plate = request.plate
    props.model = request.model

    local state = Entity(vehicle).state
    state:set('ox_lib:setVehicleProperties', props, true)
    state:set('ox_entity_setonground', true, true)

    return vehicle
end

---@param source integer
---@param vehicle integer
---@param plate string
function spawner.handOver(source, vehicle, plate)
    garage.onSpawned(plate, vehicle)
    keys.give(source, vehicle, plate)
end

---@param source integer
---@param vehicle integer
function spawner.warpInto(source, vehicle)
    local ped = GetPlayerPed(source)

    for _ = 1, 20 do
        if GetVehiclePedIsIn(ped, false) == vehicle then return end

        SetPedIntoVehicle(ped, vehicle, -1)
        Wait(100)
    end
end

return spawner
