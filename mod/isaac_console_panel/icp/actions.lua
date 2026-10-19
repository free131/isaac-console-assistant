local M = {}
local floor_suffix={[0]='',[1]='a',[2]='b',[3]='',[4]='c',[5]='d'}
function M.new(env, state, catalog)
  local self = {env=env,state=state,catalog=catalog}
  function self:is_target(player)
    if not player then return false end
    local target=env.player()
    return target and (target==player or (target.Index==player.Index and target.InitSeed==player.InitSeed))
  end
  function self:on_cache(player, flag)
    if flag==env.flying_flag and state.run.flight and self:is_target(player) then player.CanFly=true end
  end
  function self:on_damage(entity)
    local player=entity and entity:ToPlayer()
    if state.run.invincible and self:is_target(player) then return false end
  end
  function self:refresh_flight()
    local p=env.player(); if p then p:AddCacheFlags(env.flying_flag);p:EvaluateItems() end
  end
  function self:validate(request)
    local e=type(request)=='table' and catalog.by_key[request.key]
    if not e then return nil,'未知动作，已拒绝执行。' end
    if env.game():GetNumPlayers()~=1 then return nil,'多人或多角色形态暂不支持执行。' end
    local amount=request.amount
    if type(amount)~='number' or amount~=amount or amount%1~=0 or amount<e.minimum or amount>e.maximum then return nil,'数量必须是 '..e.minimum..' 到 '..e.maximum..' 的整数。' end
    local operation=request.operation
    if e.action=='ability' then
      if operation~='on' and operation~='off' then return nil,'请明确选择开启或关闭。' end
    elseif operation~='give' and not (operation=='remove' and e.removable) then return nil,'此对象不支持该操作。' end
    if e.action=='stage' and e.greed~=env.game():IsGreedMode() then return nil,'此楼层不属于当前游戏模式。' end
    local p=env.player();if not p or p:IsDead() then return nil,'当前玩家不可用。' end
    return e
  end
  function self:execute(request)
    local e,err=self:validate(request);if not e then return {ok=false,message=err} end
    local p, amount=env.player(),request.amount
    local message='已调用 '..e.name..'，请检查游戏效果。'
    local ok, failure=pcall(function()
      if e.action=='resource' then
        local before=e.getter~='' and p[e.getter](p) or nil
        if e.method=='AddMaxHearts' then p:AddMaxHearts(amount,false) else p[e.method](p,amount) end
        local after=e.getter~='' and p[e.getter](p) or nil
        if before and after then message=e.name..'：实际变化 '..string.format('%+d',after-before)..'（受角色与容量限制）' end
      elseif e.action=='collectible' then
        if request.operation=='remove' then
          if p:GetCollectibleNum(e.id,false)<amount then error('持有数量不足，未移除。') end
          for _=1,amount do p:RemoveCollectible(e.id) end
        else for _=1,amount do p:AddCollectible(e.id,0,true) end end
      elseif e.action=='trinket' then
        if request.operation=='remove' then if not p:TryRemoveTrinket(e.id) then error('未找到可移除的此饰品。') end
        else
          if p:GetTrinket(0)~=0 and (p:GetMaxTrinkets()<=1 or p:GetTrinket(1)~=0) then error('饰品栏已满，请先自行丢弃饰品。') end
          p:AddTrinket(e.id,true)
        end
      elseif e.action=='card' then p:AddCard(e.id)
      elseif e.action=='pill' then
        -- AddPill 接收颜色 ID；这里使用原生命令按效果 ID 获取胶囊。
        env.execute('giveitem p'..e.id)
      elseif e.action=='ability' then
        state.run[e.ability]=request.operation=='on'
        if e.ability=='flight' then self:refresh_flight() end
        message=e.name..'：'..(state.run[e.ability] and '已开启' or '已关闭')
      elseif e.action=='stage' then env.execute('stage '..e.code)
      elseif e.action=='restart-floor' then
        local level=env.game():GetLevel();local suffix=floor_suffix[level:GetStageType()]
        if not suffix then error('未知楼层分支，未执行重置。') end
        env.execute('stage '..level:GetStage()..suffix)
      elseif e.action=='restart' then env.execute('restart')
      elseif e.action=='rewind' then env.execute('rewind')
      else error('此动作未实现，未执行。') end
    end)
    if not ok then return {ok=false,message=tostring(failure)} end
    return {ok=true,message=message,close=e.action=='stage' or e.action=='restart-floor' or e.action=='restart' or e.action=='rewind'}
  end
  return self
end
return M
