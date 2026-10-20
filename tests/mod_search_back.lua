local function render() frame=frame+1;draws={};callbacks[1]();assert(#logs==0,logs[#logs]) end
local function key(code) keys[code]=true;render();keys[code]=false;render() end
local function pad(action) buttons[action]=true;render();buttons[action]=false;render() end
local function physical(code) pads[1]={[code]=true};render();pads={};render() end
local function has(text) for _,d in ipairs(draws) do if d.text==text then return true end end;return false end
-- Runtime starts with jinbi2 selected. Clear with Esc without changing keyboard close.
key(256);assert(nativePauseState==4)
physical(2);assert(nativePauseState==4) -- Up is now navigation, never close
pad(14);assert(has('手柄输入：方向选择字符，A 输入，B 完成'))
-- Search is reachable and usable entirely with controller directions and A/B.
type_virtual('jinbi2',pad)
pad(15);assert(has('resource:coins') and has('数量：2') and nativePauseState==4)
pad(15);assert(nativePauseState==4) -- clear query, not close on the same press
buttons[15]=true;render();assert(#draws==0 and nativePauseState==4)
for i=1,30 do render();assert(nativePauseState==4) end -- hold B cannot unpause
buttons[15]=false;render();assert(nativePauseState==0)
-- Up immediately reopens; in the open panel Up/Down moves to/from the search row.
physical(2);assert(nativePauseState==4)
physical(2);pad(23);physical(2);pad(14)
assert(has('手柄输入：方向选择字符，A 输入，B 完成'))
physical(5);physical(5);physical(5);assert(nativePauseState==0)
key(297);assert(nativePauseState==4);key(297);assert(nativePauseState==0)
-- Unit navigation: every column and an empty result list can reach visible search.
local Panel=include('icp/panel');local Search=include('icp/search');local State=include('icp/state')
local catalog=Search.prepare(include('icp/catalog'))
local p=Panel.new(Search,catalog,State.defaults(),{},function() end,function() end)
p.open=true;p:refresh(false)
for _,focus in ipairs({'results','categories','details'}) do
  p.focus=focus;p.control=1;p.category=focus=='categories' and 'favorites' or 'all';p:refresh(false)
  p:navigate(0,-1);assert(p.focus=='search' and p:confirm_id()=='search')
  p:navigate(0,1);assert(p.focus==focus)
end
p.focus='results';p:set_query('zzzzzzzzzzzz');assert(#p.hits==0)
p:navigate(0,-1);assert(p.focus=='search')
-- Back preserves all nested layers, then closes only on the next root press.
p.editing=true;p:back(true);assert(p.open and not p.editing)
p.confirm=10;p:back(true);assert(p.open and not p.confirm)
p.focus='details';p:back(true);assert(p.open and p.focus=='results')
p:back(true);assert(p.open and p.query=='')
p.category='resources';p:back(true);assert(p.open and p.category=='all')
p:back();assert(p.open) -- keyboard Esc root behavior is retained
p:back(true);assert(not p.open and p.guard)
return 4
