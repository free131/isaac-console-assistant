import { pinyin } from 'pinyin-pro';
import data from './data/catalog.json';
import { resolveIntents, fuzzyNameMatch } from './intent';

export interface Field {
  key: string; label: string; type: 'number' | 'text' | 'select'; default: string;
  min?: number; max?: number; optional?: boolean; pattern?: string;
  options?: { value: string; label: string }[]; hint?: string;
}
export interface Entry {
  key: string; category: string; name: string; english: string; id: string; kind: string;
  command: string; description: string; source: string; version: string; aliases?: string[];
  prefix?: string; symbol?: string; quality?: string; charge?: string;
  entityType?: number; variant?: number; subtype?: number;
  template?: string; fields?: Field[]; note?: string; disabled?: boolean;
}
export interface HistoryItem { id: string; entryKey: string; label: string; command: string; time: string }
export interface UserState { version: number; favorites: string[]; history: HistoryItem[]; alwaysOnTop: boolean }
export const version = data.version;
export const coverage = data.coverage;
export const provenance = data.provenance;
const objects = data.entries as Entry[];
const number = (key: string, label: string, value: string, min: number, max: number, hint?: string): Field => ({ key, label, type: 'number', default: value, min, max, hint });
const text = (key: string, label: string, value: string, pattern: string, hint?: string): Field => ({ key, label, type: 'text', default: value, pattern, hint });
const select = (key: string, label: string, pairs: [string,string][], value = pairs[0][0]): Field => ({ key,label,type:'select',default:value,options:pairs.map(([value,label])=>({value,label})) });
const commands: Entry[] = [];
function cmd(id: string, name: string, description: string, template: string, fields: Field[] = [], note = '', aliases: string[] = []) {
  commands.push({key:'cmd:'+id,category:'commands',name,english:id,id,kind:'template',command:'',template,fields,description,note,aliases,source:'isaacdocs',version});
}
cmd('giveitem','获取物品','按类型和 ID 获得收藏品、饰品、卡牌或胶囊。也可在左侧对应目录按名字选择。','giveitem {object}',[text('object','类型与 ID','c515','^[ctkp]\\d+$','c = 道具，t = 饰品，k = 卡牌／符文，p = 胶囊效果。')],'优先选择物品目录，避免输入无效 ID。',['给道具','获得物品','g']);
cmd('remove','移除道具或饰品','移除持有的收藏品或饰品，不会撤销其已经产生的效果。','remove {object}',[text('object','类型与 ID','c515','^[ct]\\d+$','仅支持收藏品 c 和饰品 t。')],'移除不是撤销；资源和房间变化不会回滚。',['r','删除道具']);
cmd('remove-all','移除全部道具','移除当前角色持有的道具。','remove *',[],'会显著改变当前对局。');
cmd('spawn','生成实体','按 类型.变体.子类型 生成实体，也可在实体目录中选择。','spawn {type}.{variant}.{subtype}',[number('type','实体类型','20',4,999),number('variant','变体','0',0,65535),number('subtype','子类型','0',0,65535)],'某些实体依赖特定变体或房间状态；数字范围合法不等于该组合存在。',['刷怪','生成怪物','sp']);
cmd('stage','楼层传送','前往指定楼层，沿用当前对局种子。','stage {floor}',[select('floor','目标楼层',objects.filter(x=>x.category==='stages').map(x=>[x.id,`${x.name} · ${x.id}`]))],'以下编号用于普通模式；贪婪模式楼层编号不同。',['跳关','传送']);
cmd('goto','房间传送','按房间类型和编号进入房间。','goto {room}',[text('room','房间标识','s.error.0','^(?:[sdx]\\.[a-z]+\\.\\d+|[sdx]\\.\\d+)$','示例：s.boss.1010、s.error.21、d.10。')],'房间编号与所在楼层有关；相同编号在不同楼层可能对应不同房间。');
cmd('gridspawn','生成障碍物','使用控制台的障碍物 ID 生成岩石、大便、活板门等。','gridspawn {grid}',[select('grid','障碍物',[['1000','普通岩石 · 1000'],['1494','彩虹大便 · 1494'],['9000','活板门 · 9000'],['9000.1','虚空传送门 · 9000.1'],['9100','楼梯 · 9100']])],'控制台 gridspawn ID 与 GridEntityType 枚举值不同，不能直接互换。');
cmd('debug','调试开关','切换选定调试功能；再次输入相同命令会切换状态。','debug {flag}',[select('flag','调试功能',[['3','无敌 · 3'],['4','增加伤害 · 4'],['5','显示房间信息 · 5'],['6','显示伤害碰撞范围 · 6'],['7','显示伤害数值 · 7'],['8','主动道具持续满充能 · 8'],['9','极高幸运 · 9'],['10','敌人持续受伤 · 10'],['12','显示持有道具与临时效果 · 12'],['13','显示地形碰撞范围 · 13']])],'这是切换开关，不是设置为开启；软件无法读取游戏内当前状态。debug 4 在忏悔中还会影响生成饰品。',['无敌','无限充能']);
cmd('rewind','回溯房间','使用游戏的房间回溯功能，效果类似发光沙漏。','rewind',[],'具体回退位置由游戏当前房间历史决定。',['后悔','倒回','撤回']);
cmd('restart','以当前角色重新开始','结束当前对局，以当前角色开始新一局。','restart',[],'指定角色请使用“角色”目录。',['重开','重置']);
cmd('restart-floor','重置当前楼层','读取游戏当前楼层与分支，再重新进入同一楼层；不会使用默认楼层参数替你跳到地下室。','lua local l=Game():GetLevel(); local t={"","a","b","","c","d"}; Isaac.ExecuteCommand("stage "..l:GetStage()..t[l:GetStageType()+1])',[],'会重置整个当前楼层的进度，不等于回溯房间或重新开局。命令执行时才读取楼层，无需软件读取存档。',['重开本关','重开本层','重置本关','重打这一关','重新生成当前楼层']);
cmd('seed','指定种子开局','结束当前对局，使用指定种子重新开始。','seed {seed}',[text('seed','种子','T1MM AY48','^[A-HJ-NP-Z0-9]{4} [A-HJ-NP-Z0-9]{4}$','输入两组各 4 位的大写种子，中间一个空格；不支持彩蛋种子。')],'将结束当前对局。');
cmd('challenge','开始挑战','结束当前对局，进入指定编号的挑战。','challenge {challenge}',[number('challenge','挑战编号','1',0,45)],'挑战目录提供完整中文名称，0 为无挑战。');
cmd('repeat','重复上一条命令','重复游戏控制台里上一条非 repeat 命令。','repeat {count}',[number('count','额外重复次数','1',1,1000)],'重复的是游戏中的上一条命令，不是软件最近复制的命令。过多实体可能导致卡顿。');
cmd('listcollectibles','查看持有道具','在游戏控制台列出当前持有道具及数量。','listcollectibles');
cmd('clearseeds','清除彩蛋种子效果','移除当前对局的彩蛋种子效果。','clearseeds');
cmd('reseed','重新生成当前楼层','使用新楼层种子生成当前楼层。','reseed',[],'会改变当前楼层布局。');
cmd('restock','重置房间道具','重置当前房间的道具底座和商店物品。','restock',[], '', ['刷新商店','刷新道具']);
cmd('curse','设置诅咒','设置诅咒位掩码：黑暗 1、迷宫 2、迷失 4、未知 8、诅咒 16、错乱 32、致盲 64、巨大 128。','curse {mask}',[number('mask','诅咒位掩码之和','0',0,255)],'多个诅咒相加，例如黑暗＋致盲＝65。迷宫诅咒可能需要重新生成楼层。');
cmd('combo','生成道具组合','从指定道具池获取指定数量的随机道具。','combo {pool}.{count}',[number('pool','道具池 ID','0',0,30),number('count','道具数量','5',1,100)],'0 为宝箱房；道具池编号请按当前游戏版本选择。');
cmd('playsfx','播放音效','按音效 ID 播放音效，可指定音高。','playsfx {sound} {pitch}',[number('sound','音效 ID','1',1,1000),{key:'pitch',label:'音高倍率',type:'text',default:'1',pattern:'^(?:[0-9]+(?:\\.[0-9]+)?)$',hint:'大于 0，不超过 4；默认 1。'}]);
cmd('costumetest','随机外观测试','添加指定数量的随机外观，不给予对应道具。','costumetest {count}',[number('count','外观数量','1',1,100)]);
cmd('macro','运行内置宏','运行游戏预定义的宏。','macro {name}',[select('name','内置宏',[['mom','mom'],['hud','hud'],['bigchest','bigchest']])],'宏由游戏内置，软件不提供自定义宏。');
cmd('copy','复制游戏控制台历史','让游戏把最近三条控制台命令复制到剪贴板。','copy',[],'本按钮只复制文字 copy；在游戏执行后会覆盖系统剪贴板。');
cmd('clear','清空控制台显示','清空游戏控制台的显示内容。','clear');
cmd('lua','Lua 输出示例','在游戏控制台输出一句文字，便于确认 Lua 功能。','lua print("Hello World!")',[],'更多资源修改示例见“资源与生命”。');
cmd('luamod','重新载入 Mod','重新执行指定 Mod 文件夹内的 main.lua。','luamod {folder}',[text('folder','Mod 文件夹名','goodtriprepentanceab','^[A-Za-z0-9_.-]+$')],'这是游戏原生命令；软件只生成文字，不安装或修改 Mod。');
cmd('metro','指定节拍器道具','指定节拍器下次选中的收藏品。','metro c{id}',[number('id','收藏品 ID','1',1,732)]);
cmd('delirious','指定百变怪道具首领','指定百变怪主动道具下次选中的首领。','delirious {id}',[number('id','首领编号','1',1,100)],'这里使用该道具的首领编号，并非 EntityType；范围内的值仍需对应有效首领。');
cmd('testbosspool','查看首领池','在游戏控制台打印当前楼层的首领和概率。','testbosspool');
cmd('reloadwisps','刷新魂火与蝗虫','重新载入美德之书魂火和无底坑蝗虫。','reloadwisps');
commands.push({key:'cmd:luarun',category:'commands',name:'运行 Lua 文件（忏悔不可用）',english:'luarun',id:'luarun',kind:'literal',command:'',description:'IsaacDocs 标注此命令在 Repentance 中已失效，因此本软件不提供可复制命令。',source:'isaacdocs',version,disabled:true});

