import type { Entry } from './core';

/** 离线中文意图解析。只产生候选条目和参数，不执行命令，也不改动目录对象。 */
export interface IntentMatch { key: string; values: Record<string,string>; reason: string; score: number }
const digits:Record<string,number>={零:0,〇:0,一:1,二:2,两:2,三:3,四:4,五:5,六:6,七:7,八:8,九:9};
export function parseChineseNumber(raw:string):number|undefined {
  const text=raw.normalize('NFKC');
  if(/^-?\d+(?:\.\d+)?$/.test(text))return Number(text);
  if(text==='半')return .5;
  if(text.includes('点')){
    const parts=text.split('点'),whole=parseChineseNumber(parts[0]);
    if(parts.length!==2||whole===undefined||!parts[1]||![...parts[1]].every(c=>c in digits))return undefined;
    const fraction=Number('0.'+[...parts[1]].map(c=>digits[c]).join(''));
    return whole+(text.startsWith('负')?-fraction:fraction);
  }
  const negative=text.startsWith('负');const s=negative?text.slice(1):text;
  if(!s||!/^[零〇一二两三四五六七八九十百千万]+$/.test(s))return undefined;
  if(!/[十百千万]/.test(s)){const n=Number([...s].map(c=>digits[c]).join(''));return negative?-n:n;}
  let total=0,section=0,current=0;
  for(const c of s){
    if(c in digits){current=digits[c];continue;}
    const unit=({十:10,百:100,千:1000,万:10000} as Record<string,number>)[c];
    if(unit===10000){total+=(section+current||1)*unit;section=0;}
    else section+=(current||1)*unit;
    current=0;
  }
  const value=total+section+current;return negative?-value:value;
}
const numberPattern='(-?\\d+(?:\\.\\d+)?|负?[零〇一二两三四五六七八九十百千万]+(?:点[零〇一二两三四五六七八九]+)?|半)';
const gain=/(?:获得|获取|得到|给我|给点|给予|增加|加上|加点|补充|补满|恢复|回复|需要|补|加|想要|我要|来)|^给/;
const lose=/(?:减少|减去|减掉|扣除|扣掉|移除|消耗|减|扣)/;
const normalize=(s:string)=>s.normalize('NFKC').toLowerCase().replace(/[\s，。！？、,.!?：:；;]/g,'');
function quantity(query:string,noun:string):number|undefined {
  const before=query.match(new RegExp(numberPattern+'\\s*(?:个|枚|把|颗|块|份|只|点)?\\s*(半)?\\s*(?:的)?(?:'+noun+')'));
  const after=query.match(new RegExp('(?:'+noun+')\\s*(?:增加|减少|恢复|回复|加|减|扣|补)?\\s*'+numberPattern+'\\s*(?:个|枚|把|颗|块|点)?'));
  const raw=before?.[1]??after?.[1];const n=raw===undefined?undefined:parseChineseNumber(raw);
  return n!==undefined&&before?.[2]?n+(n<0?-.5:.5):n;
}

