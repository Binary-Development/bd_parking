# bd_parking

Players buy their own parking spot anywhere on the map and keep their cars there. Park the car you're driving, open your list, and pick one to take back out. You see a see-through preview of the car at your spot before it spawns, so you know you grabbed the right one.

Cars that go missing end up at an impound lot, where players can pay to get them back. Police (or any job you pick) can impound cars too.

Works with ESX, QBCore, Qbox, ox_core and ND_Core, or standalone.

## What it does

- Buy a parking spot wherever you're standing. Buying again moves it.
- Park the car you're driving and take any of your cars out from a menu.
- Ghost preview of the car at your spot before you take it out.
- Won't let a car come out twice. If the plate is already driving around, it says so, and leftover copies get cleaned up.
- Cars that are out can be marked on your map. Lost cars point you to the nearest impound lot.
- Impound lots where players recover lost or impounded cars for a fee.
- Police can impound cars with ox_target, qb-target or `/impound`.
- Cars left out get sent back to parking when the server restarts.
- Admins can send any car back with `/apark`.
- Cars, bikes and trucks only by default. Boats and aircraft can be turned on.
- Discord logs for everything.
- All text is in `locales/en.json` if you want to change the wording.

## What you need

- [ox_lib](https://github.com/overextended/ox_lib) 3.37 or newer
- [oxmysql](https://github.com/overextended/oxmysql)

That's it. Everything below is optional and gets picked up on its own.

**Frameworks:** ESX, QBCore, Qbox, ox_core, ND_Core, or standalone

**Keys:** [bd_carkeys](https://github.com/Binary-Development/bd_carkeys), wasabi_carlock, mk_vehiclekeys, brutal_keys, okokGarage keys, qbx_vehiclekeys, qb-vehiclekeys, ND_Core keys

**Garages:** jg-advancedgarages stays in sync with parked cars. okokGarage works too (read the note below). lb-phone works without any setup.

## Install

1. Drop `bd_parking` into your resources folder.
2. Start it after your framework, keys and garage:

```cfg
ensure ox_lib
ensure oxmysql
ensure bd_parking
```

3. Look through `config/server.lua` and `config/shared.lua`, then restart.

You don't need to import any SQL. The script makes its own tables the first time it starts and uses your framework's vehicle table for everything else.

## Config

Both config files have a comment on every setting, so most of it explains itself. The ones people usually change:

- **Prices:** `prices.spot` and `prices.impound` in `config/server.lua`. Set either to 0 to make it free.
- **Cash or bank:** `payWith` in `config/server.lua`.
- **Impound lots:** `impoundLots` in `config/shared.lua`. Each lot needs where players walk up (`coords`) and where the car spawns (`spawn`, with heading).
- **Who can impound:** `impoundJobs` in `config/shared.lua`. You can also give the `bd_parking.impound` ace, which is handy on standalone servers:

```cfg
add_ace group.police bd_parking.impound allow
```

- **Boats and aircraft:** `allowBoats` and `allowAircraft` in `config/shared.lua`.
- **Logs:** paste a Discord webhook into `webhook` in `config/server.lua`.

Framework, keys and garage are all set to `auto`. Only change them if you run more than one of something and it picks the wrong one. If you type a name it doesn't know, it'll tell you the valid ones in the console.

### Running standalone?

Without a framework there's no garage table, money or jobs to use, so a few things work differently:

- Any car you drive becomes yours the first time you park it.
- Spots and impound recovery are free.
- Only players with the `bd_parking.impound` ace can impound.

### Using okokGarage?

okokGarage likes to impound cars right after they get parked. Turn these off in okokGarage's config:

```lua
Config.VehicleImpoundedOnDV = false
Config.SetVehiclesImpoundedOnStart = false
```

## Commands

| Command | What it does |
|---------|--------------|
| `/v buy` | Buy a spot where you're standing, or move yours here |
| `/v park` | Park the car you're driving |
| `/v` | Open your car list |
| `/impound` | Impound the car next to you (impound jobs only) |
| `/apark [plate]` | Send any car back to parking (admins) |

At an impound lot, press **E** to open it. Players can rebind it in their FiveM key bindings.

## Support

Found a bug or have an idea? Open an issue here or come find us on Discord.

**Discord:** [discord.gg/binary](https://discord.gg/binary)  
**Website and store:** [binarydevs.xyz](https://binarydevs.xyz/)
