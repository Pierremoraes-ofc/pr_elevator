local allowed=true
local exported,context,notified,keybind={},{},0
local external
PR={keyBinds='SPACE'}
joaat=function(value)return value end
RegisterNetEvent=function()end;AddEventHandler=function()end
GetCurrentResourceName=function()return 'pr_elevator'end
SetTimeout=function()end
TriggerEvent=function(name,...)if name=='pr_bridge:ui:context:openExternal' then external={...}end end
Bridge={debug={error=error,warn=function()end}}
local createContext=dofile('../../[forge]/[forge-scripts]/pr_bridge/interface/client/modules/context.lua')
local nativeContext=createContext({setFocus=function()end,send=function()end,ensureFocus=function()end,resetFocus=function()end})
CreateThread=function(fn)fn()end
exports=function(name,fn)exported[name]=fn end
local locale=setmetatable({locale=function()return 'pt-br'end},{__call=function(_,key)return key end})
pr_lib={locale=function()return locale end,debug=function()end,
    notifications={Notify=function()notified=notified+1 end},
    callback={await=function(name)assert(name=='pr_elevator:server:getSettings');return {},allowed end},
    menu={RegisterContext=function(value)context=value;nativeContext.RegisterContext(value) end,ShowContext=nativeContext.ShowContext},addKeybind=function(value)keybind=value end}
dofile('client/menu.lua')
exported.OpenAdminMenu('forge_core_server_settings','forge-core')
assert(context.id=='pr_elevator_manage_menu' and context.menu=='forge_core_server_settings')
assert(context.menuResource=='forge-core')
assert(#context.options==5,'The direct link must include settings and full elevator management')
-- Returning from settings rebuilds the root without dropping the external parent.
OpenElevatorSettingsMenu=function(back)context=nil;back()end
context.options[1].onSelect();assert(context.menu=='forge_core_server_settings' and context.menuResource=='forge-core')
nativeContext.HandleBack();assert(external[1]=='forge-core' and external[2]=='forge_core_server_settings' and external[3]=='pr_elevator')
keybind.onPressed();assert(context.menu==nil and context.menuResource==nil,'Standalone opening must clear inherited navigation')
context=nil;allowed=false;exported.OpenAdminMenu('forge_core_server_settings','forge-core')
assert(context==nil and notified==1,'Client shortcut must wait for a server-authorized entry')
print('PASS: actual elevator admin export, full management/options, back link and server authorization before opening')
