local sharedConfig = require 'config.shared'
local vehicle = require 'client.modules.vehicle'

local currentLot
local keybind
local targetIcon = 'fas fa-truck-pickup'
local targetName = 'bd_parking:impound'

---@param args { lot: integer, plate: string }
local function recoverVehicle(args)
    lib.callback.await('bd_parking:server:recover', false, args.lot, args.plate)
end

---@param lot integer
---@param price number
---@param listed table
---@return table
local function buildOption(lot, price, listed)
    local option = { title = vehicle.getTitle(listed) }

    if listed.status == 'in_use' then
        option.description = locale('menu.in_use')
        option.disabled = true
    else
        option.description = locale('menu.recover', price)
        option.onSelect = recoverVehicle
        option.args = { lot = lot, plate = listed.plate }
    end

    return option
end

local function openLot()
    local lot = currentLot
    if not lot then return end

    if cache.vehicle then
        return lib.notify({ title = locale('title'), description = locale('notify.lot_in_vehicle'), type = 'error' })
    end

    local data = lib.callback.await('bd_parking:server:getImpounded', false, lot)
    if not data then return end

    local options = {}

    for i = 1, #data.vehicles do
        local listed = data.vehicles[i]

        if vehicle.isAllowed(listed.model) then
            options[#options + 1] = buildOption(lot, data.price, listed)
        end
    end

    if #options == 0 then
        return lib.notify({ title = locale('title'), description = locale('notify.lot_empty'), type = 'error' })
    end

    lib.registerContext({
        id = 'bd_parking_impound',
        title = locale('menu.impound'),
        options = options
    })

    lib.showContext('bd_parking_impound')
end

---@param point CPoint
local function enterLot(point)
    currentLot = point.lot
    keybind:disable(false)
    lib.showTextUI(locale('prompt.impound'))
end

local function exitLot()
    currentLot = nil
    keybind:disable(true)

    local isOpen, text = lib.isTextUIOpen()

    if isOpen and text == locale('prompt.impound') then
        lib.hideTextUI()
    end
end

---@param coords vector3
local function createLotBlip(coords)
    local settings = sharedConfig.impoundBlip
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)

    SetBlipSprite(blip, settings.sprite)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, settings.scale)
    SetBlipColour(blip, settings.color)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(settings.label)
    EndTextCommandSetBlipName(blip)
end

---@param entity integer
local function requestImpound(entity)
    if not entity or entity == 0 or not NetworkGetEntityIsNetworked(entity) then return end

    TriggerServerEvent('bd_parking:server:requestedImpound', VehToNet(entity))
end

---@param data { entity: integer }
local function impoundFromOxTarget(data)
    requestImpound(data.entity)
end

local function addTargetOption()
    if GetResourceState('ox_target') == 'started' then
        return exports.ox_target:addGlobalVehicle({
            {
                name = targetName,
                icon = targetIcon,
                label = locale('target.impound'),
                groups = sharedConfig.impoundJobs,
                distance = 2.5,
                onSelect = impoundFromOxTarget
            }
        })
    end

    if GetResourceState('qb-target') ~= 'started' then return end

    local jobs = {}

    for i = 1, #sharedConfig.impoundJobs do
        jobs[sharedConfig.impoundJobs[i]] = 0
    end

    exports['qb-target']:AddGlobalVehicle({
        options = {
            { icon = targetIcon, label = locale('target.impound'), job = jobs, action = requestImpound }
        },
        distance = 2.5
    })
end

---@param seconds number
---@return boolean
local function playImpoundProgress(seconds)
    return lib.progressCircle({
        duration = seconds * 1000,
        label = locale('progress.impounding'),
        position = 'bottom',
        canCancel = true,
        disable = { move = true, car = true, combat = true }
    })
end

---@param resource string
local function cleanUp(resource)
    if resource ~= cache.resource then return end

    if currentLot then exitLot() end

    if GetResourceState('qb-target') == 'started' then
        exports['qb-target']:RemoveGlobalVehicle(locale('target.impound'))
    end
end

keybind = lib.addKeybind({
    name = 'bd_parking_impound',
    description = locale('keybind.impound'),
    defaultKey = 'E',
    disabled = true,
    onPressed = openLot
})

for i = 1, #sharedConfig.impoundLots do
    local lot = sharedConfig.impoundLots[i]

    if lot.blip then createLotBlip(lot.coords) end

    lib.points.new({
        coords = lot.coords,
        distance = sharedConfig.impoundRadius,
        lot = i,
        onEnter = enterLot,
        onExit = exitLot
    })
end

addTargetOption()
lib.callback.register('bd_parking:client:impounding', playImpoundProgress)
AddEventHandler('onResourceStop', cleanUp)
