local revision=-1
local lang=pr_lib.locale()
local function apply(value)
    local normalized=ElevatorSettings.normalize(value)
    local incoming=type(value)=='table' and tonumber(value.revision)
    if not normalized or not incoming or incoming<=revision then return false end
    revision=incoming;normalized.revision=incoming
    pr_lib.cache.set('pr_elevator:settings',normalized)
    PR.Target=normalized.mode
    PR.RespectWalls=normalized.respectWalls
    PR.KeypadInteractDistance=normalized.distance
    PR.KeypadInteractOffset=vector3(0,-normalized.frontOffset,0.03)
    TriggerEvent('pr_elevator:client:refreshElevators')
    return true
end
RegisterNetEvent('pr_elevator:client:settings',apply)
CreateThread(function()
    for _=1,5 do
        local ok,value=pcall(pr_lib.callback.await,'pr_elevator:server:getSettings',15000)
        if ok and value then apply(value);return end
        Wait(1000)
    end
    print(lang('debug.settings_sync_failed'))
end)
function OpenElevatorSettingsMenu(onReturn)
    local function back() if type(onReturn)=='function' then onReturn() end end
    CreateThread(function()
        local value,allowed=pr_lib.callback.await('pr_elevator:server:getSettings',15000)
        if not value or not allowed then
            pr_lib.Notify({title=lang('menu.settings'),description=lang('menu.settings_denied'),type='error'})
            back()
            return
        end
        local input=pr_lib.menu.InputDialog(lang('menu.settings'),{
            {type='select',label=lang('menu.settings_mode'),required=true,default=value.mode,options={
                {value='target',label=lang('menu.settings_target')}, {value='interact',label=lang('menu.settings_interact')},
                {value='both',label=lang('menu.settings_both')}}},
            {type='checkbox',label=lang('menu.settings_walls'),checked=value.respectWalls},
            {type='number',label=lang('menu.settings_offset'),required=true,default=value.frontOffset,min=0.05,max=1,step=0.01},
            {type='number',label=lang('menu.settings_distance'),required=true,default=value.distance,min=0.5,max=5,step=0.1}
        })
        if not input then back();return end
        local saved,result=pr_lib.callback.await('pr_elevator:server:saveSettings',15000,
            {mode=input[1],respectWalls=input[2]==true,frontOffset=input[3],distance=input[4],revision=value.revision})
        if saved then apply(result) end
        pr_lib.Notify({title=lang('menu.settings'),description=lang(saved and 'menu.settings_saved' or 'menu.settings_failed'),type=saved and 'success' or 'error'})
        back()
    end)
end
