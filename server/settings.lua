local path='@pr_elevator/data/settings.json'
local defaults={mode='target',respectWalls=true,frontOffset=0.18,distance=2.0}
local ok,loaded=pcall(pr_lib.loadJson,path,true)
local settings=ok and ElevatorSettings.normalize(loaded) or nil
if not settings then
    settings=defaults
    print(pr_lib.locale()('debug.settings_defaults'))
end
local revision=0
local function snapshot()
    local value=assert(ElevatorSettings.normalize(settings))
    value.revision=revision
    return value
end
local function canManage(src)
    if not src or src<=0 then return false end
    local ace=pr_lib.ace
    if ace and type(ace.isAdminWhitelisted)=='function' and ace.isAdminWhitelisted(src) then return true end
    for _,permission in ipairs({'pr_elevator.admin','admin','group.admin','god'}) do
        if ace and type(ace.isPlayerAceAllowed)=='function' and ace.isPlayerAceAllowed(src,permission) then return true end
    end
    if pr_lib.framework and type(pr_lib.framework.HasPermission)=='function' then
        for _,permission in ipairs({'admin','god'}) do
            local success,allowed=pcall(pr_lib.framework.HasPermission,src,permission)
            if success and allowed==true then return true end
        end
    end
    return false
end
pr_lib.cache.set('pr_elevator:settings',snapshot())
pr_lib.callback.register('pr_elevator:server:getSettings',function(src)
    return snapshot(),canManage(src)
end)
pr_lib.callback.register('pr_elevator:server:saveSettings',function(src,value)
    if not canManage(src) then return false,'no_permission' end
    local normalized,reason=ElevatorSettings.normalize(value)
    if not normalized then return false,reason end
    -- Reject stale editors rather than overwriting a newer administrator save.
    if value.revision~=revision then return false,'stale_settings' end
    local saved,result=pcall(pr_lib.saveJson,path,normalized)
    if not saved or result~=true then return false,'save_failed' end
    settings=normalized;revision=revision+1
    local state=snapshot()
    pr_lib.cache.set('pr_elevator:settings',state)
    TriggerClientEvent('pr_elevator:client:settings',-1,state)
    return true,state
end)
