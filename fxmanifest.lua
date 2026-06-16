fx_version 'cerulean'

game 'gta5'

author 'Pinel Devs - PierreMoraes'
description 'The best Elevator Script'

version '1.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@pr_bridge/init.lua',
    'shared/config.lua',
    'locale/*.lua'
}

client_scripts {
    'client/dui.lua',
    'client/main.lua',
    'client/menu.lua',
}

server_scripts {
    'server/main.lua',
    'server/menu.lua',
}


ui_page 'ui/ui.html'

files {
    'ui/ui.html',
    'ui/*.*'
}
