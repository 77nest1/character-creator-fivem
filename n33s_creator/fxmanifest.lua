fx_version 'cerulean'
game 'gta5'

lua54 'yes'

author 'n33st'
description 'character creator fivem'
version '1.0.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/assets/avatar_male.svg',
    'html/assets/avatar_female.svg'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

dependency 'oxmysql'
