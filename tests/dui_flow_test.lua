local messages,threads,callbacks,commands={},{},{},{}
local instance={active=true,url='https://cfx-nui-pr_elevator/ui/ui.html?dui=1'}
function instance:sendMessage(message) messages[#messages+1]=message;return true end
local previewStarts,previewStops=0,0
function instance:startSprite(options)
    assert(options.width==0.2 and options.height==0.7)
    previewStarts=previewStarts+1;return true
end
function instance:stopSprite() previewStops=previewStops+1;return true end
function instance:replaceTexture(options)
    assert(options.originalTxd=='ch_prop_casino_keypads' and options.originalTxn=='prop_ld_keypad')
    return true
end
local creates=0
pr_lib={dui={nuiUrl=function(path,resource) return 'https://cfx-nui-'..resource..'/'..path end,
    create=function(options)
        creates=creates+1
        assert(options.url==instance.url and options.width==512 and options.height==1024)
        return instance
    end},cache={get=function() return 5 end}}
joaat=function() return 1 end
local phrases={}
local function flatten(table,prefix)
    for key,value in pairs(table) do
        local name=prefix and prefix..'.'..key or key
        if type(value)=='table' then flatten(value,name) else phrases[name]=value end
    end
end
flatten(dofile('locale/en-us.lua'))
pr_lib.locale=function() return function(key,...)
    local text=assert(phrases[key],key)
    return select('#',...)>0 and text:format(...) or text
end end
vec3=function(x,y,z) return {x=x,y=y,z=z} end
vector3=vec3
CreateThread=function(fn) threads[#threads+1]=fn end
Wait=function() end
RegisterNUICallback=function(name,fn) callbacks[name]=fn end
RegisterCommand=function(name,fn) commands[name]=fn end
AddEventHandler=function() end
exports=function() end
GetCurrentResourceName=function() return 'pr_elevator' end
DoesEntityExist=function() return true end
GetEntityCoords=function() return vec3(1,2,3) end
GetOffsetFromEntityInWorldCoords=GetEntityCoords
GetEntityHeading=function() return 90 end
GetEntityModel=function() return 1 end
CreateCam=function() return 10 end
SetCamCoord=function() end;SetCamRot=function() end;SetCamActive=function() end
RenderScriptCams=function() end;FreezeEntityPosition=function() end;TriggerEvent=function() end
DoesCamExist=function() return false end;IsCamActive=function() return false end
SendNUIMessage=function() end
GetSoundId=function() return 1 end;PlaySoundFrontend=function() end;ReleaseSoundId=function() end
local function drain()
    while #threads>0 do local fn=table.remove(threads,1);fn() end
end
local function displayed()
    for i=#messages,1,-1 do if messages[i].action=='DISPLAY' then return messages[i].value end end
end
dofile('client/dui.lua')
assert(CreateDUI()==instance);drain()
assert(OpenKeypadEntity(7,nil,{acceptAnyInput=true,prompt='ANDAR',notify=false}));drain()
assert(displayed()=='ANDAR')
commands.prelevator_dui_status()
commands.prelevator_dui_preview();commands.prelevator_dui_preview()
assert(previewStarts==1,'Repeated preview must not create duplicate rendering loops')
drain();assert(previewStops==1,'Diagnostic preview must stop automatically')
ClickButton(1);ClickButton(2);assert(displayed()=='12')
local acknowledged=false
callbacks.keypadDuiReady({},function(result) acknowledged=result.ok end);drain()
assert(acknowledged and displayed()=='12','Late page readiness must restore latest input rather than initial prompt')
ClickButton(16);assert(displayed()=='1')
ClickButton(14);assert(displayed()=='SUCCESS')
assert(OpenKeypadEntity(7,nil,{acceptAnyInput=true,prompt='SENHA',notify=false}));drain()
assert(displayed()=='SENHA')
ClickButton(3);ClickButton(4);assert(displayed()=='34')
ResetToDefaultCam();assert(displayed()=='ENTER CODE')
assert(creates==1,'Reopening floor/password must reuse the existing bridge DUI')
local accepted=0
local context={acceptAnyInput=true,prompt='PASSWORD',notify=false,
    validateInput=function(_,code) return code=='12',code~='12' and 'INVALID PASSWORD' or nil end,
    onSuccess=function() accepted=accepted+1 end}
OpenKeypadEntity(7,nil,context);drain()
ClickButton(3);ClickButton(14)
assert(displayed()=='CHECKING','Must not claim success before validation')
ClickButton(14);ClickButton(4);drain()
assert(displayed()=='INVALID PASSWORD' and accepted==0,'Wrong password must stay open without success')
ClickButton(1);ClickButton(2);ClickButton(14);drain()
assert(accepted==1,'Correct retry must succeed once')
context.validateInput=function() error('simulated backend failure') end
OpenKeypadEntity(7,nil,context);drain();ClickButton(1);ClickButton(14);drain()
assert(displayed()=='ERROR' and accepted==1,'Callback exception must not freeze input or grant access')
context.validateInput=function() return true end
OpenKeypadEntity(7,nil,context);drain();ClickButton(1);ClickButton(14);ClickButton(13);drain()
assert(accepted==1,'Cancel while waiting must invalidate late success')
OpenKeypadEntity(7,nil,context);drain();ClickButton(1);ClickButton(14)
OpenKeypadEntity(7,nil,{acceptAnyInput=true,prompt='FLOOR',notify=false});drain()
assert(displayed()=='FLOOR' and accepted==1,'Old session must not overwrite a newly opened panel')
print('PASS: server verdict, wrong-password retry, duplicate submit, exception recovery and late/cancelled session isolation')
print('PASS: actual Lua DUI creation/replacement, floor input, correction, confirmation, password, late readiness and reset through bridge')
