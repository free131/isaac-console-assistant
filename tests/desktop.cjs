// 通过真实 Electron 窗口验收。仅使用独立测试记录，不写入真实使用记录。
const { _electron: electron } = require('playwright');
const assert=require('node:assert/strict');const fs=require('node:fs');const path=require('node:path');
const root=path.resolve(__dirname,'..');
const artifacts=path.join(root,'test-artifacts');fs.mkdirSync(artifacts,{recursive:true});
const userData=fs.mkdtempSync(path.join(artifacts,'desktop-state-'));
const executable=process.env.ISAAC_TEST_EXE || require('electron');
let app,page;const checks=[],errors=[];
const check=(name)=>{checks.push(name);console.log('PASS '+name);};
async function launch(){
  const env={...process.env,ISAAC_TEST_DATA:userData};delete env.ELECTRON_RUN_AS_NODE;
  app=await electron.launch({executablePath:executable,args:process.env.ISAAC_TEST_EXE?[]:[root],env,timeout:45000});
  page=await app.firstWindow({timeout:30000});
  page.on('pageerror',e=>errors.push(e.message));
  await page.locator('#detail h2').waitFor();
  return page;
}
async function search(q){await page.locator('#search').fill(q);await page.waitForFunction(q=>document.querySelector('#search').value===q&&document.querySelector('#clear-search').hidden===!q,q);await page.waitForTimeout(180);}
async function copied(text){await page.locator('#copy-button').click();await page.waitForFunction(()=>!document.querySelector('#copy-button').disabled);assert.equal(await app.evaluate(({clipboard})=>clipboard.readText()),text);}
async function screenshot(name){
  // Playwright 的页面截图在 Electron 非 100% 缩放时会裁剪；使用原生窗口捕获。
  const url=await app.evaluate(async({BrowserWindow})=>(await BrowserWindow.getAllWindows()[0].capturePage()).toDataURL());
  fs.writeFileSync(path.join(artifacts,name),Buffer.from(url.split(',')[1],'base64'));
}
async function noOverflow(){return page.evaluate(()=>({body:document.documentElement.scrollWidth>innerWidth,detail:document.querySelector('#detail').scrollWidth>document.querySelector('#detail').clientWidth,button:!!document.querySelector('#copy-button')&&document.querySelector('#copy-button').getBoundingClientRect().right<=innerWidth}));}
(async()=>{
  try{
    await launch();
    assert.equal(await app.evaluate(({app})=>app.getVersion()),require('../package.json').version);
    assert.equal(await page.locator('#command-preview').inputValue(),'giveitem c515');
    assert.equal(await page.evaluate(()=>typeof require),'undefined');
    const prefs=await app.evaluate(({BrowserWindow})=>{const w=BrowserWindow.getAllWindows()[0],p=w.webContents.getLastWebPreferences();return {node:p.nodeIntegration,isolated:p.contextIsolation,sandbox:p.sandbox};});
    assert.deepEqual(prefs,{node:false,isolated:true,sandbox:true});check('真实桌面启动与隔离配置');
    for(const q of ['神秘礼物','Mystery Gift','幸运礼物','smlw','shenmiliwu','c515']){await search(q);assert.ok(await page.locator('[data-entry="c:515"]').count(),q);}
    check('六种实际输入搜索');
    assert.equal(await page.locator('#search-tip').innerText(),'模糊搜索已开启');
    for(const q of ['获得两个金币','给我两枚硬币','我想要2块钱']){
      await search(q);assert.equal(await page.locator('.result-row').first().getAttribute('data-entry'),'resource:coins');
      assert.equal(await page.locator('[name="amount"]').inputValue(),'2');
      assert.equal(await page.locator('#command-preview').inputValue(),'lua Isaac.GetPlayer(0):AddCoins(2)');
      assert.match(await page.locator('#intent-hint').innerText(),/增加2金币/);
    }
    await copied('lua Isaac.GetPlayer(0):AddCoins(2)');await screenshot('intent-search.png');check('默认开启的口语搜索、数量填入与实际复制');
    await page.locator('[name="amount"]').fill('9');await copied('lua Isaac.GetPlayer(0):AddCoins(9)');
    await search('获得三个金币');assert.equal(await page.locator('[name="amount"]').inputValue(),'3');
    await search('获得两百个金币');assert.equal(await page.locator('#copy-button').isDisabled(),true);
    await search('获得1.5个金币');assert.equal(await page.locator('#copy-button').isDisabled(),true);
    await search('获得两个金币');assert.equal(await page.locator('#copy-button').isDisabled(),false);check('数量校验、手动修改与连续查询不串参数');
    await search('开启飞行');assert.equal(await page.locator('#command-preview').inputValue(),'giveitem c20');assert.match(await page.locator('#intent-hint').innerText(),/会添加道具/);
    await search('关闭飞行');assert.equal(await page.locator('#command-preview').inputValue(),'remove c20');check('飞行匹配原版道具并说明影响');
    await search('重开本关');assert.equal(await page.locator('.result-row').first().getAttribute('data-entry'),'cmd:restart-floor');assert.match(await page.locator('#command-preview').inputValue(),/GetStageType\(\)/);
    assert.ok(await page.locator('[data-entry="cmd:rewind"]').count());assert.ok(await page.locator('[data-entry="cmd:restart"]').count());
    await search('重开当前房间');assert.equal(await page.locator('#command-preview').inputValue(),'rewind');
    await search('重开');assert.equal(await page.locator('#command-preview').inputValue(),'restart');check('本关、房间与新一局的意图区分');
    await search('硫磺活');assert.equal(await page.locator('.result-row').first().getAttribute('data-entry'),'c:118');check('有限错字容错');
    await page.locator('[data-category="trinkets"]').click();await search('获得两个金币');assert.equal(await page.locator('#command-preview').inputValue(),'lua Isaac.GetPlayer(0):AddCoins(2)');assert.match(await page.locator('#search-tip').innerText(),/跨分类/);check('其他分类中的口语意图仍可找到命令');
    // 不等待搜索防抖，立即复制也必须使用新查询的数量。
    await page.locator('#search').fill('获得四个金币');await page.keyboard.press('Control+Enter');
    await page.waitForFunction(()=>document.querySelector('#command-preview').value==='lua Isaac.GetPlayer(0):AddCoins(4)');
    assert.equal(await app.evaluate(({clipboard})=>clipboard.readText()),'lua Isaac.GetPlayer(0):AddCoins(4)');check('快速搜索后复制不会使用旧参数');
    await page.locator('[data-category="all"]').click();await search('c515');
    await page.locator('[data-entry="c:515"]').click();await copied('giveitem c515');check('原生系统剪贴板内容');
    await page.locator('select[name="action"]').selectOption('remove');assert.equal(await page.locator('#command-preview').inputValue(),'remove c515');
    await page.locator('select[name="action"]').selectOption('spawn');await copied('spawn 5.100.515');check('操作切换与生成命令');
    await page.locator('#favorite-button').click();await page.waitForFunction(()=>document.querySelector('#favorite-button').getAttribute('aria-pressed')==='true');
    await page.locator('[data-view="favorites"]').click();assert.equal(await page.locator('[data-entry="c:515"]').count(),1);check('收藏视图');
    await page.locator('[data-category="resources"]').click();await search('增加金币');await page.locator('[data-entry="resource:coins"]').click();
    await page.locator('[name="amount"]').fill('17');await copied('lua Isaac.GetPlayer(0):AddCoins(17)');
    await page.locator('[name="amount"]').fill('1.5');assert.equal(await page.locator('#copy-button').isDisabled(),true);assert.ok(await page.locator('#validation-error').innerText());
    await page.locator('[name="amount"]').fill('-7');assert.equal(await page.locator('#command-preview').inputValue(),'lua Isaac.GetPlayer(0):AddCoins(-7)');check('资源参数、负值和非法输入');
    await page.locator('[data-category="pills"]').click();await search('p0');await page.locator('[data-entry="p:0"]').click();await copied('giveitem p0');check('胶囊效果 ID 为零');
    await page.locator('[data-category="all"]').click();await search('xyzz完全没有这个物品');assert.equal(await page.locator('.result-row').count(),0);assert.ok(await page.locator('.empty-state').count());
    const beforeEmpty=await app.evaluate(({clipboard})=>clipboard.readText());await page.keyboard.press('Control+Enter');await page.waitForTimeout(50);assert.equal(await app.evaluate(({clipboard})=>clipboard.readText()),beforeEmpty);
    await page.locator('#clear-search').click();assert.ok(await page.locator('.result-row').count());check('空结果与清空查询');
    await page.locator('#pin-button').click();await page.waitForFunction(()=>document.querySelector('#pin-button').getAttribute('aria-pressed')==='true');
    let onTop=false;
    for(let i=0;i<30&&!onTop;i++){onTop=await app.evaluate(({BrowserWindow})=>BrowserWindow.getAllWindows()[0].isAlwaysOnTop());if(!onTop)await page.waitForTimeout(50);}
    assert.equal(onTop,true);check('真实窗口置顶');
    await page.locator('[data-view="history"]').click();const recent=(await page.locator('.history-select code').allTextContents());assert.ok(recent.includes('lua Isaac.GetPlayer(0):AddCoins(17)'));
    await page.locator('.history-select').filter({has:page.locator('code', {hasText:'AddCoins(17)'})}).click();await copied('lua Isaac.GetPlayer(0):AddCoins(17)');check('历史按原始参数复制');
    const count=Number(await page.locator('#history-count').innerText());await page.locator('.history-delete').first().click();await page.waitForFunction(n=>Number(document.querySelector('#history-count').textContent)===n,count-1);check('单独删除历史');
    await app.close();await launch();assert.equal(await page.locator('#favorite-count').innerText(),'1');assert.equal(await page.locator('#pin-button').getAttribute('aria-pressed'),'true');assert.equal(Number(await page.locator('#history-count').innerText()),count-1);check('关闭重启后恢复收藏、历史和置顶');
    await page.locator('[data-category="all"]').click();await search('c515');await page.locator('[data-entry="c:515"]').click();
    await screenshot('desktop-100.png');
    for(const zoom of [1.25,1.5]){
      await app.evaluate(({BrowserWindow},zoom)=>BrowserWindow.getAllWindows()[0].webContents.setZoomFactor(zoom),zoom);await page.waitForTimeout(220);
      assert.deepEqual(await noOverflow(),{body:false,detail:false,button:true});
      await screenshot(`desktop-${zoom*100}.png`);
      await copied('giveitem c515');
    }
    check('125%／150% 页面缩放布局和复制');
    await app.evaluate(({BrowserWindow})=>BrowserWindow.getAllWindows()[0].setSize(850,620));await page.waitForTimeout(200);assert.deepEqual(await noOverflow(),{body:false,detail:false,button:true});check('最小窗口与 150% 缩放');
    await app.evaluate(({BrowserWindow})=>{const w=BrowserWindow.getAllWindows()[0];w.webContents.setZoomFactor(1);w.setSize(1320,860);});
    await page.locator('#help-button').click();assert.equal(await page.locator('#help-dialog').evaluate(el=>el.open),true);await page.locator('#help-done').click();check('使用说明打开关闭');
    await page.locator('[data-view="history"]').click();await page.locator('#clear-history').click();await page.waitForFunction(()=>document.querySelector('#history-count').textContent==='0');check('清空历史');
    await app.close();
    const statePath=path.join(userData,'state-v1.json');fs.writeFileSync(statePath,'{broken state','utf8');
    await launch();assert.equal(await page.locator('#favorite-count').innerText(),'0');assert.ok(fs.readdirSync(userData).some(x=>x.startsWith('state-v1.json.corrupt-')));check('真实启动时备份损坏记录并恢复');
    assert.deepEqual(errors,[]);check('无渲染层异常');
    const report={passed:true,softwareVersion:await app.evaluate(({app})=>app.getVersion()),executable,checks,errors,gameCommandsExecuted:false,screenshots:['intent-search.png','desktop-100.png','desktop-125.png','desktop-150.png'],userData};
    fs.writeFileSync(path.join(artifacts,process.env.ISAAC_TEST_EXE?'packaged-report.json':'desktop-report.json'),JSON.stringify(report,null,2));
    console.log(`${checks.length} checks passed`);
  }finally{if(app)await app.close().catch(()=>{});}
})().catch(err=>{console.error(err);process.exitCode=1;});
