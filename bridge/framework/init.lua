local pick = require 'bridge.pick'
local serverConfig = require 'config.server'

---@class VehicleSchema
---@field table string
---@field owner string
---@field props string
---@field propsPath? string
---@field model? string
---@field state string
---@field storedValue any
---@field outValue any
---@field heldValue? any
---@field lostValue? any
---@field anyStored? boolean

---@class FrameworkBridge
---@field schema VehicleSchema
---@field setupQuery? string
---@field claimsOnPark? boolean
---@field getOwner fun(source: integer): string?
---@field getName fun(source: integer): string
---@field hasJob fun(source: integer, jobs: string[]): boolean
---@field removeMoney fun(source: integer, account: 'cash' | 'bank', amount: number, reason: string): boolean
---@field beforeDespawn? fun(vehicle: integer)

local name = pick.choose({
    kind = 'framework',
    setting = serverConfig.framework,
    options = { 'esx', 'qbcore', 'qbox', 'ox', 'nd', 'standalone' },
    detection = {
        { resource = 'qbx_core', name = 'qbox' },
        { resource = 'es_extended', name = 'esx' },
        { resource = 'ox_core', name = 'ox' },
        { resource = 'ND_Core', name = 'nd' },
        { resource = 'qb-core', name = 'qbcore' },
    },
    fallback = 'standalone'
})

---@type FrameworkBridge
return require(('bridge.framework.%s'):format(name))
