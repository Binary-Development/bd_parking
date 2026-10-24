local framework = require 'bridge.framework'
local garage = require 'bridge.garage'
local world = require 'server.modules.world'

---@alias VehicleStatus 'stored' | 'out' | 'held'

---@class OwnedVehicle
---@field key string
---@field plate string
---@field owner string
---@field model integer?
---@field props table
---@field status VehicleStatus

---@class StateColumn
---@field column string
---@field storedValue any
---@field outValue any
---@field heldValue? any
---@field lostValue? any
---@field anyStored? boolean

local schema = framework.schema
local vehicles = {}

local heldFlagColumns = { 'pound', 'impound', 'impounded' }

---@type StateColumn[]
local stateColumns = {}
local heldFlags = {}
local sql = {}
local fixedParams = {}
local ready = false

---@param value any
---@return any
local function normalizeFlag(value)
    if value == true then return 1 end
    if value == false then return 0 end

    return tonumber(value) or value
end

---@param value any
---@return boolean
local function isFlagSet(value)
    value = normalizeFlag(value)

    return value ~= nil and value ~= 0 and value ~= ''
end

---@param ... any[]
---@return any[]
local function joinParams(...)
    local joined = {}

    for i = 1, select('#', ...) do
        local list = select(i, ...)

        for j = 1, #list do
            joined[#joined + 1] = list[j]
        end
    end

    return joined
end

---@param columns table<string, true>
local function detectColumns(columns)
    local stateColumn = garage.stateColumn

    if stateColumn and columns[stateColumn.column] then
        stateColumns[#stateColumns + 1] = {
            column = stateColumn.column,
            storedValue = stateColumn.storedValue,
            outValue = stateColumn.outValue
        }
    end

    stateColumns[#stateColumns + 1] = {
        column = schema.state,
        storedValue = schema.storedValue,
        outValue = schema.outValue,
        heldValue = schema.heldValue,
        lostValue = schema.lostValue,
        anyStored = schema.anyStored
    }

    for i = 1, #heldFlagColumns do
        local column = heldFlagColumns[i]

        if columns[column] and column ~= schema.state then
            heldFlags[#heldFlags + 1] = column
        end
    end
end

---@param status 'stored' | 'out'
---@return string clause
---@return any[] params
local function buildStateSet(status)
    local parts, params = {}, {}

    for i = 1, #stateColumns do
        local state = stateColumns[i]
        local value = status == 'stored' and state.storedValue or state.outValue

        if value == nil then
            parts[#parts + 1] = ('`%s` = NULL'):format(state.column)
        else
            parts[#parts + 1] = ('`%s` = ?'):format(state.column)
            params[#params + 1] = value
        end
    end

    return table.concat(parts, ', '), params
end

---@return string storedWhere
---@return any[] storedParams
---@return string outWhere
---@return any[] outParams
local function buildStateWheres()
    local primary = stateColumns[1]
    local column = primary.column

    if primary.anyStored then
        return ('`%s` IS NOT NULL AND `%s` <> ?'):format(column, column), { primary.lostValue },
            ('(`%s` IS NULL OR `%s` = ?)'):format(column, column), { primary.lostValue }
    end

    return ('`%s` = ?'):format(column), { primary.storedValue },
        ('`%s` = ?'):format(column), { primary.outValue }
end

---@return string
local function buildPropsSet()
    if not schema.propsPath then
        return ('`%s` = ?'):format(schema.props)
    end

    return ('`%s` = JSON_SET(COALESCE(`%s`, \'{}\'), \'$.%s\', JSON_EXTRACT(?, \'$\'))'):format(
        schema.props, schema.props, schema.propsPath)
end

---@return string
local function buildHeldClear()
    local parts = {}

    for i = 1, #heldFlags do
        local column = heldFlags[i]

        parts[#parts + 1] = column == 'pound' and '`pound` = NULL' or ('`%s` = 0'):format(column)
    end

    return #parts > 0 and (', ' .. table.concat(parts, ', ')) or ''
end

---@param columns table<string, true>
---@return string
local function buildSelect(columns)
    local selected = {
        '`plate`',
        ('`%s` AS `owner`'):format(schema.owner),
        ('`%s` AS `props`'):format(schema.props)
    }

    if schema.model and columns[schema.model] then
        selected[#selected + 1] = ('`%s` AS `model`'):format(schema.model)
    end

    for i = 1, #stateColumns do
        selected[#selected + 1] = ('`%s`'):format(stateColumns[i].column)
    end

    for i = 1, #heldFlags do
        selected[#selected + 1] = ('`%s`'):format(heldFlags[i])
    end

    return table.concat(selected, ', ')
end

---@param columns table<string, true>
local function buildStatements(columns)
    local tableName = schema.table
    local selected = buildSelect(columns)
    local storedSet, storedSetParams = buildStateSet('stored')
    local outSet, outSetParams = buildStateSet('out')
    local storedWhere, storedWhereParams, outWhere, outWhereParams = buildStateWheres()

    fixedParams.storedSet = storedSetParams
    fixedParams.outSet = outSetParams
    fixedParams.storedWhere = storedWhereParams
    fixedParams.outWhere = outWhereParams

    sql.owned = ('SELECT %s FROM `%s` WHERE `%s` = ?'):format(selected, tableName, schema.owner)
    sql.byPlate = ('SELECT %s FROM `%s` WHERE `plate` = ? LIMIT 1'):format(selected, tableName)
    sql.hasAny = ('SELECT 1 FROM `%s` WHERE `%s` = ? LIMIT 1'):format(tableName, schema.owner)
    sql.outRows = ('SELECT %s FROM `%s` WHERE %s'):format(selected, tableName, outWhere)
    sql.store = ('UPDATE `%s` SET %s, %s WHERE `plate` = ?'):format(tableName, buildPropsSet(), storedSet)
    sql.release = ('UPDATE `%s` SET %s%s WHERE `plate` = ?'):format(tableName, storedSet, buildHeldClear())
    sql.claim = ('UPDATE `%s` SET %s WHERE `plate` = ? AND %s'):format(tableName, outSet, storedWhere)
    sql.markOut = ('UPDATE `%s` SET %s WHERE `plate` = ?'):format(tableName, outSet)
    sql.returnMany = ('UPDATE `%s` SET %s WHERE `plate` IN (?)'):format(tableName, storedSet)

    if framework.claimsOnPark then
        sql.register = ('INSERT INTO `%s` (`plate`, `%s`, `%s`, `%s`, `%s`) VALUES (?, ?, ?, ?, ?)'):format(
            tableName, schema.owner, schema.model, schema.props, schema.state)
    end
end

function vehicles.init()
    local rows = MySQL.query.await(
        'SELECT `COLUMN_NAME` AS `name` FROM information_schema.COLUMNS WHERE `TABLE_SCHEMA` = DATABASE() AND `TABLE_NAME` = ?',
        { schema.table })

    assert(rows and #rows > 0, ("vehicle table '%s' wasn't found in your database, is your framework set up?"):format(schema.table))

    local columns = {}

    for i = 1, #rows do
        columns[rows[i].name] = true
    end

    assert(columns[schema.state], ("column '%s' is missing from '%s'"):format(schema.state, schema.table))

    detectColumns(columns)
    buildStatements(columns)
    ready = true
end

---@param raw any
---@return table
local function decodeProps(raw)
    local data = raw

    if type(raw) == 'string' then
        local ok, decoded = pcall(json.decode, raw)
        data = ok and decoded or nil
    end

    if type(data) ~= 'table' then return {} end
    if not schema.propsPath then return data end

    local nested = data[schema.propsPath]

    return type(nested) == 'table' and nested or {}
end

---@param row table
---@return VehicleStatus
local function readStatus(row)
    for i = 1, #heldFlags do
        if isFlagSet(row[heldFlags[i]]) then return 'held' end
    end

    for i = 1, #stateColumns do
        local state = stateColumns[i]

        if state.heldValue ~= nil and normalizeFlag(row[state.column]) == state.heldValue then return 'held' end
    end

    local primary = stateColumns[1]
    local value = normalizeFlag(row[primary.column])

    if primary.anyStored then
        return (value ~= nil and value ~= primary.lostValue) and 'stored' or 'out'
    end

    return value == primary.storedValue and 'stored' or 'out'
end

---@param row table
---@return OwnedVehicle
local function toVehicle(row)
    local props = decodeProps(row.props)

    return {
        key = row.plate,
        plate = world.normalizePlate(row.plate),
        owner = tostring(row.owner),
        model = world.toModelHash(props.model or row.model),
        props = props,
        status = readStatus(row)
    }
end

---@param owner string
---@return OwnedVehicle[]
function vehicles.getOwned(owner)
    assert(ready, 'vehicle store used before the database was ready')

    local rows = MySQL.query.await(sql.owned, { owner }) or {}
    local owned = {}

    for i = 1, #rows do
        owned[i] = toVehicle(rows[i])
    end

    return owned
end

---@param plate string
---@return OwnedVehicle?
function vehicles.get(plate)
    assert(ready, 'vehicle store used before the database was ready')

    local row = MySQL.single.await(sql.byPlate, { plate })

    return row and toVehicle(row)
end

---@param owner string
---@return boolean
function vehicles.hasAny(owner)
    return MySQL.scalar.await(sql.hasAny, { owner }) ~= nil
end

---@param key string
---@param props table
function vehicles.store(key, props)
    MySQL.update.await(sql.store, joinParams({ json.encode(props) }, fixedParams.storedSet, { key }))
end

---@param key string
function vehicles.release(key)
    MySQL.update.await(sql.release, joinParams(fixedParams.storedSet, { key }))
end

---@param key string
---@return boolean claimed false when the vehicle was no longer stored
function vehicles.claimOut(key)
    local affected = MySQL.update.await(sql.claim, joinParams(fixedParams.outSet, { key }, fixedParams.storedWhere))

    return affected == 1
end

---@param key string
function vehicles.markOut(key)
    MySQL.update.await(sql.markOut, joinParams(fixedParams.outSet, { key }))
end

---@param owner string
---@param plate string
---@param model integer
---@param props table
function vehicles.register(owner, plate, model, props)
    assert(sql.register, 'this framework does not let players register vehicles by parking them')

    MySQL.insert.await(sql.register, { plate, owner, model, json.encode(props), schema.outValue })
end

---@param shouldStayOut fun(plate: string): boolean
---@return integer returned
function vehicles.returnAllOut(shouldStayOut)
    local rows = MySQL.query.await(sql.outRows, fixedParams.outWhere) or {}
    local keys = {}

    for i = 1, #rows do
        local row = rows[i]

        if readStatus(row) == 'out' and not shouldStayOut(world.normalizePlate(row.plate)) then
            keys[#keys + 1] = row.plate
        end
    end

    if #keys > 0 then
        MySQL.update.await(sql.returnMany, joinParams(fixedParams.storedSet, { keys }))
    end

    return #keys
end

return vehicles
