local serverConfig = require 'config.server'
local framework = require 'bridge.framework'
local notify = require 'server.modules.notify'

local players = {}

---@param source integer
---@return string? owner nil after telling the player their character isn't loaded
function players.requireOwner(source)
    local owner = framework.getOwner(source)

    if not owner then
        notify.fail(source, 'notify.not_loaded')
    end

    return owner
end

---@param source integer
---@param propertyId any
---@return boolean
local function isListedInside(source, propertyId)
    local occupants = exports.nolag_properties:GetPlayersInProperty(propertyId)
    if type(occupants) ~= 'table' then return false end

    for i = 1, #occupants do
        if tonumber(occupants[i]) == source then return true end
    end

    return false
end

---@param source integer
---@param owner string
---@return boolean
local function isInsideProperty(source, owner)
    if GetPlayerRoutingBucket(source) ~= 0 then return true end
    if GetResourceState('nolag_properties') ~= 'started' then return false end

    local properties = exports.nolag_properties:GetAllProperties(owner, 'user', true)
    if type(properties) ~= 'table' then return false end

    for i = 1, #properties do
        local entry = properties[i]

        if entry and entry.id and isListedInside(source, entry.id) then return true end
    end

    return false
end

---@param source integer
---@param owner string
---@return boolean blocked
function players.isBlockedByProperty(source, owner)
    if not serverConfig.blockInsideProperties or not isInsideProperty(source, owner) then return false end

    notify.fail(source, 'notify.inside_property')

    return true
end

---@param source integer
---@param amount number
---@param reason string
---@return boolean paid
function players.charge(source, amount, reason)
    if amount <= 0 then return true end

    if framework.removeMoney(source, serverConfig.payWith, amount, reason) then return true end

    return notify.fail(source, 'notify.no_money', amount)
end

---@param source integer
---@param jobs string[]
---@return boolean
function players.canImpound(source, jobs)
    return IsPlayerAceAllowed(source, 'bd_parking.impound') or framework.hasJob(source, jobs)
end

return players
