local Ox = require '@ox_core.lib.init'

---@type FrameworkBridge
local ox = {
    schema = {
        table = 'vehicles',
        owner = 'owner',
        props = 'data',
        propsPath = 'properties',
        model = 'model',
        state = 'stored',
        storedValue = 'parking',
        outValue = nil,
        lostValue = 'impound',
        anyStored = true
    }
}

function ox.getOwner(source)
    local player = Ox.GetPlayer(source)

    return player and player.charId and tostring(player.charId)
end

function ox.getName(source)
    local player = Ox.GetPlayer(source)
    local firstName = player and player.get('firstName')
    if not firstName then return GetPlayerName(source) end

    return ('%s %s'):format(firstName, player.get('lastName') or '')
end

function ox.hasJob(source, jobs)
    local player = Ox.GetPlayer(source)

    return player ~= nil and player.getGroup(jobs) ~= nil
end

function ox.removeMoney(source, account, amount, reason)
    if account == 'cash' then
        if exports.ox_inventory:GetItemCount(source, 'money') < amount then return false end

        return exports.ox_inventory:RemoveItem(source, 'money', amount) == true
    end

    local player = Ox.GetPlayer(source)
    local bank = player and player.getAccount()
    if not bank then return false end

    local result = bank.removeBalance({ amount = amount, message = reason })

    return result == true or type(result) == 'table' and result.success == true
end

function ox.beforeDespawn(vehicle)
    local oxVehicle = Ox.GetVehicleFromEntity(vehicle)
    if not oxVehicle then return end

    oxVehicle.setStored('parking', true)
end

return ox
