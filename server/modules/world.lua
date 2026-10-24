local world = {}

---@param plate any
---@return string
function world.normalizePlate(plate)
    if type(plate) ~= 'string' then return '' end

    return plate:match('^%s*(.-)%s*$'):upper()
end

---@param model any
---@return integer?
function world.toModelHash(model)
    local hash = type(model) == 'string' and joaat(model) or tonumber(model)

    return hash and hash % 4294967296
end

---@param plate string
---@return integer[]
function world.findByPlate(plate)
    local found = {}
    local vehicles = GetAllVehicles()

    for i = 1, #vehicles do
        local vehicle = vehicles[i]

        if world.normalizePlate(GetVehicleNumberPlateText(vehicle)) == plate then
            found[#found + 1] = vehicle
        end
    end

    return found
end

---@return table<string, integer>
function world.indexPlates()
    local index = {}
    local vehicles = GetAllVehicles()

    for i = 1, #vehicles do
        local vehicle = vehicles[i]

        index[world.normalizePlate(GetVehicleNumberPlateText(vehicle))] = vehicle
    end

    return index
end

---@param vehicle integer
---@return boolean
function world.hasPlayerInside(vehicle)
    local players = GetPlayers()

    for i = 1, #players do
        local ped = GetPlayerPed(players[i])

        if ped ~= 0 and GetVehiclePedIsIn(ped, false) == vehicle then return true end
    end

    return false
end

---@param plate string
---@return boolean
function world.isPlateInUse(plate)
    local copies = world.findByPlate(plate)

    for i = 1, #copies do
        if world.hasPlayerInside(copies[i]) then return true end
    end

    return false
end

---@param plate string
---@param keep? integer
---@return integer removed
function world.removeCopies(plate, keep)
    local copies = world.findByPlate(plate)
    local removed = 0

    for i = 1, #copies do
        local copy = copies[i]

        if copy ~= keep then
            DeleteEntity(copy)
            removed += 1
        end
    end

    return removed
end

---@param coords vector3
---@param radius number
---@return boolean
function world.isAreaBlocked(coords, radius)
    local vehicles = GetAllVehicles()

    for i = 1, #vehicles do
        if #(GetEntityCoords(vehicles[i]) - coords) < radius then return true end
    end

    return false
end

---@param source integer
---@param radius number
---@return integer?
function world.getClosestVehicle(source, radius)
    local ped = GetPlayerPed(source)
    if ped == 0 then return end

    local origin = GetEntityCoords(ped)
    local vehicles = GetAllVehicles()
    local closest, closestDistance = nil, radius

    for i = 1, #vehicles do
        local vehicle = vehicles[i]
        local distance = #(GetEntityCoords(vehicle) - origin)

        if distance < closestDistance then
            closest, closestDistance = vehicle, distance
        end
    end

    return closest
end

---@param source integer
---@param coords vector3
---@param range number
---@return boolean
function world.isPlayerNear(source, coords, range)
    local ped = GetPlayerPed(source)

    return ped ~= 0 and #(GetEntityCoords(ped) - coords) <= range
end

---@param source integer
---@return boolean
function world.isOnFoot(source)
    return GetVehiclePedIsIn(GetPlayerPed(source), false) == 0
end

---@param source integer
---@return integer? vehicle the vehicle the player is driving
function world.getDrivenVehicle(source)
    local ped = GetPlayerPed(source)
    if ped == 0 then return end

    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped then return end

    return vehicle
end

return world
