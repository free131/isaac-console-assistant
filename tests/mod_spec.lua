local count=0
local function test(name,fn) fn();count=count+1;print('PASS '..name) end
local Search=include('icp.search');local State=include('icp.state');local Actions=include('icp.actions');local Panel=include('icp.panel')
local catalog=Search.prepare(include('icp.catalog'));local state=State.defaults()
local p={Index=1,InitSeed=100,coins=3,natural=false,inventory={},trinket=0,ControllerIndex=0}
function p:IsDead() return false end
function p:ToPlayer() return self end
function p:GetNumCoins() return self.coins end
function p:AddCoins(n) self.coins=math.max(0,math.min(99,self.coins+n)) end
function p:AddCollectible(id) self.inventory[id]=(self.inventory[id] or 0)+1 end
function p:GetCollectibleNum(id) return self.inventory[id] or 0 end
function p:RemoveCollectible(id) self.inventory[id]=self.inventory[id]-1 end
function p:GetTrinket(slot) return slot==0 and self.trinket or 0 end
function p:GetMaxTrinkets() return 1 end
function p:AddTrinket(id) self.trinket=id end
function p:TryRemoveTrinket(id) if self.trinket==id then self.trinket=0;return true end;return false end
function p:AddCard(id) self.card=id end
function p:AddCacheFlags(flag) self.flag=flag end
local commands={};local numPlayers=1;local greed=false;local stageType=0
local game={GetNumPlayers=function() return numPlayers end,IsGreedMode=function() return greed end,GetLevel=function() return {GetStage=function() return 2 end,GetStageType=function() return stageType end} end}
local actions=Actions.new({player=function() return p end,game=function() return game end,execute=function(s) commands[#commands+1]=s end,flying_flag=128},state,catalog)
function p:EvaluateItems() self.CanFly=self.natural;actions:on_cache(self,128) end
local function req(key,amount,op) return {key=key,amount=amount or 1,operation=op or 'give'} end
test('full catalog and typed IDs',function()
  local seen={};for _,e in ipairs(catalog.entries) do assert(e.name~='' and not seen[e.key]);seen[e.key]=true end
  assert(#catalog.entries==1122 and catalog.counts.collectibles==721 and catalog.counts.trinkets==188 and catalog.counts.cards==97 and catalog.counts.pills==50)
  assert(not catalog.by_key['t:47'] and not catalog.by_key['c:0']);assert(catalog.by_key['p:0'] and catalog.by_key['c:1'] and catalog.by_key['t:1'])
end)
test('pinyin initials alias typed ID and zero',function()
  assert(Search.query(catalog,'shengxin','all',state,false)[1].entry.key=='c:182')
  local found=false;for _,hit in ipairs(Search.query(catalog,'sx','all',state,false)) do if hit.entry.key=='c:182' then found=true end end;assert(found)
  assert(Search.query(catalog,'c515','all',state,false)[1].entry.key=='c:515')
  assert(Search.query(catalog,'p0','all',state,false)[1].entry.key=='p:0')
  assert(Search.query(catalog,'feixing','all',state,false)[1].entry.key=='ability:flight')
  assert(Search.query(catalog,'chongkai','all',state,false)[1].entry.key=='flow:restart')
  assert(#Search.query(catalog,'zzzzzzzz','all',state,false)==0)
end)
test('numeric suffix validation',function()
  assert(Search.query(catalog,'jinbi2','all',state,false)[1].amount==2)
  assert(Search.query(catalog,'jinbi-2','all',state,false)[1].amount==-2)
  for _,n in ipairs({100,-100,1.5,math.huge}) do assert(not actions:execute(req('resource:coins',n)).ok) end
  assert(not actions:execute(req('c:999999')).ok and not actions:execute(req('c:1',1,'lua')).ok)
end)
test('resource API item remove trinket slot card and pill zero',function()
  assert(actions:execute(req('resource:coins',2)).ok and p.coins==5)
  assert(actions:execute(req('resource:coins',-2)).ok and p.coins==3)
  assert(actions:execute(req('c:515',2)).ok and p.inventory[515]==2)
  assert(not actions:execute(req('c:515',3,'remove')).ok and p.inventory[515]==2)
  assert(actions:execute(req('c:515',2,'remove')).ok and p.inventory[515]==0)
  assert(actions:execute(req('t:1')).ok and p.trinket==1);assert(not actions:execute(req('t:2')).ok)
  assert(actions:execute(req('t:1',1,'remove')).ok and p.trinket==0)
  assert(actions:execute(req('k:1')).ok and p.card==1)
  assert(actions:execute(req('p:0')).ok and commands[#commands]=='giveitem p0')
end)
test('flight natural flight and damage isolation',function()
  assert(actions:execute(req('ability:flight',1,'on')).ok and p.CanFly)
  assert(actions:execute(req('ability:flight',1,'off')).ok and not p.CanFly)
  p.natural=true;actions:execute(req('ability:flight',1,'on'));actions:execute(req('ability:flight',1,'off'));assert(p.CanFly)
  actions:execute(req('ability:invincible',1,'on'));assert(actions:on_damage(p)==false)
  local other={Index=2,InitSeed=200,ToPlayer=function(s) return s end};assert(actions:on_damage(other)==nil)
  actions:execute(req('ability:invincible',1,'off'));assert(actions:on_damage(p)==nil)
end)
test('every resource dispatch and half-heart unit bounds',function()
  for _,e in ipairs(catalog.entries) do if e.action=='resource' and e.key~='resource:coins' then
    local balance=4;local lastAmount,lastExtra
    p[e.method]=function(_,amount,extra) lastAmount=amount;lastExtra=extra;balance=balance+amount end
    if e.getter~='' then p[e.getter]=function() return balance end end
    assert(actions:execute(req(e.key,e.default)).ok and lastAmount==e.default)
    if e.method=='AddMaxHearts' then assert(lastExtra==false) end
    if e.minimum<0 then assert(actions:execute(req(e.key,-2)).ok and lastAmount==-2) else assert(not actions:execute(req(e.key,-1)).ok) end
  end end
end)
test('singleplayer and stage branches',function()
  numPlayers=2;assert(not actions:execute(req('resource:coins')).ok);numPlayers=1
  for t,suffix in pairs({[0]='',[1]='a',[2]='b',[3]='',[4]='c',[5]='d'}) do stageType=t;assert(actions:execute(req('flow:restart-floor')).ok and commands[#commands]=='stage 2'..suffix) end
  stageType=9;assert(not actions:execute(req('flow:restart-floor')).ok);stageType=0
  assert(not actions:execute(req('greed-stage:1')).ok);greed=true;assert(actions:execute(req('greed-stage:1')).ok);greed=false
  assert(actions:execute(req('flow:rewind')).ok and commands[#commands]=='rewind')
end)
test('save sanitation recovery and run identity',function()
  local damaged,warn=State.load('bad',function() error('decode') end,catalog.by_key);assert(damaged.recovery=='bad' and warn)
  State.toggle_favorite(state,'c:515');assert(state.favorites['c:515']);State.toggle_favorite(state,'c:515');assert(not state.favorites['c:515'])
  for i=1,110 do State.record(state,req('c:1'),i) end;assert(#state.history==100 and state.history[1].stamp=='110')
  state.run={seed='123',flight=true,invincible=true};State.begin_run(state,true,123);assert(state.run.flight)
  State.begin_run(state,false,123);assert(not state.run.flight);state.run.flight=true;State.begin_run(state,true,456);assert(not state.run.flight)
  State.cycle_hotkey(state);assert(state.hotkey=='KEY_F9');State.cycle_hotkey(state);assert(state.hotkey=='KEY_F11');State.cycle_hotkey(state);assert(state.hotkey=='KEY_F8')
end)
test('save normalization rejects unknown keys and preserves readable state',function()
  local incoming={version=1,favorites={['c:515']=true,['unknown']=true},history={{key='p:0',amount=1,operation='give'},{key='bad',amount=1,operation='give'}},hotkey='KEY_F11',run={seed='test',flight=true,invincible=false},recovery='original'}
  local loaded=State.load('encoded',function() return incoming end,catalog.by_key)
  assert(loaded.favorites['c:515'] and not loaded.favorites.unknown and #loaded.history==1 and loaded.history[1].key=='p:0')
  assert(loaded.run.flight and loaded.run.seed=='test' and loaded.hotkey=='KEY_F11' and loaded.recovery=='original')
end)
test('panel pagination suffix confirmation history and back',function()
  local saved=0
  local panel=Panel.new(Search,catalog,state,actions,function() saved=saved+1 end,function(r) State.record(state,r,1) end)
  panel.open=true;panel:refresh(false);assert(#panel:visible()==8);panel:select(9);assert(panel:page()==1)
  panel:set_query('jinbi2');assert(panel.amount==2);panel:execute();assert(p.coins==5)
  panel:set_query('jinbi999');local before=p.coins;panel:execute();assert(p.coins==before)
  panel:set_query('chongkai');local n=#commands;panel:execute();assert(#commands==n and panel.confirm)
  panel:back();assert(panel.open and not panel.confirm);panel:execute();panel:execute();assert(commands[#commands]=='restart' and not panel.open and panel.guard)
  panel.category='history';panel:refresh(false);assert(panel:entry().key=='flow:restart');local size=#state.history;panel:history_delete();assert(#state.history==size-1)
  assert(saved>=3)
end)
return count
