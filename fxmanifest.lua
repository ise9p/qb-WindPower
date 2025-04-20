fx_version 'cerulean'
game 'gta5'

author 'Se9p Script'
description 'A FiveM resource for QBCore that adds purchasable power stations with management features.'
version '1.0.0'

shared_scripts {
    'config.lua',
    '@ox_lib/init.lua',
}

client_scripts {
    'client/client.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/server.lua'
}


dependencies {
    'qb-weathersync',
}

lua54 'yes'
