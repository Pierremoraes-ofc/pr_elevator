-- Execute with @pr_bridge/init.lua loaded; resolve this resource's locale explicitly.
local lang = pr_lib.locale('pr_elevator')
return {
    ['key_card_gold'] = {
        label = lang('items.vip'),
        weight = 10,
        type = 'item',
        unique = true,
        useable = true,
        shouldClose = true,
        combinable = nil,
        description = lang('items.vip_description')
    },
    ['key_card_security'] = {
        label = lang('items.security'),
        weight = 10,
        type = 'item',
        unique = true,
        useable = true,
        shouldClose = true,
        combinable = nil,
        description = lang('items.security_description')
    },
    ['key_card_ilegal'] = {
        label = lang('items.illegal'),
        weight = 10,
        type = 'item',
        unique = true,
        useable = true,
        shouldClose = true,
        combinable = nil,
        description = lang('items.illegal_description')
    },
}
