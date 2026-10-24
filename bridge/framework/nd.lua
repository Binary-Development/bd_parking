local core = exports.ND_Core

---@type FrameworkBridge
local nd = {
    schema = {
        table = 'nd_vehicles',
        owner = 'owner',
        props = 'properties',
        state = 'stored',
        storedValue = 1,
        outValue = 0
    }
}

function nd.getOwner(source)
    local player = core:getPlayer(source)

    return player and player.id and tostring(player.id)
end

function nd.getName(source)
    local player = core:getPlayer(source)

    return player and player.fullname or GetPlayerName(source)
end

function nd.hasJob(source, jobs)
    local player = core:getPlayer(source)
    local job = player and player.job

    return job ~= nil and lib.table.contains(jobs, type(job) == 'table' and job.name or job)
end

function nd.removeMoney(source, account, amount, reason)
    local player = core:getPlayer(source)
    if not player or (player[account] or 0) < amount then return false end

    player.deductMoney(account, amount, reason)

    return true
end

return nd