const resources: [string,string,string,string,string,number,number][] = [
  ['coins','增加金币','AddCoins','7','枚金币',-99,99],
  ['bombs','增加炸弹','AddBombs','5','枚炸弹',-99,99],
  ['keys','增加钥匙','AddKeys','5','把钥匙',-99,99],
  ['hearts','恢复红心','AddHearts','2','半颗红心（2 = 1 颗）',-24,24],
  ['soul-hearts','增加魂心','AddSoulHearts','2','半颗魂心（2 = 1 颗）',-24,24],
  ['black-hearts','增加黑心','AddBlackHearts','2','半颗黑心（2 = 1 颗）',0,24],
  ['max-hearts','增加心之容器','AddMaxHearts','2','半个心之容器（2 = 1 个）',-24,24],
  ['bone-hearts','增加骨心','AddBoneHearts','1','个骨心',0,12],
  ['eternal-hearts','增加永恒之心','AddEternalHearts','1','颗永恒之心',0,12],
  ['golden-hearts','增加金心','AddGoldenHearts','1','颗金心',0,12],
  ['rotten-hearts','增加腐心','AddRottenHearts','1','颗腐心',0,12]
];
for(const [id,name,method,value,unit,min,max] of resources){
  commands.push({key:'resource:'+id,category:'resources',name,english:method,id,kind:'template',command:'',template:`lua Isaac.GetPlayer({player}):${method}({amount}${method==='AddMaxHearts'?', false':''})`,fields:[number('amount',unit,value,min,max),number('player','玩家索引','0',0,3,'0 为首位玩家；只有该玩家实际存在时才能使用。')],description:'通过游戏原生 Lua 控制台修改资源。数值会受角色机制、容量和持有道具影响。',note:method==='AddMaxHearts'?'增加心之容器不等于恢复红心；需要回血请另用“恢复红心”。':min<0?'负数表示减少对应资源。':'不适用于所有角色，请按当前角色机制使用。',source:'local-luadocs',version,aliases:id==='coins'?['钱','金钱','七块钱','加钱']:[]});
}

