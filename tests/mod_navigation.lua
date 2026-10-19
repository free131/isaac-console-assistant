-- Runs against actual main.lua callbacks after mod_runtime, using no mouse to navigate.
local function render() frame=frame+1;draws={};callbacks[1]();assert(#logs==0,logs[#logs]) end
local function key(k) keys[k]=true;render();keys[k]=false;render() end
local function pad(a) buttons[a]=true;render();buttons[a]=false;render() end
local function text_has(s) for _,d in ipairs(draws) do if d.text==s then return true end end;return false end
local function blocked() return callbacks[2](nil,runtime_player,0,0)==false end
local function clear() keys[341]=true;key(75);keys[341]=false;render() end
local function typequery(s) for i=1,#s do key(string.byte(s:sub(i,i):upper())) end end
-- Escape clears a search, then returns categories, and never closes the root.
key(256);assert(blocked());key(256);assert(blocked())
-- Keyboard-only: select resources category, results, amount and execute.
key(263);for _=1,5 do key(264) end;key(262);assert(text_has('resource:coins'))
key(264);assert(text_has('resource:bombs'))
key(262);key(262);assert(text_has('数量：2'));key(256);assert(blocked())
key(256);assert(blocked()) -- return to all
clear();typequery('jinbi2')
-- Controller-only: reach quantity, operation, favorite, execute, clear, hotkey, close.
pad(21);pad(21);pad(20);assert(text_has('数量：2'))
pad(23);pad(14) -- resource has no remove mode; harmless
pad(23);pad(14);assert(text_has('取消收藏'))
pad(23);local before=runtime_player.coins;pad(14);assert(runtime_player.coins==before+2)
pad(15);assert(blocked());pad(15);assert(blocked()) -- back to results, clear search
-- Controller operation switch works for abilities, not just quantity and execution.
pad(20);for _=1,6 do pad(23) end;pad(21);pad(21);pad(23);pad(14);assert(text_has('操作：关闭'))
pad(14);assert(text_has('操作：开启'));pad(23);pad(23);pad(14);assert(text_has('本 Mod 状态：开启'))
pad(15);pad(15)
-- History management is reachable without mouse: select history through categories.
pad(20);for _=1,10 do pad(23) end;pad(21);pad(21)
for _=1,4 do pad(23) end -- details control 5: delete
pad(14);assert(blocked());pad(23);pad(14);assert(text_has('再次确认“清历史”以清空记录。'));pad(15);assert(blocked())
-- Cancel clear confirmation, then activate twice to clear all history.
pad(14);pad(14);assert(text_has('结果 0 条'))
pad(23);pad(14) -- clear search
pad(23);pad(14) -- open controller character keyboard
local cursor=1
for ch in ('jinbi2'):gmatch('.') do
  local dest=assert(('abcdefghijklmnopqrstuvwxyz0123456789-'):find(ch,1,true))
  local col,row=(cursor-1)%10,math.floor((cursor-1)/10)
  local tocol,torow=(dest-1)%10,math.floor((dest-1)/10)
  while col~=tocol do pad(col<tocol and 21 or 20);col=col+(col<tocol and 1 or -1) end
  while row~=torow do pad(row<torow and 23 or 22);row=row+(row<torow and 1 or -1) end
  pad(14);cursor=dest
end
pad(15);assert(text_has('resource:coins') and text_has('数量：2') and blocked())
pad(21);for _=1,6 do pad(23) end;pad(14);assert(text_has('打开 / 关闭热键已设为 F9'))
pad(23);pad(14);assert(not blocked()) -- close via keyboard/controller selectable control
key(298);assert(blocked()) -- configured F9 reopens
-- Return hotkey to F8 through keyboard-only focus actions for remaining test fixtures.
key(290) -- focus results -> details, quantity selected
key(265);key(265);key(257);key(257) -- hotkey F11 -> F8
key(256);key(256);assert(blocked())
-- Mouse auxiliary path: non-identity world/render/screen spaces, multiple scales.
local function mouse_click(x,y)
  local w,h=screenW or 960,screenH or 540
  local s=math.min((w-16)/760,(h-16)/450,1.5)
  mouseX=(w-760*s)/2+x*s;mouseY=(h-450*s)/2+y*s;mouse=true;render();mouse=false;render()
end
for _,size in ipairs({{640,360},{960,540},{1280,720},{1920,1080}}) do
  screenW=size[1];screenH=size[2];render()
  mouse_click(60,225);assert(text_has('resource:coins'))
  mouse_click(250,157);assert(text_has('resource:bombs'))
  mouse_click(718,274);assert(text_has('数量：2'))
  key(256);assert(blocked())
end
-- Restore predictable selection for the JSON restart fixture.
mouseX=0;mouseY=0;clear();typequery('jinbi2');key(256);clear();typequery('jinbi2')
return 4
