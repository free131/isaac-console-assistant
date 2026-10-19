import { test } from 'node:test';
import assert from 'node:assert/strict';
import reference from '../src/data/enum-reference.json';
import { entries, byKey, createSearchIndex, searchEntries, searchMatches, buildCommand, defaultsFor, fieldsFor } from '../src/core';
import { parseChineseNumber } from '../src/intent';
const index=createSearchIndex(entries);
const entry=(key:string)=>{const e=byKey.get(key);assert.ok(e,key);return e;};
const command=(key:string,params:Record<string,string>={})=>{const e=entry(key);return buildCommand(e,{...defaultsFor(e),...params});};

test('完整目录与本机枚举逐项一致，包含符文及胶囊 0，排除计数项和掩码',()=>{
  for(const [table,prefix,category] of [[reference.CollectibleType,'COLLECTIBLE_','collectibles'],[reference.TrinketType,'TRINKET_','trinkets'],[reference.Card,'','cards'],[reference.PillEffect,'PILLEFFECT_','pills']] as const){
    const expected=[...new Set(Object.entries(table).filter(([name,id])=>(category==='cards'?(name.startsWith('CARD_')||name.startsWith('RUNE_')):name.startsWith(prefix))&&id>=(category==='pills'?0:1)).map(([,id])=>String(id)))].sort();
    assert.deepEqual(entries.filter(e=>e.category===category).map(e=>e.id).sort(),expected,category);
  }
  assert.equal(entries.filter(e=>e.category==='collectibles').length,721);
  assert.equal(entries.filter(e=>e.category==='cards').length,97);
  assert.ok(byKey.has('p:0'));assert.ok(byKey.has('k:33'));assert.ok(!byKey.has('c:733'));
});
test('目录键唯一，名称和版本完整，所有可用条目均可生成默认命令',()=>{
  assert.equal(new Set(entries.map(e=>e.key)).size,entries.length);
  for(const e of entries){assert.ok(e.name&&e.version);assert.equal(new Set(fieldsFor(e).map(f=>f.key)).size,fieldsFor(e).length);if(!e.disabled){const r=buildCommand(e,defaultsFor(e));assert.equal(r.error,'',e.key);assert.ok(r.command);assert.ok(!/[\r\n]/.test(r.command));}}
});
test('中英文、别名、全拼、首字母及带空格的 ID 查询均可找到神秘礼物',()=>{
  for(const q of ['神秘礼物','Mystery Gift','幸运礼物','shenmiliwu','smlw','515','c515','c:515','giveitem c515','sm lw'])assert.ok(searchEntries(index,q).some(e=>e.key==='c:515'),q);
  assert.equal(searchEntries(index,'神秘礼物')[0].key,'c:515');assert.equal(searchEntries(index,'c515')[0].key,'c:515');
});
test('同数字的道具、饰品和卡牌不会串类型；分类和收藏共同过滤',()=>{
  for(const key of ['c:1','t:1','k:1'])assert.ok(searchEntries(index,'1').some(e=>e.key===key));
  assert.deepEqual(searchEntries(index,'1','trinkets',new Set(['c:1','t:1'])).map(e=>e.key),['t:1']);
  assert.equal(searchEntries(index,'完全不存在的道具xyzz123').length,0);
});
test('获取、移除、生成道具和卡牌的类型编码正确',()=>{
  assert.equal(command('c:515').command,'giveitem c515');assert.equal(command('c:515',{action:'remove'}).command,'remove c515');
  assert.equal(command('c:515',{action:'spawn'}).command,'spawn 5.100.515');assert.equal(command('t:1',{action:'spawn'}).command,'spawn 5.350.1');
  assert.equal(command('k:33',{action:'spawn'}).command,'spawn 5.300.33');assert.equal(command('p:0').command,'giveitem p0');
  assert.ok(command('p:0',{action:'spawn'}).error);assert.ok(command('k:1',{action:'remove'}).error);
});
test('实体变体、子类型和精英颜色不会丢失，空精英参数省略',()=>{
  assert.equal(command('entity:20').command,'spawn 20.0.0');assert.equal(command('entity:20',{variant:'1',subtype:'2',champion:'4'}).command,'spawn 20.1.2.4');
  assert.equal(command('pickup:20:1').command,'spawn 5.20.1');assert.ok(command('entity:20',{champion:'26'}).error);
});
test('楼层、角色、挑战和资源生成正确的命令及单位',()=>{
  assert.equal(command('stage:3c').command,'stage 3c');assert.equal(command('player:0').command,'restart 0');assert.equal(command('challenge:45').command,'challenge 45');
  assert.equal(command('resource:coins').command,'lua Isaac.GetPlayer(0):AddCoins(7)');
  assert.equal(command('resource:hearts',{amount:'2',player:'1'}).command,'lua Isaac.GetPlayer(1):AddHearts(2)');
  assert.equal(command('resource:max-hearts').command,'lua Isaac.GetPlayer(0):AddMaxHearts(2, false)');
});
test('缺失、越界、小数、注入和不存在的 ID 阻止生成',()=>{
  for(const amount of ['', '1.5','100','-100','7\nlua print(1)','abc'])assert.ok(command('resource:coins',{amount}).error,amount);
  assert.ok(command('cmd:giveitem',{object:'c733'}).error);assert.ok(command('cmd:giveitem',{object:'p9999'}).error);
  assert.ok(command('cmd:stage',{floor:'99z'}).error);assert.ok(command('cmd:challenge',{challenge:'46'}).error);assert.ok(command('cmd:playsfx',{pitch:'0'}).error);
  assert.ok(command('cmd:luarun').error);assert.ok(command('cmd:goto',{room:'s.boss.1\nrestart'}).error);
});
test('数量负值保留，种子大写规则和障碍物控制台编码不混用',()=>{
  assert.equal(command('resource:coins',{amount:'-7'}).command,'lua Isaac.GetPlayer(0):AddCoins(-7)');
  assert.equal(command('cmd:seed').command,'seed T1MM AY48');assert.ok(command('cmd:seed',{seed:'t1mm ay48'}).error);
  assert.equal(command('cmd:gridspawn',{grid:'9000.1'}).command,'gridspawn 9000.1');
});

