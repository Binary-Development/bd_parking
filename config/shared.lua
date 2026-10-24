return {
    -- Cars, bikes and trucks always work. Turn these on to also let boats or helicopters and planes
    -- use parking spots, impound lots and the impound command.
    allowBoats = false,
    allowAircraft = false,

    -- How see-through the preview car at your spot is. 0 is invisible, 255 is solid.
    previewAlpha = 150,

    -- Jobs that can impound vehicles (target option on vehicles, or the impound command).
    -- Anyone with the ace "bd_parking.impound" can impound too, handy for standalone servers.
    impoundJobs = { 'police', 'ambulance' },

    -- How long impounding takes, in seconds.
    impoundTime = 3.5,

    -- How close (meters) you need to stand to an impound lot to open it.
    impoundRadius = 15.0,

    -- Map icon used for every impound lot that has blip = true.
    -- Sprites and colors: https://docs.fivem.net/docs/game-references/blips/
    impoundBlip = {
        label = 'Impound',
        sprite = 357,
        color = 7,
        scale = 0.8
    },

    -- Impound lots.
    -- coords: where players walk up to open the menu.
    -- spawn: where the recovered car appears (x, y, z, heading).
    -- blip: show it on the map or not.
    impoundLots = {
        {
            coords = vec3(490.19, -1453.63, 29.27),
            spawn = vec4(490.49, -1445.98, 29.23, 14.42),
            blip = true
        },
    },
}
