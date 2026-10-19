import { mkdirSync, writeFileSync, copyFileSync } from 'node:fs';
import source from '../src/data/catalog.json';
import { pinyin } from 'pinyin-pro';
import { entries } from '../src/core';
type Row=Record<string,unknown>;
const rows:Row[]=[];
const compact=(s:string)=>s.toLowerCase().replace(/\s+/g,'');
function add(row:Row,aliases:string[]=[]){
  const name=String(row.name),english=String(row.english??'');
  row.search=[name,compact(english),pinyin(name,{toneType:'none',type:'array'}).join(''),pinyin(name,{pattern:'first',toneType:'none',type:'array'}).join(''),row.key,...aliases].map(x=>compact(String(x)));
  rows.push(row);
}
for(const e of entries){
  if(e.kind==='item'&&!/OBSOLETE|_NULL|_FLAG|_MASK/.test(e.symbol??'')){
    const type=({c:'collectible',t:'trinket',k:'card',p:'pill'} as Record<string,string>)[e.prefix!];
    add({key:e.key,name:e.name,english:e.english,category:e.category,action:type,id:Number(e.id),description:e.description,removable:['c','t'].includes(e.prefix!),minimum:1,maximum:e.prefix==='c'?99:1,default:1},[e.prefix+e.id,e.id,...e.aliases??[]]);
  }else if(e.category==='stages')add({key:e.key,name:e.name,english:e.english,category:'stages',action:'stage',code:e.id,description:'普通模式楼层传送，会重新生成目标楼层。',danger:true,minimum:1,maximum:1,default:1,greed:false});
}
const resources=[
 ['coins','金币','AddCoins','GetNumCoins',-99,99,1,'jinbi','yingbi','qian'],
 ['bombs','炸弹','AddBombs','GetNumBombs',-99,99,1,'zhadan'],
 ['keys','钥匙','AddKeys','GetNumKeys',-99,99,1,'yaoshi'],
 ['hearts','红心','AddHearts','GetHearts',-24,24,2,'hongxin','huixue'],
 ['soul-hearts','魂心','AddSoulHearts','GetSoulHearts',-24,24,2,'hunxin','lanxin'],
 ['black-hearts','黑心','AddBlackHearts','',0,24,2,'heixin'],
 ['max-hearts','心之容器','AddMaxHearts','GetMaxHearts',-24,24,2,'xinzhi rongqi','xueshangxian'],
 ['bone-hearts','骨心','AddBoneHearts','GetBoneHearts',0,12,1,'guxin'],
 ['eternal-hearts','永恒之心','AddEternalHearts','GetEternalHearts',0,12,1,'bai xin'],
 ['golden-hearts','金心','AddGoldenHearts','GetGoldenHearts',0,12,1,'jinxin'],
 ['rotten-hearts','腐心','AddRottenHearts','GetRottenHearts',0,12,1,'fuxin']
] as const;
for(const [id,name,method,getter,min,max,value,...aliases] of resources){
  const half=['hearts','soul-hearts','black-hearts','max-hearts'].includes(id);
  add({key:'resource:'+id,name:'增减'+name,english:method,category:'resources',action:'resource',method,getter,minimum:min,maximum:max,default:value,description:half?'数量单位为半颗／半个，2 表示完整一颗／一个。受角色机制和容量影响。':'按数量增减'+name+'，受角色机制和容量影响。',unit:half?'半心单位':'数量'},[...aliases]);
}
for(const [id,name,aliases] of [['flight','飞行开关',['feixing','fei','fly']],['invincible','无敌开关',['wudi','invincible']]] as const)add({key:'ability:'+id,name,english:id,category:'abilities',action:'ability',ability:id,minimum:1,maximum:1,default:1,description:id==='flight'?'当前局的飞行开关，不添加道具。关闭后恢复道具和角色自身的飞行判定。':'当前局的玩家受伤拦截开关。只影响首位玩家，不会暂停游戏。'},[...aliases]);
for(const [id,name,description,danger,aliases] of [
 ['rewind','回溯房间','类似发光沙漏；回退位置由游戏的房间历史决定。',false,['houshui','houhui','huifangjian','rewind']],
 ['restart-floor','重置当前楼层','重置整个楼层的进度，保留当前楼层和分支。不是回溯房间。',true,['chongkaibenguan','chongkaibenceng','benguan','benceng','chongkaibengceng']],
 ['restart','重新开局','结束当前对局，以当前角色开始新一局。',true,['chongkai','chongxinkaiju','restart']]
] as const)add({key:'flow:'+id,name,english:id,category:'flow',action:id,danger,description,minimum:1,maximum:1,default:1},[...aliases]);
for(let id=1;id<=7;id++)add({key:'greed-stage:'+id,name:'贪婪模式 · '+['地下室','洞穴','深牢','子宫','阴间','商店','究极贪婪'][id-1],english:'Greed stage '+id,category:'stages',action:'stage',code:String(id),greed:true,danger:true,description:'仅在贪婪／究极贪婪模式下列出。会重新生成目标楼层。',minimum:1,maximum:1,default:1});
function lua(value:unknown):string{
  if(value===null||value===undefined)return 'nil';
  if(typeof value==='string')return '"'+value.replace(/\\/g,'\\\\').replace(/"/g,'\\"').replace(/\r/g,'\\r').replace(/\n/g,'\\n').replace(/\t/g,'\\t')+'"';
  if(Array.isArray(value))return '{'+value.map(lua).join(',')+'}';
  if(typeof value==='object')return '{'+Object.entries(value).map(([k,v])=>'['+lua(k)+']='+lua(v)).join(',')+'}';
  return String(value);
}
const counts=Object.fromEntries(['collectibles','trinkets','cards','pills','resources','abilities','flow','stages'].map(c=>[c,rows.filter(r=>r.category===c).length]));
if(counts.collectibles!==721||counts.trinkets!==188||counts.cards!==97||counts.pills!==50||new Set(rows.map(r=>r.key)).size!==rows.length)throw Error('Mod 目录完整性检查失败');
mkdirSync('mod/isaac_console_panel/icp',{recursive:true});mkdirSync('.cache',{recursive:true});
writeFileSync('mod/isaac_console_panel/icp/catalog.lua','-- 自动生成：npm run mod:data；来源许可见 Mod 文档。\nreturn '+lua({version:1,counts,entries:rows})+'\n','utf8');
writeFileSync('.cache/mod-catalog.json',JSON.stringify({counts,entries:rows},null,2),'utf8');
mkdirSync('mod/isaac_console_panel/licenses',{recursive:true});
copyFileSync('licenses/isaac-cheat-sheet-MIT.txt','mod/isaac_console_panel/licenses/isaac-cheat-sheet-MIT.txt');
writeFileSync('mod/isaac_console_panel/catalog-sources.json',JSON.stringify({version:source.version,provenance:source.provenance,counts,excluded:'OBSOLETE / NULL / FLAG / MASK；饰品 47 已过时，保留空号不补齐'},null,2),'utf8');
console.log(JSON.stringify({counts,total:rows.length}));
