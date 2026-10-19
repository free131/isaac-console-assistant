-- Regression fixture: emulate installed EID wrappers and keyboard action bindings.
-- Run after mod_runtime with its actual main.lua callbacks.
local function render() frame=frame+1;draws={};callbacks[1]();assert(#logs==0,logs[#logs]) end
local function key(k) keys[k]=true;render();keys[k]=false;render() end
local function text_has(s) for _,d in ipairs(draws) do if d.text==s then return true end end;return false end
local function clear() keys[341]=true;key(75);keys[341]=false;render() end
local function typequery(s) for i=1,#s do key(string.byte(s:sub(i,i):upper())) end end
runtime_player.ControllerIndex=0
-- All global actions are blocked while the panel owns input, including F/M.
for hook=0,2 do for _,a in ipairs({17,18,19}) do assert(callbacks[2](nil,nil,hook,a)==(hook==2 and 0 or false)) end end
-- Emulate EID's actual force argument without changing the user's EID files.
local old=Input.IsButtonPressed;local aliasDown=false
EID={BoCSHookInputIsButtonPressed=function() end}
Input.IsButtonPressed=function(k,index,force)
  if not force then return false end
  -- Controller bit 21 falsely reports CTRL (341 % 32 == 21), as in Repentance.
  if aliasDown and (k==21 or k==341) then return true end
  return old(k,index)
end
clear();aliasDown=true;typequery('jinbi2');assert(text_has('jinbi2_') and text_has('resource:coins') and text_has('数量：2'));aliasDown=false
clear();typequery('feixing');assert(text_has('feixing_') and text_has('ability:flight'))
-- The real keyboard maps E/Q to menu switch, and space to menu confirm.
-- Those mappings must not move focus or accidentally execute a command.
clear();local before=runtime_player.coins;typequery('q e m f');assert(text_has('q e m f_') and runtime_player.coins==before)
-- Physical typing also works inside the controller character input overlay.
clear();typequery('jinbi2');key(290) -- results -> details, quantity
for _=1,5 do key(264) end;key(257) -- search action
assert(text_has('手柄输入：方向选择字符，A 输入，B 完成'))
clear();typequery('shengxin');assert(text_has('shengxin_'));key(256);assert(text_has('c:182'))
-- Closing must restore fullscreen / mute actions and native keyboard mappings.
key(297);assert(callbacks[2](nil,nil,0,17)==nil and callbacks[2](nil,nil,0,18)==nil)
EID=nil;Input.IsButtonPressed=old;key(297)
-- A gamepad still controls the panel even with a keyboard-assigned player index.
buttons[21]=true;render();buttons[21]=false;render();assert(callbacks[2](nil,runtime_player,0,0)==false)
return 4
