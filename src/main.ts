import './style.css';
import './intent.css';
import { entries, byKey, categories, categoryLabel, version, coverage, provenance, fieldsFor, defaultsFor, buildCommand, createSearchIndex, searchMatches, type SearchMatch, type Entry, type UserState, type HistoryItem } from './core';

interface Reply { ok: boolean; error?: string; warning?: string; state?: UserState; recovered?: boolean; copied?: boolean }
interface Bridge {
  loadState():Promise<Reply>; favorite(key:string):Promise<Reply>;
  copy(data:{entryKey:string;label:string;command:string}):Promise<Reply>;
  copyHistory(id:string):Promise<Reply>; deleteHistory(id:string):Promise<Reply>;
  clearHistory():Promise<Reply>; setOnTop(value:boolean):Promise<Reply>;
}
declare global { interface Window { isaac?: Bridge } }
const esc=(s:unknown)=>String(s??'').replace(/[&<>"']/g,x=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[x]!));
const $=<T extends Element = HTMLElement>(selector:string)=>document.querySelector<T>(selector)!;
const index=createSearchIndex(entries);
let state:UserState={version:1,favorites:[],history:[],alwaysOnTop:false};
let category='all', view='catalog', query='', limit=80;
let selected=byKey.get('c:515')!, values=defaultsFor(selected), selectedHistory:HistoryItem|undefined;
let results:Entry[]=[], copyBusy=false, toastTimer:ReturnType<typeof setTimeout>;
let matches=new Map<string,SearchMatch>();
const counts=Object.fromEntries(categories.map(([id])=>[id,id==='all'?entries.length:entries.filter(x=>x.category===id).length]));
const badge=(id:string)=>`<span class="category-badge ${esc(id)}">${esc(categoryLabel(id))}</span>`;
const app=$('#app');
app.innerHTML=`
  <header class="app-header">
    <div class="brand-mark">⌘</div><div class="brand"><h1>以撒控制台助手</h1><span>ISAAC CONSOLE COMPANION</span></div>
    <span class="version-badge"><i></i> Repentance 1.7.9b</span>
    <div class="header-actions"><button class="quiet-button" id="help-button" title="使用说明">ⓘ <span>使用说明</span></button><button class="quiet-button" id="pin-button" aria-pressed="false">♧ <span>窗口置顶</span></button></div>
  </header>
  <div class="workspace">
    <aside class="sidebar"><div class="nav-label">命令资料库</div><nav id="category-nav" aria-label="命令分类"></nav>
      <div class="nav-divider"></div><div class="nav-label">我的工作台</div>
      <button class="nav-item" data-view="favorites"><span class="nav-icon">☆</span><span>我的收藏</span><small id="favorite-count">0</small></button>
      <button class="nav-item" data-view="history"><span class="nav-icon">◷</span><span>最近复制</span><small id="history-count">0</small></button>
      <div class="sidebar-bottom"><span class="offline-dot"></span> 完全离线可用<br><small>命令只复制，由你在游戏中粘贴</small></div>
    </aside>
    <main class="library">
      <div class="library-heading"><div><div class="eyebrow" id="eyebrow">COMMAND LIBRARY</div><h2 id="view-title">全部命令</h2></div><span class="total-count" id="total-count"></span></div>
      <div class="search-box"><span class="search-icon">⌕</span><input id="search" type="search" placeholder="试试：获得两个金币、开启飞行…" aria-label="搜索命令" autocomplete="off" spellcheck="false"><button id="clear-search" title="清空搜索" aria-label="清空搜索" hidden>×</button><kbd>Ctrl K</kbd></div>
      <div class="list-toolbar"><span id="result-count"></span><button class="text-button danger" id="clear-history" hidden>清空记录</button><span id="search-tip">模糊搜索已开启</span></div>
      <div class="result-list" id="result-list" tabindex="0" aria-label="搜索结果"></div>
      <div class="library-footer"><span>⌨</span> <span>Ctrl + K 搜索</span><span>Ctrl + Enter 复制</span></div>
    </main>
    <section class="detail" id="detail" aria-label="命令详情"></section>
  </div>
  <div class="toast" id="toast" role="status" aria-live="polite" hidden></div>
  <dialog id="help-dialog"><div class="dialog-head"><div><div class="eyebrow">GETTING STARTED</div><h2>从查询到游戏，只需三步</h2></div><button class="icon-button" id="close-help" aria-label="关闭使用说明">×</button></div>
    <ol class="help-steps"><li><b>直接说你想做什么</b><p>模糊搜索默认开启。可输入“获得两个金币”“开启飞行”“重开本关”，也支持原来的名称、拼音和 ID 搜索。</p></li><li><b>核对理解结果并复制</b><p>识别到的数量和操作会自动填入右侧，仍可手动修改。“重开本关”按重置当前楼层理解，并显示其他候选；飞行通过获取超凡升天实现。</p></li><li><b>在游戏控制台粘贴</b><p>进入一局游戏，切换英文键盘，按 ~ 打开控制台，Ctrl + V 粘贴并回车。匹配结果仅供选择，不自动执行。</p></li></ol>
    <div class="help-box"><b>控制台开启方式</b><p>关闭游戏，在 Documents\\My Games\\Binding of Isaac Repentance\\options.ini 中设置 EnableDebugConsole=1。建议修改前自行备份。软件不会修改游戏配置。</p></div>
    <div class="help-box"><b>版本与目录</b><p>${esc(version)} · ${entries.length.toLocaleString()} 条记录</p><p>${esc(coverage)}</p><p>道具 721 · 饰品 189 · 卡牌／符文 97 · 胶囊效果 50。内部保留的 ID 与实际游戏可获得状态可能不同。</p><p>楼层表为普通模式；房间编号依赖楼层。部分实体保留英文原名。参数范围检查不能代替游戏内效果验证。</p></div>
    <details><summary>资料来源与本地记录</summary><p>命令语法：wofsauge/IsaacDocs；物品资料：roiiiu/isaac-cheat-sheet（MIT）；本机游戏枚举、本机 EID 名称。完整来源和许可见发布包 THIRD-PARTY-NOTICES.md。</p><p>物品数据版本：${esc(provenance.cheatSheetRevision.slice(0,12))}。每条记录都可在详情底部查看来源。</p><p>收藏、最近 100 条复制和置顶偏好保存在本机应用数据目录的 state-v1.json。损坏记录将先备份再恢复默认值。软件不读取存档、不发送游戏按键、不安装 Mod。</p></details>
    <button id="help-done" class="primary-button">开始查询 <span>→</span></button>
  </dialog>`;

$('#category-nav').innerHTML=categories.map(([id,name,icon])=>`<button class="nav-item ${id==='all'?'active':''}" data-category="${id}"><span class="nav-icon">${icon}</span><span>${name}</span><small>${counts[id]}</small></button>`).join('');
function toast(message:string,error=false){const el=$('#toast');clearTimeout(toastTimer);el.textContent=message;el.classList.toggle('error',error);el.hidden=false;toastTimer=setTimeout(()=>el.hidden=true,4000);}
async function invoke(fn:()=>Promise<Reply>):Promise<Reply>{try{const reply=await fn();if(!reply.ok)toast(reply.error??'操作失败，请重试。',true);if(reply.state){state=reply.state;updateStateUI();}if(reply.warning)toast(reply.warning,true);return reply;}catch{return {ok:false,error:'无法连接桌面功能，请重新打开软件。'};}}
function updateStateUI(){
  $('#favorite-count').textContent=String(state.favorites.length);$('#history-count').textContent=String(state.history.length);
  $('#pin-button').setAttribute('aria-pressed',String(state.alwaysOnTop));$('#pin-button').classList.toggle('pinned',state.alwaysOnTop);
  const b=$('#favorite-button');if(b){const active=state.favorites.includes(selected.key);b.innerHTML=active?'★ 已收藏':'☆ 收藏';b.setAttribute('aria-pressed',String(active));b.classList.toggle('saved',active);}
}
function setView(next:string,cat='all'){
  view=next;category=cat;limit=80;selectedHistory=undefined;query='';
  $<HTMLInputElement>('#search').value='';$('#clear-search').hidden=true;
  document.querySelectorAll<HTMLElement>('[data-category]').forEach(el=>el.classList.toggle('active',view==='catalog'&&el.dataset.category===cat));
  document.querySelectorAll<HTMLElement>('[data-view]').forEach(el=>el.classList.toggle('active',el.dataset.view===view));
  $('#view-title').textContent=view==='favorites'?'我的收藏':view==='history'?'最近复制':categoryLabel(cat);
  $('#eyebrow').textContent=view==='history'?'RECENTLY COPIED':view==='favorites'?'YOUR FAVORITES':'COMMAND LIBRARY';
  $('#clear-history').hidden=view!=='history';$('#search-tip').hidden=view==='history';
  renderList(true);
}
function row(e:Entry){
  return `<button class="result-row ${!selectedHistory&&selected.key===e.key?'selected':''}" data-entry="${esc(e.key)}"><div class="result-icon ${esc(e.category)}">${esc(categories.find(x=>x[0]===e.category)?.[2]??'›_')}</div><div class="result-content"><div class="result-title">${esc(e.name)} ${state.favorites.includes(e.key)?'<span class="star">★</span>':''}</div><div class="result-subtitle">${esc(e.english)} <span>· ${esc(e.prefix?e.prefix+e.id:e.id)}</span></div>${matches.get(e.key)?.reason?`<div class="match-reason">${esc(matches.get(e.key)!.reason)}</div>`:''}</div><span class="result-arrow">›</span></button>`;
}
function renderList(choose=false,preferFirst=false){
  const list=$('#result-list');
  if(view==='history'){
    const q=query.toLowerCase();const records=state.history.filter(h=>`${h.label} ${h.command}`.toLowerCase().includes(q));
    $('#result-count').textContent=`${records.length} 条复制记录`;$('#total-count').textContent='最近 100 条';
    list.innerHTML=records.length?records.map(h=>`<div class="history-row ${selectedHistory?.id===h.id?'selected':''}"><button class="history-select" data-history="${esc(h.id)}"><b>${esc(h.label)}</b><code>${esc(h.command)}</code><small>${esc(new Date(h.time).toLocaleString('zh-CN',{hour12:false}))}</small></button><button class="history-delete icon-button" data-delete="${esc(h.id)}" title="删除这条记录" aria-label="删除 ${esc(h.label)} 的记录">×</button></div>`).join(''):'<div class="empty-state"><span>◷</span><h3>还没有复制记录</h3><p>复制过的命令会保存在这里。<br>可以直接按原参数再次复制。</p></div>';
    if(choose){if(records.length) selectHistory(records[0].id);else renderEmpty('这里会显示你的复制记录','先去资料库找一条想用的命令。');}
    return;
  }
  let found=searchMatches(index,query,category,view==='favorites'?new Set(state.favorites):undefined);
  let crossCategory=false;
  if(view==='catalog'&&query&&found.length===0&&category!=='all'){
    const global=searchMatches(index,query);
    if(global.some(x=>x.score>=1500)){found=global;crossCategory=true;}
  }
  $('#search-tip').textContent=crossCategory?'模糊搜索 · 跨分类匹配':'模糊搜索已开启';
  matches=new Map(found.map(x=>[x.entry.key,x]));results=found.map(x=>x.entry);
  $('#result-count').textContent=`${results.length.toLocaleString()} 条${query?'匹配结果':'记录'}`;
  $('#total-count').textContent=`${results.length.toLocaleString()} 条`;
  list.innerHTML=results.length?results.slice(0,limit).map(row).join('')+(results.length>limit?`<button id="load-more" class="load-more">继续显示 · 还有 ${results.length-limit} 条</button>`:''):`<div class="empty-state"><span>${view==='favorites'?'☆':'⌕'}</span><h3>${view==='favorites'&&!query?'收藏常用命令':'没有找到匹配结果'}</h3><p>${view==='favorites'&&!query?'点击详情中的“收藏”，下次更快找到。':'试试简短名称、英文、拼音或 ID。'}</p></div>`;
  if(choose){
    if(results.length){const next=preferFirst?results[0]:results.find(x=>x.key===selected.key)??results[0];selectEntry(next.key,false);}
    else renderEmpty(view==='favorites'?'你的常用命令，放在这里':'换个关键词试试','可以试试「神秘礼物」「加钱」「c515」或「sm lw」。');
  }
}
function renderEmpty(title:string,body:string){$('#detail').innerHTML=`<div class="detail-empty"><div class="big-mark">⌘</div><h2>${esc(title)}</h2><p>${esc(body)}</p></div>`;}
function sourceLabel(e:Entry){return e.source==='isaacdocs'?'IsaacDocs · 原生控制台文档':e.source==='local-luadocs'?'本机 LuaDocs · 玩家资源接口':e.source==='cheat-sheet+local-enums'?'isaac-cheat-sheet（MIT）＋本机枚举':e.source==='local-names+local-enums'?'本机 EID 名称＋本机枚举':'本机 resources/scripts/enums.lua';}
function renderDetail(){
  const e=selected;
  const fields=fieldsFor(e), example=buildCommand(e,defaultsFor(e)).command;
  $('#detail').innerHTML=`<div class="detail-scroll"><div class="detail-top">${badge(e.category)}<button id="favorite-button" class="favorite-button" aria-pressed="false">☆ 收藏</button></div>
    <div class="detail-title"><h2>${esc(e.name)}</h2><p>${esc(e.english)}${e.prefix?` <span class="id-chip">${esc(e.prefix+e.id)}</span>`:''}</p></div>
    <p class="description">${esc(e.description)}</p>
    ${!selectedHistory&&matches.get(e.key)?.reason?`<div id="intent-hint" class="intent-hint" role="status"><b>已理解你的输入</b><p>${esc(matches.get(e.key)!.reason)}</p><small>参数可继续修改，复制后由你在游戏中执行。</small></div>`:''}
    ${e.quality?`<div class="meta-line"><span>道具品质</span><b>${esc(e.quality)}</b>${e.charge?`<span>充能</span><b>${esc(e.charge)}</b>`:''}</div>`:''}
    ${selectedHistory?`<div class="note-box">◷ 这是一条历史记录，将复制当时保存的完整命令。</div>`:fields.length?`<div class="section-label"><span>设置参数</span><small>PARAMETERS</small></div><form id="parameters" class="parameters">${fields.map(f=>`<label class="field"><span>${esc(f.label)}</span>${f.type==='select'?`<select name="${esc(f.key)}" aria-label="${esc(f.label)}">${f.options!.map(o=>`<option value="${esc(o.value)}"${values[f.key]===o.value?' selected':''}>${esc(o.label)}</option>`).join('')}</select>`:`<input name="${esc(f.key)}" type="${f.type==='number'?'number':'text'}" value="${esc(values[f.key])}" aria-label="${esc(f.label)}" ${f.type==='number'?`min="${f.min}" max="${f.max}" step="1"`:''} autocomplete="off" spellcheck="false">`}${f.hint?`<small>${esc(f.hint)}</small>`:''}</label>`).join('')}</form>`:'<div class="no-parameters"><span>✓</span> 这条命令无需填写参数</div>'}
    ${e.note?`<div class="note-box">${esc(e.note)}</div>`:''}
    ${!selectedHistory&&example?`<details class="syntax"><summary>语法与示例</summary><p>语法：<code>${esc(e.template??(e.kind==='item'?`${e.prefix==='p'?'giveitem':'giveitem / spawn'} ${e.prefix}<ID>`:e.kind==='entity'?'spawn 类型.变体.子类型[.精英颜色]':e.command))}</code></p><p>示例：<code>${esc(example)}</code></p></details>`:''}
    <div class="source-line"><span>资料来源</span><p>${esc(sourceLabel(e))}</p><span>适用版本</span><p>${esc(e.version)}</p></div>
    </div><div class="command-panel"><div class="section-label"><span>命令预览</span><small>READY TO COPY</small></div><textarea id="command-preview" readonly aria-label="完整命令" spellcheck="false"></textarea><p id="validation-error" class="validation-error" role="status"></p><button id="copy-button" class="primary-button"><span>▣ 复制命令</span><kbd>Ctrl ↵</kbd></button><p class="copy-footnote">只复制命令文本 · 在游戏控制台粘贴后回车</p></div>`;
  updateStateUI();updatePreview();
  $('#favorite-button').addEventListener('click',async()=>{
    if(!window.isaac){toast('请通过桌面软件使用收藏功能。',true);return;}
    const reply=await invoke(()=>window.isaac!.favorite(e.key));if(reply.ok){renderList(view==='favorites');updateStateUI();}
  });
  $('#parameters')?.addEventListener('submit',event=>event.preventDefault());
  $('#parameters')?.addEventListener('input',event=>{const field=event.target as HTMLInputElement;values[field.name]=field.value;updatePreview();});
  $('#copy-button').addEventListener('click',()=>void copyCurrent());
}
function selectEntry(key:string,refresh=true){const e=byKey.get(key);if(!e)return;selected=e;values={...defaultsFor(e),...matches.get(key)?.values};selectedHistory=undefined;renderDetail();if(refresh)renderList();else document.querySelectorAll<HTMLElement>('[data-entry]').forEach(el=>el.classList.toggle('selected',el.dataset.entry===key));}
function selectHistory(id:string){const h=state.history.find(x=>x.id===id);if(!h)return;selectedHistory=h;selected=byKey.get(h.entryKey)??selected;values=defaultsFor(selected);renderDetail();renderList();}
function updatePreview(){
  const built=selectedHistory?{command:selectedHistory.command,error:''}:buildCommand(selected,values);
  $<HTMLTextAreaElement>('#command-preview').value=built.command;
  $('#validation-error').textContent=built.error;
  $<HTMLButtonElement>('#copy-button').disabled=!!built.error||!built.command||copyBusy;
}
async function copyCurrent(){
  if(copyBusy||searchComposing)return;
  // 复制快捷键可能早于搜索防抖完成；先解析最新输入，避免复制上一条结果。
  if($<HTMLInputElement>('#search').value!==query)commitSearch();
  if(!document.querySelector('#copy-button'))return;
  const built=selectedHistory?{command:selectedHistory.command,error:''}:buildCommand(selected,values);
  if(built.error||!built.command)return;
  if(!window.isaac){toast('请打开桌面 EXE 使用复制功能，或手动选择命令文本。',true);return;}
  copyBusy=true;updatePreview();
  const reply=await invoke(()=>selectedHistory?window.isaac!.copyHistory(selectedHistory.id):window.isaac!.copy({entryKey:selected.key,label:selected.name,command:built.command}));
  copyBusy=false;updatePreview();
  if(reply.ok){if(!reply.warning)toast('✓ 已复制，可以在游戏控制台粘贴');renderList();}else{toast(reply.error??'复制失败，请手动选择命令文本复制。',true);$<HTMLTextAreaElement>('#command-preview').select();}
}
document.querySelectorAll<HTMLElement>('[data-category]').forEach(el=>el.addEventListener('click',()=>setView('catalog',el.dataset.category)));
document.querySelectorAll<HTMLElement>('[data-view]').forEach(el=>el.addEventListener('click',()=>setView(el.dataset.view!)));
$('#result-list').addEventListener('click',async event=>{
  const target=event.target as HTMLElement;
  const e=target.closest<HTMLElement>('[data-entry]');if(e){selectEntry(e.dataset.entry!);return;}
  const h=target.closest<HTMLElement>('[data-history]');if(h){selectHistory(h.dataset.history!);return;}
  const del=target.closest<HTMLElement>('[data-delete]');if(del&&window.isaac){const reply=await invoke(()=>window.isaac!.deleteHistory(del.dataset.delete!));if(reply.ok)renderList(selectedHistory?.id===del.dataset.delete);return;}
  if(target.closest('#load-more')){limit+=80;renderList();}
});
let debounce:ReturnType<typeof setTimeout>;
let searchComposing=false;
function commitSearch(){clearTimeout(debounce);query=$<HTMLInputElement>('#search').value;limit=80;$('#clear-search').hidden=!query;selectedHistory=undefined;renderList(true,true);$('#result-list').scrollTop=0;}
$('#search').addEventListener('compositionstart',()=>{searchComposing=true;clearTimeout(debounce);});
$('#search').addEventListener('compositionend',()=>{searchComposing=false;commitSearch();});
$('#search').addEventListener('input',()=>{clearTimeout(debounce);if(!searchComposing)debounce=setTimeout(commitSearch,100);});
$('#clear-search').addEventListener('click',()=>{clearTimeout(debounce);query='';$<HTMLInputElement>('#search').value='';$('#clear-search').hidden=true;limit=80;renderList(true);$<HTMLInputElement>('#search').focus();});
$('#pin-button').addEventListener('click',async()=>{if(window.isaac){const reply=await invoke(()=>window.isaac!.setOnTop(!state.alwaysOnTop));if(reply.ok)toast(state.alwaysOnTop?'窗口已置顶':'已取消窗口置顶');}});
$('#clear-history').addEventListener('click',async()=>{if(window.isaac){const reply=await invoke(()=>window.isaac!.clearHistory());if(reply.ok){selectedHistory=undefined;renderList(true);toast('复制记录已清空');}}});
const dialog=$<HTMLDialogElement>('#help-dialog');
$('#help-button').addEventListener('click',()=>dialog.showModal());
$('#close-help').addEventListener('click',()=>dialog.close());$('#help-done').addEventListener('click',()=>{dialog.close();$<HTMLInputElement>('#search').focus();});
document.addEventListener('keydown',event=>{
  if(event.ctrlKey&&event.key.toLowerCase()==='k'){event.preventDefault();if(!dialog.open){$<HTMLInputElement>('#search').focus();$<HTMLInputElement>('#search').select();}}
  if(event.ctrlKey&&event.key==='Enter'&&!dialog.open){event.preventDefault();void copyCurrent();}
});
async function init(){
  if(window.isaac){const reply=await invoke(()=>window.isaac!.loadState());if(reply.recovered)toast('使用记录损坏，已保留备份并恢复默认值。',true);if(!reply.ok)toast(reply.error??'无法读取使用记录',true);}
  else toast('浏览器预览模式；收藏、复制和置顶请在桌面 EXE 中使用。');
  renderList();renderDetail();updateStateUI();
}
void init();
