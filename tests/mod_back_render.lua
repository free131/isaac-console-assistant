-- Inspect every rendered frame, including the press frame rather than only release.
local function has(s) for _,d in ipairs(draws) do if d.text==s then return true end end;return false end
local function render(visible)
  frame=frame+1;draws={};callbacks[1]();assert(#logs==0,logs[#logs])
  if visible then assert(has('以撒指令面板'),'back press frame lost the panel render') end
end
local function key(k) keys[k]=true;render(true);keys[k]=false;render(true) end
local function typed(s) for i=1,#s do key(string.byte(s:sub(i,i):upper())) end end
key(262);key(262);assert(has('数量：3')) -- enter quantity, then increment
keys[256]=true;render(true);assert(has('已返回结果列表。') and has('数量：3'))
for _=1,30 do render(true);assert(has('已返回结果列表。') and has('jinbi2_')) end
keys[256]=false;render(true)
key(256);assert(has('已清空搜索，返回当前分类。'))
key(256);assert(has('已在主列表；按打开热键关闭面板。'))
-- Controller B follows the same draw-preserving return path and never repeats held.
buttons[21]=true;render(true);buttons[21]=false;render(true)
buttons[15]=true;render(true);assert(has('已返回结果列表。'))
for _=1,30 do render(true);assert(has('已返回结果列表。')) end
buttons[15]=false;render(true)
typed('chongkai');key(257);assert(has('再次确认执行'))
key(256);assert(has('已取消确认。'))
-- Returning from the character overlay redraws the underlying list in the same frame.
key(256);key(290);for _=1,5 do key(264) end;key(257)
assert(has('手柄输入：方向选择字符，A 输入，B 完成'))
key(256);assert(has('输入完成，已返回搜索结果。') and not has('手柄输入：方向选择字符，A 输入，B 完成'))
-- A genuine close is still allowed to stop rendering immediately.
keys[297]=true;render(false);assert(#draws==0);keys[297]=false;render(false)
return 3
