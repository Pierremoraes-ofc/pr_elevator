fx_version 'cerulean'

game 'gta5'

author 'Pinel Devs - PierreMoraes'
description 'The best Elevator Script'
repository 'https://github.com/Pierremoraes-ofc/pr_elevator'

version '1.1.2'

dependency 'pr_bridge'

shared_scripts {
    '@pr_bridge/init.lua',
    'shared/config.lua',
    'shared/settings.lua',
    'locale/*.lua'
}

client_scripts {
    'client/settings.lua',
    'client/dui.lua',
    'client/main.lua',
    'client/menu.lua',
    'client/menu_exports.lua',
}

server_scripts {
    'server/settings.lua',
    'server/version.lua',
    'server/main.lua',
    'server/menu.lua',
}


ui_page 'ui/ui.html'

files {
    'ui/ui.html',
    'ui/*.*'
}


--[[


]]
