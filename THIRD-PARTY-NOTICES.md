# 来源、许可与参考项目

本软件是独立离线速查工具，与 Nicalis、Edmund McMillen、Valve 或下列项目无隶属关系。游戏名称及物品名称归其权利人所有。

## 实际使用的数据

- [roiiiu/isaac-cheat-sheet](https://github.com/roiiiu/isaac-cheat-sheet)：MIT License，固定提交 `7d59952d4e5718ac80ebf9a60b4f7c5611557952`。使用其 `data.json`、`data_trinkets.json`、`data_card.json` 中的物品名称、英文名、短描述和品质信息，按本机枚举过滤并规范化。原 MIT 版权与许可全文附在 `licenses/isaac-cheat-sheet-MIT.txt`。不使用其游戏图片或精灵表。
- 本机游戏 `resources/scripts/enums.lua`：仅读取物品、角色、挑战及实体的 ID 与符号，生成静态目录及枚举核对快照；不再分发游戏可执行文件、图片、资源包或原始脚本。基准为 Repentance v1.7.9b.J835，源文件 SHA-256 随目录保存。
- [External Item Descriptions](https://github.com/wofsauge/External-Item-Descriptions)：对少量缺少中文名的物品及胶囊，使用本机已安装 `descriptions/names/zh_cn.lua` 的名称字符串核对；不执行或分发原始 Lua 文件，不复制整段效果说明，不把其 Repentance+ 专有内容合并进原版目录。
- [wofsauge/IsaacDocs](https://github.com/wofsauge/IsaacDocs/blob/main/docs/tutorials/DebugConsole.md) 及本机 LuaDocs：核对控制台语法、原生命令和玩家资源方法。中文用途说明与界面文字由本项目编写，未全文复制文档。

物品短描述属于速查提示，并非完整机制手册。目录只声明对应的本机版本；枚举中存在内部形态和保留内容。实体未公开变体不以“完整敌人变体库”宣传。

## 调研参考（未复制实现代码）

- [boyl/isaac-chinese-console](https://github.com/boyl/isaac-chinese-console)：分类、离线中文检索、类型化 ID 的设计经验。
- [NOTF-API/IsaacBoxClient](https://github.com/NOTF-API/IsaacBoxClient)：外置 Electron 桌面工具的结构经验。
- [enthusiasmgame2001/isaac-szx-chinese-console](https://github.com/enthusiasmgame2001/isaac-szx-chinese-console)：中文别名及搜索方式参考。
- [Basement-Renovator/basement-renovator](https://github.com/Basement-Renovator/basement-renovator)：仅调研实体目录组织方式，其 LICENSE 为保留所有权利；未复制其 XML、代码或图片。

## 软件依赖

Electron 及其 Chromium、Node.js 组件许可随程序附带 `LICENSE.electron.txt`、`LICENSES.chromium.html`。拼音检索使用 pinyin-pro（MIT），许可随包附在 `licenses/pinyin-pro-LICENSE`。TypeScript、Vite、electron-builder、Playwright、tsx 为开发和验证依赖，版本锁定在 `package-lock.json`，依赖自身许可保留在源码依赖包中。
