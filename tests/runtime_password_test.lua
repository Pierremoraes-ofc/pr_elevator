-- Exercise the actual runtime menu flow and callback names with a fake server.
local phrases={}
local function flatten(value,prefix)
    for key,text in pairs(value) do
        local name=prefix and prefix..'.'..key or key
        if type(text)=='table' then flatten(text,name) else phrases[name]=text end
    end
end
flatten(dofile('locale/en-us.lua'))
local function lang(key,...)
    local text=assert(phrases[key],key)
    return select('#',...)>0 and text:format(...) or text
end
local threads,events,keypads,opened,notifications={},{},{},{},{}
local teleports=0
local floors={
    {id=1,name='T',floor=1,coords={x=1,y=2,z=3},interact_coords={x=1,y=2,z=3}},
    {id=2,name='2',floor=2,coords={x=4,y=5,z=6},interact_coords={x=4,y=5,z=6}}
}
pr_lib={locale=function() return lang end,debug=function() end,progressBar=function() return true end,
    notifications={Notify=function(data) notifications[#notifications+1]=data.description end},
    callback={await=function(name,_,id,password)
        if name=='pr_elevator:server:getElevators' then return {{id=1,name='Test'}} end
        if name=='pr_elevator:server:getFloors' then return floors end
        assert(name=='pr_elevator:server:checkFloorAccess' and id==2)
        if not password then return {allowed=false,needsPassword=true} end
        return {allowed=password=='12',needsPassword=false,message=password~='12' and lang('menu.invalid_password') or nil}
    end}}
PR={Target='target',KeypadInteractDistance=2}
CreateThread=function(fn) threads[#threads+1]=fn end
RegisterNetEvent=function(name,fn) events[name]=fn end
RegisterCommand=function() end;AddEventHandler=function() end
Wait=function() end;GetGameTimer=function() return 0 end
GetCurrentResourceName=function() return 'pr_elevator' end
GetResourceState=function() return 'started' end
DoesEntityExist=function() return true end
CreateKeypadFromInteract=function(_,_,options) keypads[#keypads+1]=options;return #keypads end
HasKeypadTarget=function() return true end
OpenKeypadEntity=function(_,_,context) opened[#opened+1]=context;return true end
PlayerPedId=function() return 5 end
DoScreenFadeOut=function() end;DoScreenFadeIn=function() end
IsPedInAnyVehicle=function() return false end
SetEntityCoords=function() teleports=teleports+1 end;SetEntityHeading=function() end
dofile('client/main.lua')
threads={} -- Do not run the unrelated infinite proximity loop in this test.
events['pr_elevator:client:refreshElevators']()
table.remove(threads,1)()
assert(#keypads==2)
keypads[1].onSelect({entity=1})
local floor=opened[1]
assert(floor.prompt=='FLOOR')
assert(not floor.validateInput(floor,'99'),'Unknown floor must not show success')
assert(not floor.validateInput(floor,'T'),'Current floor must not show success')
local accepted,text=floor.validateInput(floor,'2')
assert(accepted and text=='PASSWORD','Selecting a password floor must request a password, not success')
floor.onSuccess();table.remove(threads,1)()
local password=opened[2]
accepted,text=password.validateInput(password,'33')
assert(not accepted and text=='INVALID PASSWORD' and teleports==0)
assert(notifications[#notifications]=='Invalid password.','Notification must be translated, not a missing key')
assert(password.validateInput(password,'12'))
password.onSuccess();assert(teleports==1)
print('PASS: actual floor selection, password callback, translated denial, correct password and teleport flow')