export const entries: Entry[] = [...commands, ...objects];
export const byKey = new Map(entries.map(e=>[e.key,e]));
export const categories = [
  ['all','全部命令','⌘'],['commands','控制台命令','›_'],['collectibles','道具','◈'],['trinkets','饰品','◇'],['cards','卡牌与符文','▤'],['pills','胶囊效果','◒'],['resources','资源与生命','＋'],['entities','实体与掉落物','⬡'],['stages','楼层传送','⇥'],['players','角色','♙'],['challenges','挑战','⚑']
] as const;
export const categoryLabel = (id:string) => categories.find(x=>x[0]===id)?.[1] ?? id;
export function fieldsFor(e: Entry): Field[] {
  if(e.kind==='item') return [select('action','操作',e.prefix==='p'?[['giveitem','获得胶囊']]:[['giveitem','获得物品'],...(['c','t'].includes(e.prefix!)?[['remove','移除物品'] as [string,string]]:[]),['spawn','生成地面物品']])];
  if(e.kind==='entity') return [number('variant','变体',String(e.variant??0),0,65535),number('subtype','子类型',String(e.subtype??0),0,65535),{key:'champion',label:'精英颜色编号（可留空）',type:'number',default:'',min:0,max:25,optional:true,hint:'仅适用于支持精英形态的敌人。'}];
  return e.fields??[];
}
export const defaultsFor = (e:Entry): Record<string,string> => Object.fromEntries(fieldsFor(e).map(f=>[f.key,f.default]));
const knownItems = new Set(objects.filter(e=>e.kind==='item').map(e=>e.prefix+e.id));
export function buildCommand(e: Entry, values: Record<string,string>): {command:string;error:string} {
  if(e.disabled) return {command:'',error:'此命令在目标版本不可用。'};
  const fields=fieldsFor(e), clean:Record<string,string>={};
  for(const f of fields){
    const raw=String(values[f.key]??'').trim(); clean[f.key]=raw;
    if(!raw){ if(f.optional) continue; return {command:'',error:`请填写${f.label}。`}; }
    if(/[\r\n\0]/.test(raw) || raw.length>200) return {command:'',error:`${f.label}格式不正确。`};
    if(f.type==='number' && (!/^-?\d+$/.test(raw)||!Number.isSafeInteger(Number(raw))||Number(raw)<f.min!||Number(raw)>f.max!)) return {command:'',error:`${f.label}须为 ${f.min} 到 ${f.max} 的整数。`};
    if(f.type==='select' && !f.options?.some(x=>x.value===raw)) return {command:'',error:`请选择有效的${f.label}。`};
    if(f.pattern && !new RegExp(f.pattern).test(raw)) return {command:'',error:`${f.label}格式不正确。`};
  }
  if(['cmd:giveitem','cmd:remove'].includes(e.key) && !knownItems.has(clean.object)) return {command:'',error:'此物品 ID 不在本机版本目录中，请从道具等目录选择。'};
  if(e.key==='cmd:metro' && !knownItems.has('c'+clean.id)) return {command:'',error:'此收藏品 ID 在本版本不存在。'};
  if(e.key==='cmd:playsfx' && (Number(clean.pitch)<=0||Number(clean.pitch)>4)) return {command:'',error:'音高倍率须大于 0 且不超过 4。'};
  let command=e.command;
  if(e.kind==='item'){
    const action=clean.action;
    command=action==='spawn'?`spawn 5.${{c:100,t:350,k:300}[e.prefix as 'c'|'t'|'k']}.${e.id}`:`${action} ${e.prefix}${e.id}`;
  } else if(e.kind==='entity') command=`spawn ${e.entityType}.${clean.variant}.${clean.subtype}${clean.champion!==''?'.'+clean.champion:''}`;
  else if(e.template) command=e.template.replace(/\{(\w+)\}/g,(_,key)=>clean[key]??'');
  if(!command||/[\r\n\0]/.test(command)||/\{\w+\}/.test(command)) return {command:'',error:'命令参数未完成。'};
  return {command,error:''};
}

