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
    'client/menu_exports.lua',
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


--[[

precisa criar o item para o ox_inventory
precisa criar a opçao de puxar players proximos
precisa add ao menu para editar o elevador
precisa edd ao menu para dar o item certinho
precisa add a funcao do elevador para puxar veiculo caso o elevador seja de veiculo também!

]]
