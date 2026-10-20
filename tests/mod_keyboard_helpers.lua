-- Controller typing helper follows the current physical layout, not alphabet indices.
function type_virtual(text,press)
  local Panel=include('icp/panel')
  local cursor=Panel.new(nil,nil,nil,nil,nil,nil)
  cursor.keyboardIndex=1
  local function choose(value)
    local target
    for i,key in ipairs(Panel.keyboard) do if key.value==value then target=i;break end end
    assert(target,'missing virtual key '..value)
    for i=1,5 do
      if Panel.keyboard[cursor.keyboardIndex].row==Panel.keyboard[target].row then break end
      press(23);cursor:keyboard_move(0,1)
    end
    for i=1,11 do
      if cursor.keyboardIndex==target then break end
      press(21);cursor:keyboard_move(1,0)
    end
    assert(cursor.keyboardIndex==target)
    press(14)
  end
  for ch in text:gmatch('.') do choose(ch) end
  return choose
end
