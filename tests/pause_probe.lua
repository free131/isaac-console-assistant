local now,frame,timer,paused=0,0,0,false
local events={}
local Probe=include('probe')
local p=Probe.new({time=function() return now end,frame=function() return frame end,timer=function() return timer end,paused=function() return paused end,grave=function() return false end,log=function(kind,row) events[#events+1]={kind,row} end})
assert(p:input(1,28)==nil and not p:arm())
p:start();p:arm();assert(p:input(1,0)==nil and p:input(1,28)==true and p:input(1,28)==nil)
assert(p:input(0,28)==true and p:input(2,28)==1 and p:input(2,28)==nil)
frame=1;assert(p:input(0,28)==nil)
now=1001;p:render();assert(p.status=='request_finished_result_unverified')
p:start();now=2000;p:arm();now=3001;p:render();assert(p.status=='request_expired_no_hook')
p:snapshot('console_A');now=8001;paused=true;local row=p:snapshot('console_B')
assert(row.delta.ms==5000 and row.delta.renders==0 and row.delta.updates==0 and row.delta.timer==0)
p:render();p:update();now=9000;frame=2;timer=1;row=p:snapshot('after')
assert(row.delta.renders==1 and row.delta.updates==1 and row.delta.game_frame==1 and row.delta.timer==1)
for i=1,40 do p:snapshot(i) end;assert(#p.marks==32 and p:report().game_verified==false)
return 5