const understood=(q:string)=>{const match=searchMatches(index,q)[0];assert.ok(match,'未识别：'+q);return {...match,...buildCommand(match.entry,{...defaultsFor(match.entry),...match.values})};};
test('中文口语与数量自动解析：两个金币、十二把钥匙、零金币与负数',()=>{
  for(const q of ['获得两个金币','给我两枚硬币','我想要2块钱','金币加二','请给我２个金币']){const r=understood(q);assert.equal(r.entry.key,'resource:coins',q);assert.equal(r.command,'lua Isaac.GetPlayer(0):AddCoins(2)',q);}
  assert.equal(understood('增加十二把钥匙').command,'lua Isaac.GetPlayer(0):AddKeys(12)');
  assert.equal(understood('获得零个金币').command,'lua Isaac.GetPlayer(0):AddCoins(0)');
  assert.equal(understood('扣掉三个金币').command,'lua Isaac.GetPlayer(0):AddCoins(-3)');
  assert.equal(understood('获得-2个金币').command,'lua Isaac.GetPlayer(0):AddCoins(-2)');
  assert.equal(understood('给玩家2增加三枚金币').command,'lua Isaac.GetPlayer(1):AddCoins(3)');
});
test('中文数字与半心单位不混淆，超出范围和小数不被截断',()=>{
  for(const [s,n] of [['两',2],['十二',12],['二十三',23],['一百零二',102],['两百',200],['一千零二十',1020],['一万',10000],['零',0],['负三',-3],['半',.5]] as const)assert.equal(parseChineseNumber(s),n,s);
  assert.equal(understood('补充两颗红心').command,'lua Isaac.GetPlayer(0):AddHearts(4)');
  assert.equal(understood('恢复半颗魂心').command,'lua Isaac.GetPlayer(0):AddSoulHearts(1)');
  assert.equal(understood('恢复一颗半红心').command,'lua Isaac.GetPlayer(0):AddHearts(3)');
  assert.equal(understood('增加一点五颗魂心').command,'lua Isaac.GetPlayer(0):AddSoulHearts(3)');
  assert.equal(understood('获得两个骨心').command,'lua Isaac.GetPlayer(0):AddBoneHearts(2)');
  assert.ok(understood('获得两百个金币').error);assert.ok(understood('获得1.5个金币').error);
});
test('飞行通过原版道具匹配，明确展示添加和移除的实际影响',()=>{
  const on=understood('开启飞行');assert.equal(on.entry.key,'c:20');assert.equal(on.command,'giveitem c20');assert.match(on.reason,/会添加道具/);
  assert.equal(understood('让我飞起来').command,'giveitem c20');
  const off=understood('关闭飞行');assert.equal(off.command,'remove c20');assert.match(off.reason,/其他来源/);
});
test('重开本关与回溯房间、重新开局区分，动态读取当前楼层并保留分支',()=>{
  for(const q of ['重开本关','重置本层','重打这一关']){const r=understood(q);assert.equal(r.entry.key,'cmd:restart-floor');assert.match(r.command,/GetLevel\(\)/);assert.match(r.command,/GetStage\(\)/);assert.match(r.command,/GetStageType\(\)\+1/);assert.match(r.command,/"","a","b","","c","d"/);}
  assert.equal(understood('重开当前房间').command,'rewind');assert.equal(understood('重开').command,'restart');
  const options=searchMatches(index,'重开本关').slice(0,3).map(x=>x.entry.key);assert.deepEqual(options,['cmd:restart-floor','cmd:rewind','cmd:restart']);
});
test('道具口语与常用能力、传送意图支持原有参数验证',()=>{
  assert.equal(understood('获得神秘礼物').command,'giveitem c515');
  assert.equal(understood('移除硫磺火').command,'remove c118');
  assert.equal(understood('获得'+entry('c:199').name).command,'giveitem c199');
  assert.equal(understood('生成一个神秘礼物').command,'spawn 5.100.515');
  assert.equal(understood('开启无敌').command,'debug 3');assert.match(understood('关闭无敌').reason,/切换/);
  assert.equal(understood('无限充能').command,'debug 8');assert.equal(understood('去教堂').command,'stage 10a');
});
test('错字容错、分类与收藏过滤仍正常，无效 ID 和否定表达不猜命令',()=>{
  assert.equal(understood('硫磺活').entry.key,'c:118');
  assert.equal(searchMatches(index,'c99998').length,0);
  assert.equal(searchMatches(index,'不要获得两个金币').length,0);
  assert.equal(searchMatches(index,'获得两个金币\nrestart').some(x=>x.reason.startsWith('增加')),false);
  assert.equal(searchMatches(index,'获得两个金币','trinkets').length,0);
  assert.equal(searchMatches(index,'获得两个金币','all',new Set(['resource:coins']))[0].values.amount,'2');
});
test('连续查询和手动改参数不污染目录、下一次搜索或收藏记录',()=>{
  const original=defaultsFor(entry('resource:coins'));const a=understood('获得两个金币');a.values.amount='9';
  assert.equal(understood('获得三个金币').values.amount,'3');assert.equal(understood('获得两个金币').values.amount,'2');
  assert.deepEqual(defaultsFor(entry('resource:coins')),original);assert.equal(command('resource:coins').command,'lua Isaac.GetPlayer(0):AddCoins(7)');
});
