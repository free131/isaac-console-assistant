-- Actual main.lua callback harness; all game APIs below are mocks, no game process.
callbacks={};keys={};buttons={};pads={};mouse=false;paused=false;nativePauseState=0;nativePauseAnimation='Dissapear';logs={};pauseLogs={};draws={};saved='';players=1;frame=0
function RegisterMod() return {HasData=function() return initialSave~=nil end,LoadData=function() return initialSave end,SaveData=function(_,s) saved=s end,AddCallback=function(_,id,fn) callbacks[id]=fn end} end
ModCallbacks={MC_POST_RENDER=1,MC_INPUT_ACTION=2,MC_EVALUATE_CACHE=3,MC_ENTITY_TAKE_DMG=4,MC_POST_GAME_STARTED=5,MC_PRE_GAME_EXIT=6,MC_POST_NEW_ROOM=7,MC_PRE_PAUSE_SCREEN_RENDER=9}
PauseMenu={GetState=function() return nativePauseState end,SetState=function(s) nativePauseState=s end,GetSprite=function() return {Play=function(_,name) nativePauseAnimation=name end,GetAnimation=function() return nativePauseAnimation end} end}
CacheFlag={CACHE_FLYING=128};EntityType={ENTITY_PLAYER=1};InputHook={IS_ACTION_PRESSED=0,IS_ACTION_TRIGGERED=1,GET_ACTION_VALUE=2}
ButtonAction={ACTION_BOMB=8,ACTION_ITEM=9,ACTION_PILLCARD=10,ACTION_FULLSCREEN=17,ACTION_MUTE=18,ACTION_MENUCONFIRM=14,ACTION_MENUBACK=15,ACTION_MENULEFT=20,ACTION_MENURIGHT=21,ACTION_MENUUP=22,ACTION_MENUDOWN=23,ACTION_MENULT=24,ACTION_MENURT=25}
Keyboard={KEY_F1=290,KEY_F8=297,KEY_F9=298,KEY_F11=300,KEY_ESCAPE=256,KEY_UP=265,KEY_DOWN=264,KEY_LEFT=263,KEY_RIGHT=262,KEY_TAB=258,KEY_PAGE_UP=266,KEY_PAGE_DOWN=267,KEY_F2=291,KEY_F3=292,KEY_DELETE=261,KEY_BACKSPACE=259,KEY_LEFT_CONTROL=341,KEY_RIGHT_CONTROL=345,KEY_K=75,KEY_MINUS=45,KEY_SPACE=32,KEY_ENTER=257}
Vector=setmetatable({Zero={X=0,Y=0}},{__call=function(_,x,y) return {X=x,Y=y} end})
function Color(...) return {...} end;function KColor(...) return {...} end
function Sprite() return {Load=function() end,Play=function() end,Render=function() end} end
function Font() return {Load=function() end,IsLoaded=function() return true end,GetStringWidthUTF8=function(_,s) local _,n=s:gsub('[^\128-\191]','');return n*18 end,DrawStringScaledUTF8=function(_,s,x,y,sx,sy,c) draws[#draws+1]={text=s,x=x,y=y,sx=sx,sy=sy,color=c} end} end
runtime_player={Index=1,InitSeed=1,ControllerIndex=1,coins=0,ToPlayer=function(s) return s end,IsDead=function() return false end,AddCacheFlags=function() end,EvaluateItems=function() end,GetNumCoins=function(s) return s.coins end,AddCoins=function(s,n) s.coins=s.coins+n end}
local game={IsPaused=function() return paused or nativePauseState~=0 end,GetNumPlayers=function() return players end,IsGreedMode=function() return false end,GetFrameCount=function() return frame end,GetSeeds=function() return {GetStartSeed=function() return 123 end} end}
function Game() return game end
Isaac={GetTime=function() return clock or frame*1000/60 end,GetPlayer=function() return runtime_player end,GetScreenWidth=function() return screenW or 960 end,GetScreenHeight=function() return screenH or 540 end,WorldToScreen=function(v) return Vector(v.X-103,v.Y+41) end,DebugString=function(s) if s:find('[ICP-Pause]',1,true) then pauseLogs[#pauseLogs+1]=s else logs[#logs+1]=s end end,RenderText=function() end,ExecuteCommand=function() error('unexpected game command in runtime harness') end}
Input={IsButtonPressed=function(k,index) if index and index>0 then return pads[index] and pads[index][k]==true or false end;return keys[k]==true end,IsMouseBtnPressed=function() return mouse end,GetMousePosition=function(world) if world then return Vector((mouseX or 0)+103,(mouseY or 0)-41) end;return Vector((mouseX or 0)*2+30,(mouseY or 0)*2+20) end,IsActionPressed=function(a,index) local intercepted=callbacks[2] and callbacks[2](nil,runtime_player,0,a);if intercepted~=nil then return intercepted end;if index==0 then local map={[14]={32,257},[15]={256},[17]={70},[18]={77},[20]={263},[21]={262},[22]={265},[23]={264},[24]={81},[25]={69}};for _,k in ipairs(map[a] or {}) do if keys[k] then return true end end;return false end;local map={[8]=8,[9]=11,[14]=4,[15]=5,[20]=0,[21]=1,[22]=2,[23]=3,[24]=8,[25]=11};return buttons[a]==true or (map[a] and pads[index] and pads[index][map[a]]==true) or false end}
package.preload.json=function() return json_bridge or {encode=function() return 'mock encoded' end,decode=function() return {} end} end
include('main')
local function render() frame=frame+1;callbacks[1]();assert(#logs==0,logs[#logs]) end
local function keypress(k) keys[k]=true;render();keys[k]=false;render() end
local function typequery(s) for i=1,#s do keypress(string.byte(s:sub(i,i):upper())) end end
local function blocked() return callbacks[2](nil,runtime_player,0,0)==false end
callbacks[5](nil,false);render();assert(not blocked())
keypress(297);assert(blocked());assert(callbacks[2](nil,runtime_player,2,4)==0)
keypress(256) -- leave default favorites for the general gameplay fixture
typequery('jinbi2');keypress(257);assert(runtime_player.coins==2 and saved~='')
-- Holding confirm never repeats execution; release after closing must still be guarded.
keys[257]=true;render();render();local n=runtime_player.coins;render();assert(runtime_player.coins==n)
keys[297]=true;render();assert(blocked());keys[297]=false;render();assert(blocked());keys[257]=false;render();assert(not blocked())
-- Controller menu actions are observable by the panel despite its own input hook.
keypress(297);keypress(256);typequery('jinbi2');buttons[14]=true;render();assert(runtime_player.coins==n+2);buttons[14]=false;render()
buttons[15]=true;render();assert(blocked());buttons[15]=false;render();assert(blocked());keypress(297);assert(not blocked())
-- Native pause and MCM prevent stacking, and close an already opened panel.
paused=true;keypress(297);assert(not blocked());paused=false
ModConfigMenu={IsVisible=true};keypress(297);assert(not blocked());ModConfigMenu.IsVisible=false
keypress(297);assert(blocked());ModConfigMenu.IsVisible=true;render();assert(not blocked());ModConfigMenu.IsVisible=false;render();assert(not blocked())
gt={mapHeld=true};keypress(297);assert(not blocked());gt.mapHeld=false
-- Normal gameplay hooks have no return value when panel is closed.
for a=0,28 do assert(callbacks[2](nil,runtime_player,0,a)==nil) end
keypress(297)
for _,size in ipairs({{640,360},{960,540},{1280,720},{1920,1080}}) do screenW=size[1];screenH=size[2];draws={};render();for _,d in ipairs(draws) do assert(d.x>=0 and d.y>=0 and d.x<screenW and d.y<screenH) end end
keypress(256);typequery('jinbi2')
return 7
