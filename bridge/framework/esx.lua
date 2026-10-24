local ESX = exports.es_extended:getSharedObject()

local accounts = {
    cash = 'money',
    bank = 'bank'
}

---@type FrameworkBridge
local esx = {
    schema = {
        table = 'owned_vehicles',
        owner = 'owner',
        props = 'vehicle',
        state = 'stored',
        storedValue = 1,
        outValue = 0,
        heldValue = 2
    }
}

function esx.getOwner(source)
    local player = ESX.GetPlayerFromId(source)

    return player and player.identifier
end

function esx.getName(source)
    local player = ESX.GetPlayerFromId(source)

    return player and player.getName() or GetPlayerName(source)
end

function esx.hasJob(source, jobs)
    local player = ESX.GetPlayerFromId(source)
    local job = player and player.getJob()

    return job ~= nil and lib.table.contains(jobs, job.name)
end

function esx.removeMoney(source, account, amount, reason)
    local player = ESX.GetPlayerFromId(source)
    if not player then return false end

    local name = accounts[account]
    local balance = player.getAccount(name)
    if not balance or balance.money < amount then return false end

    player.removeAccountMoney(name, amount, reason)

    return true
end

return esx