export function resolveIntents(rawQuery:string,items:Entry[]):IntentMatch[]{
  if(rawQuery.length>200||/[\r\n\0]/.test(rawQuery))return [];
  const q=rawQuery.normalize('NFKC').toLowerCase().replace(/[\s，。！？、!?：:；;]/g,'');if(!q||/(?:不要|不用|别给|别加|别开|不想|不需要)/.test(q))return [];
  const matches:IntentMatch[]=[];
  const add=(key:string,values:Record<string,string>,reason:string,score=1500)=>{if(items.some(e=>e.key===key))matches.push({key,values,reason,score});};
  const isGain=gain.test(q),isLoss=lose.test(q);
  // 一条查询可以出现不同资源，各自生成独立候选，不拼接多条命令。
  const resources:[string,string,string,number][]=[
    ['coins','金币|硬币|块钱|金钱|钱','金币',1],['bombs','炸弹','炸弹',1],['keys','钥匙','钥匙',1],
    ['max-hearts','心之容器|心容器|血上限|生命上限|最大生命','心之容器',2],
    ['soul-hearts','魂心|蓝心','魂心',2],['black-hearts','黑心','黑心',2],
    ['bone-hearts','骨心','骨心',1],['eternal-hearts','永恒之心|白心','永恒之心',1],
    ['golden-hearts','金心','金心',1],['rotten-hearts','腐心|腐烂心','腐心',1],
    ['hearts','红心|血量|生命值|回血|血','红心',2]
  ];
  if(isGain||isLoss){
    for(const [id,noun,label,multiplier] of resources){
      if(!new RegExp(noun).test(q))continue;
      if(id==='hearts'&&/血上限|最大生命|生命上限/.test(q))continue;
      const n=quantity(q,noun), values:Record<string,string>={};
      if(n!==undefined)values.amount=String((isLoss?-Math.abs(n):n)*multiplier);
      // 只在明确提到玩家时取玩家编号，避免把资源数量当作玩家索引。
      const player=q.match(/(?:玩家|p)([1-4一二三四])(?:号)?/);
      if(player)values.player=String((parseChineseNumber(player[1])??1)-1);
      if(isLoss&&n===undefined)values.amount='-1';
      add('resource:'+id,values,`${isLoss||(n!==undefined&&n<0)?'减少':'增加'}${n===undefined?'（数量可调整）':Math.abs(n)}${label}${multiplier===2&&n!==undefined?`（${values.amount} 个半心单位）`:''}`);
    }
  }
  // 原版道具授予的飞行会经过游戏的正常属性刷新；不直接改写 CanFly 缓存属性。
  if(/飞行|飞天|飞起来|让我飞|我要飞|能飞/.test(q)){
    const off=/关闭|关掉|取消|禁用|停止|移除/.test(q);
    add('c:20',{action:off?'remove':'giveitem'},off?'移除超凡升天；其他来源的飞行可能仍保留':'通过超凡升天获得飞行（会添加道具）');
  }
  if(/(?:重开|重置|重打|重新开始|重新生成|重新打)(?:一下|下)?(?:本关|本层|当前关卡|当前层|当前楼层|这一关|这一层|本楼层)|^(?:当前楼层|本关|本层)(?:重开|重置|重打)$/.test(q)){
    add('cmd:restart-floor',{},'重置当前楼层，保留楼层分支；会重置整层进度');
    add('cmd:rewind',{},'如果想回溯房间，可选择这一项',650);
    add('cmd:restart',{},'如果想从头开始新一局，可选择这一项',600);
  }else if(/(?:重开|重置|重打|回到|回溯|倒回|返回)(?:一下|下)?(?:本房|本房间|当前房间|这个房间|上个房间)|后悔|撤回|回退/.test(q)){
    add('cmd:rewind',{},'房间回溯，类似发光沙漏；回退位置由游戏房间历史决定');
  }else if(/^(?:帮我|请|我想)?(?:重开|重新开始|重新开局|重新开一局|重新开始一局|重开游戏|重开这局|从头开始|重新来一局|重来一局)(?:吧|一下)?$/.test(q)){
    add('cmd:restart',{},'结束当前对局，以当前角色重新开局');
  }
  for(const [pattern,flag,label] of [[/无敌|不受伤|不会受伤/,'3','无敌'],[/无限充能|无限能量|一直满充能|主动道具满充能/,'8','主动道具持续满充能'],[/显示伤害|伤害数字/,'7','显示伤害'],[/显示碰撞|碰撞箱/,'6','伤害碰撞范围']] as const){
    if(pattern.test(q))add('cmd:debug',{flag},`切换${label}；当前开关状态需在游戏中确认`);
  }
  if(/刷新商店|重置商店|刷新房间道具|重置房间道具/.test(q))add('cmd:restock',{},'重置当前房间的道具底座和商店物品');
  // “获得神秘礼物”“移除硫磺火”等口语前缀，名称仍由现有目录核实。
  const itemRequest=q.match(/^(?:请|帮我|我想)?(获得|获取|得到|给我|给予|移除|删除|去掉|生成|刷出)(?:一个|一张|一颗|一枚)?(.+?)(?:吧)?$/);
  if(itemRequest){
    const action=/移除|删除|去掉/.test(itemRequest[1])?'remove':/生成|刷出/.test(itemRequest[1])?'spawn':'giveitem';
    const target=normalize(itemRequest[2]);
    for(const entry of items){
      if(entry.kind!=='item'||!entry.prefix)continue;
      if(action==='remove'&&!['c','t'].includes(entry.prefix)||action==='spawn'&&entry.prefix==='p')continue;
      if([entry.name,entry.english,entry.prefix+entry.id,...entry.aliases??[]].some(s=>normalize(s)===target))add(entry.key,{action},`${action==='remove'?'移除':action==='spawn'?'生成地面物品':'获取'}${entry.name}`,1700);
    }
  }
  const destination=q.match(/^(?:传送到|传送去|前往|去|跳到|进入)(.+)$/)?.[1];
  if(destination)for(const entry of items){if(entry.category==='stages'&&normalize(entry.name)===destination)add(entry.key,{},`传送到${entry.name}（普通模式楼层）`);}
  return matches;
}

/** 有限的错字容错，短词与纯数字不猜测，避免把无效 ID 换成其他对象。 */
export function fuzzyNameMatch(query:string,names:string[]):boolean{
  if(query.length<3||query.length>36||/^[\da-z: ._-]*\d[\da-z: ._-]*$/i.test(query))return false;
  const allowance=query.length>=7?2:1;
  return names.some(name=>{
    if(!name||Math.abs(query.length-name.length)>allowance)return false;
    let previous=Array.from({length:name.length+1},(_,i)=>i);
    for(let i=1;i<=query.length;i++){
      const row=[i];for(let j=1;j<=name.length;j++)row[j]=Math.min(row[j-1]+1,previous[j]+1,previous[j-1]+(query[i-1]===name[j-1]?0:1));
      if(Math.min(...row)>allowance)return false;previous=row;
    }
    return previous[name.length]<=allowance;
  });
}
