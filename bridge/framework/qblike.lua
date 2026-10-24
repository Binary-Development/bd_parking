---@param getPlayer fun(source: integer): table?
---@return FrameworkBridge
local function createBridge(getPlayer)
    ---@type FrameworkBridge
    local bridge = {
        schema = {
            table = 'player_vehicles',
            owner = 'citizenid',
            props = 'mods',
            model = 'vehicle',
            state = 'state',
            storedValue = 1,
            outValue = 0,
            heldValue = 2
        }
    }

    function bridge.getOwner(source)
        local player = getPlayer(source)

        return player and player.PlayerData.citizenid
    end

    function bridge.getName(source)
        local player = getPlayer(source)
        if not player then return GetPlayerName(source) end

        local info = player.PlayerData.charinfo

        return ('%s %s'):format(info.firstname, info.lastname)
    end

    function bridge.hasJob(source, jobs)
        local player = getPlayer(source)

        return player ~= nil and lib.table.contains(jobs, player.PlayerData.job.name)
    end

    function bridge.removeMoney(source, account, amount, reason)
        local player = getPlayer(source)
        if not player or (player.PlayerData.money[account] or 0) < amount then return false end

        return player.Functions.RemoveMoney(account, amount, reason) ~= false
    end

    return bridge
end

return createBridge
