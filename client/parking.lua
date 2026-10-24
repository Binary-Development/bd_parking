local sharedConfig = require 'config.shared'
local vehicle = require 'client.modules.vehicle'

local previewVehicle
local previewToken = 0
local listedSpot
local listedVehicles = {}

local function clearPreview()
    previewToken += 1

    if previewVehicle and DoesEntityExist(previewVehicle) then
        DeleteEntity(previewVehicle)
    end

    previewVehicle = nil
end

---@param model integer
---@param props table
local function showPreview(model, props)
    clearPreview()

    if not listedSpot or not IsModelInCdimage(model) then return end

    local token = previewToken

    lib.requestModel(model)

    if token ~= previewToken then
        return SetModelAsNoLongerNeeded(model)
    end

    local spot = listedSpot
    local preview = CreateVehicle(model, spot.x, spot.y, spot.z, spot.w, false, false)

    SetModelAsNoLongerNeeded(model)
    lib.setVehicleProperties(preview, props)
    SetVehicleOnGroundProperly(preview)
    SetEntityCollision(preview, false, false)
    FreezeEntityPosition(preview, true)
    SetEntityInvincible(preview, true)
    SetVehicleDoorsLocked(preview, 2)
    SetEntityAlpha(preview, sharedConfig.previewAlpha, false)

    previewVehicle = preview
end

---@param coords vector3
local function markLocation(coords)
    SetNewWaypoint(coords.x, coords.y)
end

local function markNearestLot()
    local origin = GetEntityCoords(cache.ped)
    local nearest, nearestDistance

    for i = 1, #sharedConfig.impoundLots do
        local coords = sharedConfig.impoundLots[i].coords
        local distance = #(coords - origin)

        if not nearestDistance or distance < nearestDistance then
            nearest, nearestDistance = coords, distance
        end
    end

    if nearest then markLocation(nearest) end
end

---@param plate string
local function takeOut(plate)
    clearPreview()
    lib.callback.await('bd_parking:server:takeOut', false, plate)
end

---@param index integer
local function openVehicle(index)
    local listed = listedVehicles[index]

    lib.registerContext({
        id = 'bd_parking_vehicle',
        title = vehicle.getTitle(listed),
        menu = 'bd_parking_list',
        onBack = clearPreview,
        onExit = clearPreview,
        options = {
            { title = locale('menu.take_out'), icon = 'key', onSelect = takeOut, args = listed.plate }
        }
    })

    lib.showContext('bd_parking_vehicle')
    showPreview(listed.model, listed.props)
end

---@param index integer
---@return table
local function buildOption(index)
    local listed = listedVehicles[index]
    local option = {
        title = vehicle.getTitle(listed),
        description = locale(('menu.%s'):format(listed.status))
    }

    if listed.status == 'stored' then
        option.onSelect = openVehicle
        option.args = index
        option.arrow = true
        option.disabled = not listed.model
    elseif listed.status == 'out' then
        option.onSelect = markLocation
        option.args = listed.coords
    elseif listed.status == 'held' then
        option.disabled = true
    else
        option.onSelect = markNearestLot
    end

    return option
end

---@param data { spot: vector4, vehicles: table[] }
local function openList(data)
    clearPreview()

    listedSpot = data.spot
    listedVehicles = {}

    for i = 1, #data.vehicles do
        local listed = data.vehicles[i]

        if vehicle.isAllowed(listed.model) then
            listedVehicles[#listedVehicles + 1] = listed
        end
    end

    if #listedVehicles == 0 then
        return lib.notify({ title = locale('title'), description = locale('notify.no_vehicles'), type = 'error' })
    end

    local options = {}

    for i = 1, #listedVehicles do
        options[i] = buildOption(i)
    end

    lib.registerContext({
        id = 'bd_parking_list',
        title = locale('title'),
        options = options
    })

    lib.showContext('bd_parking_list')
end

---@param netId integer
---@return table?
local function getProperties(netId)
    if not cache.vehicle or VehToNet(cache.vehicle) ~= netId then return end

    return lib.getVehicleProperties(cache.vehicle)
end

---@param plate string
local function claimOkokKeys(plate)
    TriggerServerEvent('okokGarage:GiveKeys', plate)
end

---@param resource string
local function cleanUp(resource)
    if resource ~= cache.resource then return end

    clearPreview()
end

RegisterNetEvent('bd_parking:client:openedList', openList)
RegisterNetEvent('bd_parking:client:markedWaypoint', markLocation)
RegisterNetEvent('bd_parking:client:receivedVehicle', claimOkokKeys)
lib.callback.register('bd_parking:client:getVehicleType', vehicle.getType)
lib.callback.register('bd_parking:client:getProperties', getProperties)
AddEventHandler('onResourceStop', cleanUp)
