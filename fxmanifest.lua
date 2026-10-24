fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'bd_parking'
author 'eugene'
description 'Personal parking spots and impound lots'
version '1.0.0'

ox_libs { 'locale' }

shared_script '@ox_lib/init.lua'

client_scripts {
    'client/*.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/*.lua'
}

files {
    'config/shared.lua',
    'shared/*.lua',
    'client/modules/*.lua',
    'locales/*.json'
}
