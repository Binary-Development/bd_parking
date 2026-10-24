local types = require 'shared.types'

local vehicle = {}

local submarines = {
    [`submersible` % 4294967296] = true,
    [`submersible2` % 4294967296] = true,
    [`kosatka` % 4294967296] = true,
    [`avisa` % 4294967296] = true
}

---@param model any
---@return string?
function vehicle.getType(model)
    if type(model) ~= 'number' or not IsModelInCdimage(model) or not IsModelAVehicle(model) then return end

    if IsThisModelAHeli(model) then return 'heli' end
    if IsThisModelAPlane(model) then return 'plane' end
    if submarines[model % 4294967296] then return 'submarine' end
    if IsThisModelABoat(model) or IsThisModelAJetski(model) then return 'boat' end
    if IsThisModelABike(model) or IsThisModelABicycle(model) then return 'bike' end
    if IsThisModelATrain(model) then return 'train' end

    return 'automobile'
end

---@param model integer?
---@return boolean
function vehicle.isAllowed(model)
    local vehicleType = vehicle.getType(model)

    return vehicleType == nil or types.isAllowed(vehicleType)
end

---@param model integer?
---@return string
function vehicle.getLabel(model)
    if not model then return '?' end

    local name = GetDisplayNameFromVehicleModel(model)
    local label = GetLabelText(name)

    if label ~= 'NULL' then return label end

    return name ~= 'CARNOTFOUND' and name or tostring(model)
end

---@param listed { plate: string, model: integer? }
---@return string
function vehicle.getTitle(listed)
    return ('%s (%s)'):format(vehicle.getLabel(listed.model), listed.plate)
end

return vehicle
