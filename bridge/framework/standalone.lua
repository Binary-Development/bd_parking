---@type FrameworkBridge
local standalone = {
    schema = {
        table = 'bd_parking_vehicles',
        owner = 'owner',
        props = 'props',
        model = 'model',
        state = 'stored',
        storedValue = 1,
        outValue = 0
    },
    claimsOnPark = true,
    setupQuery = [[
        CREATE TABLE IF NOT EXISTS `bd_parking_vehicles` (
            `plate` VARCHAR(16) NOT NULL,
            `owner` VARCHAR(100) NOT NULL,
            `model` BIGINT NULL,
            `props` LONGTEXT NULL,
            `stored` TINYINT NOT NULL DEFAULT 0,
            PRIMARY KEY (`plate`),
            KEY `owner` (`owner`)
        )
    ]]
}

function standalone.getOwner(source)
    return GetPlayerIdentifierByType(source, 'license')
end

function standalone.getName(source)
    return GetPlayerName(source)
end

function standalone.hasJob()
    return false
end

function standalone.removeMoney()
    return true
end

return standalone