const normalize=(s:string)=>s.normalize('NFKC').toLowerCase().replace(/\s+/g,'');
export interface IndexedEntry { entry:Entry; exact:string[]; text:string }
export function createSearchIndex(items:Entry[]):IndexedEntry[]{
  return items.map(entry=>{
    const full=pinyin(entry.name,{toneType:'none',type:'array'}).join('');
    const initials=pinyin(entry.name,{pattern:'first',toneType:'none',type:'array'}).join('');
    const shortId=entry.prefix?entry.prefix+entry.id:entry.id;
    const example=buildCommand(entry,defaultsFor(entry)).command;
    const exact=[entry.name,entry.english,entry.key,shortId,...(entry.aliases??[])].map(normalize);
    const search=[...exact,entry.id,entry.symbol??'',entry.description,categoryLabel(entry.category),full,initials,entry.command,example].join('\n');
    return {entry,exact,text:normalize(search)};
  });
}
export interface SearchMatch { entry: Entry; values: Record<string,string>; reason: string; score: number }
export function searchMatches(index:IndexedEntry[],query:string,category='all',favorites?:Set<string>):SearchMatch[]{
  const q=normalize(query.trim()), tokens=query.trim().split(/\s+/).map(normalize).filter(Boolean);
  const intents=new Map(resolveIntents(query,index.map(x=>x.entry)).map(x=>[x.key,x]));
  return index.filter(x=>(category==='all'||x.entry.category===category)&&(!favorites||favorites.has(x.entry.key)))
    .map((x,i)=>{
      const intent=intents.get(x.entry.key);
      const normal=!q?1:x.exact.includes(q)?1000:x.entry.id===q?900:normalize(x.entry.name).startsWith(q)?800:x.exact.some(s=>s.includes(q))?600:x.text.includes(q)?400:tokens.every(t=>x.text.includes(t))?200:0;
      const fuzzy=normal||intent?false:fuzzyNameMatch(q,x.exact);
      return {entry:x.entry,i,score:Math.max(normal,intent?.score??0,fuzzy?150:0),values:intent?.values??{},reason:intent?.reason??(fuzzy?'名称近似匹配，请核对具体对象':'')};
    })
    .filter(x=>x.score>0).sort((a,b)=>b.score-a.score||a.i-b.i);
}
export function searchEntries(index:IndexedEntry[],query:string,category='all',favorites?:Set<string>):Entry[]{
  return searchMatches(index,query,category,favorites).map(x=>x.entry);
}
