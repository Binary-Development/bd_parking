return {
    -- Which framework you run. Leave it on 'auto' and it gets detected.
    -- Options: 'auto', 'esx', 'qbcore', 'qbox', 'ox', 'nd', 'standalone'
    framework = 'auto',

    -- Which vehicle keys script gives keys when a car is taken out. 'auto' finds it for you.
    -- Options: 'auto', 'bd', 'wasabi', 'mk', 'brutal', 'okok', 'qbox', 'qbcore', 'nd', 'none'
    -- 'okok' is okokGarage's own keys (Config.UseOkokVehicleKeys = true in okokGarage).
    keys = 'auto',

    -- Garage sync. 'auto' finds jg-advancedgarages and keeps parked cars in sync with it.
    -- Options: 'auto', 'jg', 'none'
    -- okokGarage and other garages work through your framework's normal stored flag, nothing to set here.
    -- okokGarage users: in okokGarage's config set Config.VehicleImpoundedOnDV = false and
    -- Config.SetVehiclesImpoundedOnStart = false, or okok can impound cars right after you park them.
    garage = 'auto',

    -- Command names, without the slash.
    -- parking: /v buy, /v park, /v list
    -- adminPark: /apark [plate] sends any vehicle back to parking
    -- impound: impounds the vehicle next to you (police and the jobs in config/shared.lua)
    commands = {
        parking = 'v',
        adminPark = 'apark',
        impound = 'impound'
    },

    -- Who can use the admin park command. These are ace groups from your server.cfg.
    adminGroups = { 'group.admin' },

    -- Prices in dollars. Set to 0 to make it free.
    prices = {
        spot = 250,
        impound = 250
    },

    -- Where the money comes from: 'cash' or 'bank'.
    payWith = 'cash',

    -- How close (meters) the car has to be to your spot to park it.
    parkRadius = 10.0,

    -- How close (meters) you have to be to your spot to take a car out.
    -- Keep this under 400, the game can't hand a car to a player further away than that.
    takeOutRange = 300.0,

    -- Put every car that was left out back in parking when the server starts.
    -- Impounded cars stay impounded.
    -- With jg-advancedgarages this also skips jg's return fee for cars left out, turn it off if you want that fee.
    returnOnRestart = true,

    -- Stop players from buying, parking or taking out cars while inside a property
    -- (another routing bucket, or a nolag_properties property).
    -- Turn this off if your server uses routing buckets for other things, like lobbies.
    blockInsideProperties = true,

    -- Discord webhook for logs. Leave empty to turn logs off.
    webhook = ''
}
