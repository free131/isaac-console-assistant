local Panel=include('icp/panel')
local rows={'1234567890-','qwertyuiop','asdfghjkl','zxcvbnm'}
assert(#Panel.keyboard==40 and #Panel.keyboardRows==5)
for row,expected in ipairs(rows) do
  local actual=''
  for _,i in ipairs(Panel.keyboardRows[row]) do
    local k=Panel.keyboard[i];actual=actual..k.value
    assert(k.row==row and k.x>=0 and k.x+k.w<=550 and k.y>=0 and k.y+k.h<=170)
  end
  assert(actual==expected)
end
assert(Panel.keyboard[38].value==' ' and Panel.keyboard[39].value=='backspace' and Panel.keyboard[40].value=='done')
local p=Panel.new(nil,nil,nil,nil,nil,nil)
-- Horizontal wrap respects each staggered row; vertical travel retains its column.
for row,indices in ipairs(Panel.keyboardRows) do
  p.keyboardIndex=indices[1];p.keyboardAimX=nil
  p:keyboard_move(-1,0);assert(p.keyboardIndex==indices[#indices])
  p:keyboard_move(1,0);assert(p.keyboardIndex==indices[1])
  if row<5 then
    p:keyboard_move(0,1);p:keyboard_move(0,-1)
    assert(p.keyboardIndex==indices[1])
  end
end
-- All targets remain valid over repeated directional motion across uneven rows.
for i=1,40 do
  p.keyboardIndex=i;p.keyboardAimX=nil
  for n=1,20 do p:keyboard_move(0,1);assert(Panel.keyboard[p.keyboardIndex]) end
end
local function render() frame=frame+1;draws={};callbacks[1]();assert(#logs==0,logs[#logs]) end
local function key(k) keys[k]=true;render();keys[k]=false;render() end
local function pad(a) buttons[a]=true;render();buttons[a]=false;render() end
local function has(text) for _,d in ipairs(draws) do if d.text==text then return true end end;return false end
key(256);key(265);pad(14)
assert(has('手柄输入：方向选择字符，A 输入，B 完成'))
local choose=type_virtual('jinbi2',pad)
assert(has('jinbi2_'))
choose('backspace');assert(has('jinbi_'))
choose(' ');choose('-');assert(has('jinbi -_'))
choose('done');assert(not has('手柄输入：方向选择字符，A 输入，B 完成') and nativePauseState==4)
return 3
