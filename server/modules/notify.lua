local notify = {}

---@param source integer
---@param kind 'success' | 'error' | 'inform'
---@param key string
---@param ... any
function notify.send(source, kind, key, ...)
    local message = locale(key, ...)

    if source == 0 then
        return lib.print.info(message)
    end

    TriggerClientEvent('ox_lib:notify', source, {
        title = locale('title'),
        description = message,
        type = kind
    })
end

---@param source integer
---@param key string
---@param ... any
---@return false
function notify.fail(source, key, ...)
    notify.send(source, 'error', key, ...)

    return false
end

return notify
