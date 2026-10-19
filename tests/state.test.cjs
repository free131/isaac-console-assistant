const { test }=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');const os=require('node:os');const path=require('node:path');
const {emptyState,readState,writeState,normalize}=require('../electron/state.cjs');
function withFile(fn){const root=path.join(__dirname,'../.cache/state-tests');fs.mkdirSync(root,{recursive:true});const dir=fs.mkdtempSync(path.join(root,'run-'));try{fn(path.join(dir,'state-v1.json'));}finally{fs.rmSync(dir,{recursive:true,force:true});}}
test('首次使用与收藏、历史、置顶保存恢复',()=>withFile(file=>{
  assert.deepEqual(readState(file),{state:emptyState(),recovered:false});
  const state={...emptyState(),favorites:['c:1','t:1'],alwaysOnTop:true,history:[{id:'one',entryKey:'c:1',label:'悲伤洋葱',command:'giveitem c1',time:'2026-10-18T01:00:00.000Z'}]};
  writeState(file,state);assert.deepEqual(readState(file).state,state);
}));
test('记录损坏先保留原内容备份，再给默认值',()=>withFile(file=>{
  fs.writeFileSync(file,'{"broken":');const r=readState(file);assert.equal(r.recovered,true);assert.deepEqual(r.state,emptyState());
  assert.equal(fs.readFileSync(r.backup,'utf8'),'{"broken":');assert.equal(fs.readFileSync(file,'utf8'),'{"broken":');
  writeState(file,r.state);assert.equal(fs.readFileSync(r.backup,'utf8'),'{"broken":');
}));
test('历史限制 100 条、过滤坏条目且收藏按类型区分',()=>{
  const state=normalize({...emptyState(),favorites:['c:1','t:1','c:1',null],history:Array.from({length:105},(_,i)=>({id:String(i),entryKey:'p:0',label:'臭屁',command:'giveitem p0',time:'2026-10-18'}))});
  assert.deepEqual(state.favorites,['c:1','t:1']);assert.equal(state.history.length,100);assert.equal(state.history[0].id,'0');
  assert.equal(normalize({...emptyState(),history:[{id:'x',entryKey:'c:1',label:'x',command:'a\nb',time:'now'}]}).history.length,0);
});
