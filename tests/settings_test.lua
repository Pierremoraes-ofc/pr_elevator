dofile('shared/settings.lua')
local stored={mode='target',respectWalls=true,frontOffset=0.18,distance=2}
local callbacks,cache,broadcasts={},{},{}
local failSave=false
pr_lib={loadJson=function(path) assert(path=='@pr_elevator/data/settings.json');return stored end,
    saveJson=function(path,value) assert(path=='@pr_elevator/data/settings.json');if failSave then return false end;stored=value;return true end,
    cache={set=function(key,value) cache[key]=value end},
    callback={register=function(name,fn) callbacks[name]=fn end},
    ace={isPlayerAceAllowed=function(src,permission) return src==1 and permission=='pr_elevator.admin' end},framework={}}
TriggerClientEvent=function(name,target,value) broadcasts[#broadcasts+1]={name=name,target=target,value=value} end
dofile('server/settings.lua')
local read=callbacks['pr_elevator:server:getSettings']
local save=callbacks['pr_elevator:server:saveSettings']
local value,allowed=read(1);assert(allowed and value.revision==0)
assert(not select(2,read(2)))
local update={mode='interact',respectWalls=false,frontOffset=0.25,distance=3,revision=0}
assert(not save(2,update),'Non-admin cannot save')
local saved,state=save(1,update)
assert(saved and state.revision==1 and stored.mode=='interact')
assert(broadcasts[1].target==-1 and cache['pr_elevator:settings'].respectWalls==false)
assert(not save(1,update),'Stale editor cannot overwrite newer settings')
update.revision=1;update.distance=999
assert(not save(1,update));update.distance=3
failSave=true;assert(not save(1,update));assert(read(1).revision==1,'Failed disk save must not apply or broadcast')
failSave=false
local isolated=read(1);isolated.mode='target';assert(read(1).mode=='interact')
update.mode='both';assert(save(1,update));assert(read(1).revision==2)
assert(not ElevatorSettings.normalize({mode='ox_target',respectWalls=true,frontOffset=0.1,distance=2}))
assert(not ElevatorSettings.normalize({mode='target',respectWalls='false',frontOffset=0.1,distance=2}))
print('PASS: server JSON persistence, admin authorization, broadcast/cache, stale editor, limits, save rollback and snapshot isolation')

local events,refreshes,threads={},{},{}
local previous=cache['pr_elevator:settings']
PR={}
vector3=function(x,y,z) return {x=x,y=y,z=z} end
RegisterNetEvent=function(name,fn) events[name]=fn end
CreateThread=function(fn) threads[#threads+1]=fn end
TriggerEvent=function(name) refreshes[#refreshes+1]=name end
pr_lib.locale=function() return function(key) return key end end
pr_lib.callback.await=function() return state,true end
dofile('client/settings.lua')
local apply=events['pr_elevator:client:settings']
apply({mode='interact',respectWalls=true,frontOffset=0.3,distance=2.5,revision=3})
assert(PR.Target=='interact' and PR.RespectWalls and PR.KeypadInteractOffset.y==-0.3 and PR.KeypadInteractDistance==2.5)
assert(#refreshes==1)
apply({mode='target',respectWalls=false,frontOffset=0.1,distance=1,revision=2})
assert(PR.Target=='interact' and #refreshes==1,'Out of order packet must not revert live settings')
apply({mode='both',respectWalls=false,frontOffset=0.2,distance=1,revision=4})
assert(PR.Target=='both' and not PR.RespectWalls and #refreshes==2)
print('PASS: client cache/revision synchronization, live refresh and front offset')
