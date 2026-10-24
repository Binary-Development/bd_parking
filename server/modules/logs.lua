local serverConfig = require 'config.server'
local framework = require 'bridge.framework'

local logs = {}

local colors = {
    success = 5763719,
    info = 3447003,
    warning = 16753920,
    danger = 15548997
}

---@class LogField
---@field name string
---@field value string
---@field inline? boolean

---@class LogEntry
---@field action string
---@field color 'success' | 'info' | 'warning' | 'danger'
---@field plate? string
---@field model? integer
---@field price? number
---@field coords? vector3
---@field vehicleOwner? string
---@field copiesRemoved? integer

---@param status integer
local function checkResponse(status)
    if status >= 200 and status < 300 then return end

    lib.print.warn(('discord webhook returned status %s, check the webhook in config/server.lua'):format(status))
end

---@param coords vector3
---@return string
local function formatCoords(coords)
    return ('%.2f, %.2f, %.2f'):format(coords.x, coords.y, coords.z)
end

---@param source integer
---@return LogField[]
local function getPlayerFields(source)
    if source == 0 then
        return { { name = 'Player', value = 'Server console', inline = true } }
    end

    local discord = GetPlayerIdentifierByType(source, 'discord')

    return {
        { name = 'Player', value = ('%s (ID %s)'):format(GetPlayerName(source), source), inline = true },
        { name = 'Character', value = framework.getName(source) or 'Unknown', inline = true },
        { name = 'Owner ID', value = framework.getOwner(source) or 'Unknown', inline = true },
        { name = 'Discord', value = discord and ('<@%s>'):format(discord:sub(9)) or 'Not linked', inline = true },
        { name = 'License', value = GetPlayerIdentifierByType(source, 'license') or 'None', inline = true },
    }
end

---@param source integer
---@param entry LogEntry
function logs.send(source, entry)
    if type(serverConfig.webhook) ~= 'string' or serverConfig.webhook == '' then return end

    local fields = getPlayerFields(source)

    if entry.plate then
        fields[#fields + 1] = { name = 'Plate', value = entry.plate, inline = true }
    end

    if entry.model then
        fields[#fields + 1] = { name = 'Model hash', value = tostring(entry.model), inline = true }
    end

    if entry.price then
        fields[#fields + 1] = { name = 'Price', value = ('$%s'):format(entry.price), inline = true }
    end

    if entry.vehicleOwner then
        fields[#fields + 1] = { name = 'Vehicle owner', value = entry.vehicleOwner, inline = true }
    end

    if entry.copiesRemoved and entry.copiesRemoved > 0 then
        fields[#fields + 1] = { name = 'Stray copies removed', value = tostring(entry.copiesRemoved), inline = true }
    end

    local coords = entry.coords or (source ~= 0 and GetEntityCoords(GetPlayerPed(source)))

    if coords then
        fields[#fields + 1] = { name = 'Location', value = formatCoords(coords), inline = false }
    end

    PerformHttpRequest(serverConfig.webhook, checkResponse, 'POST', json.encode({
        username = 'Parking',
        embeds = {
            {
                title = locale(entry.action),
                color = colors[entry.color],
                fields = fields,
                footer = { text = cache.resource },
                timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ')
            }
        }
    }), { ['Content-Type'] = 'application/json' })
end

return logs
