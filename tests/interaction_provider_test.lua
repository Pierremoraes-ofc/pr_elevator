local interactions,targets,removed,deleted={},{},{},{}
local bridge={
    AddLocalEntityInteraction=function(_,data) interactions[data.entity]=data;return 'interaction-'..data.entity end,
    AddInteraction=function() error('Unexpected coordinate fallback') end,
    RemoveInteraction=function(_,id) removed[id]=true end,
    addLocalEntity=function(_,entity,options) targets[entity]=options end,
    removeLocalEntity=function(_,entity) removed['target-'..entity]=true end
}
exports=setmetatable({pr_bridge=bridge},{__call=function() end,__index=function(_,name) error('External provider forbidden: '..name) end})
joaat=function() return 1 end
vec3=function(x,y,z) return {x=x,y=y,z=z} end;vector3=vec3
GetResourceState=function(name) return name=='pr_bridge' and 'started' or 'stopped' end
GetCurrentResourceName=function() return 'pr_elevator' end
RegisterCommand=function() end;RegisterNUICallback=function() end;AddEventHandler=function() end
CreateThread=function() end
DoesEntityExist=function(entity) return not deleted[entity] end
DeleteEntity=function(entity) deleted[entity]=true end
local nextProp=10
CreateObjectNoOffset=function() nextProp=nextProp+1;return nextProp end
SetEntityAsMissionEntity=function() end;SetEntityHeading=function() end;FreezeEntityPosition=function() end
pr_lib={requestModel=function() return true end,locale=function() return function(key) return key end end}
PR={Target='interact',RespectWalls=true,KeypadInteractOffset=vec3(0,-0.18,0.03)}
dofile('client/dui.lua')
local prop=CreateKeypad(1,2,3,0)
assert(interactions[prop].offset.y==-0.18 and interactions[prop].wallDetection and not interactions[prop].ignoreLos)
assert(HasKeypadTarget(prop),'Bridge-only Interact works with external interact stopped')
PR.Target='target';DeleteKeypad(prop)
assert(removed['interaction-'..prop],'Mode change must remove old Interact by stored ID, not current mode')
PR.RespectWalls=false
local targetProp=CreateKeypad(1,2,3,0)
assert(targets[targetProp][1].ignoreLos and targets[targetProp][1].wallDetection==false)
PR.Target='interact';DeleteKeypad(targetProp)
assert(removed['target-'..targetProp],'Mode change must remove old native Target')
PR.Target='both'
local both=CreateKeypad(1,2,3,0)
assert(interactions[both] and targets[both])
PR.Target='target';DeleteKeypad(both)
assert(removed['target-'..both] and removed['interaction-'..both],'Both old registrations must be removed on switch')
print('PASS: PR Bridge-only native Target/Interact, front offset, obstacle flags, mode-switch cleanup and no external dependency')
