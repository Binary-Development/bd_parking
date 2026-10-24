local notify = require 'server.modules.notify'

local locks = {}

local held = {}

---@param source integer
---@param fn fun(source: integer, ...): any
---@param ... any
---@return boolean acquired false when the player already has a request running
---@return any result
local function run(source, fn, ...)
    if held[source] then return false end

    held[source] = true

    local ok, result = pcall(fn, source, ...)

    held[source] = nil

    assert(ok, result)

    return true, result
end

---@param fn fun(source: integer, ...): any
---@return fun(source: integer, ...): any
function locks.perPlayer(fn)
    ---@param source integer
    ---@param ... any
    ---@return any
    local function locked(source, ...)
        local acquired, result = run(source, fn, ...)
        if not acquired then return notify.fail(source, 'notify.busy') end

        return result
    end

    return locked
end

local function releasePlayer()
    held[source] = nil
end

AddEventHandler('playerDropped', releasePlayer)

return locks
