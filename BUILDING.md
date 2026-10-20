# 源码构建与验证

玩家直接下载 Release 中的 Mod ZIP，无需 Node.js、Python 或开发工具。

## 开发环境

- Node.js 22 或更新版本，npm。
- Python 3.12（本项目已使用的版本）；开发依赖在 `requirements-dev.txt`。
- 以下命令按 Git Bash 编写，在仓库根目录执行。

```bash
npm ci
python -m pip install -r requirements-dev.txt
npm run mod:test
python scripts/package_mod.py
```

源码已经包含生成后的 Lua 目录和位图字体，上述测试与打包无需游戏文件，也不会启动游戏或提交游戏命令。产物位于 `release/以撒游戏内指令面板-0.1.0.zip`。打包脚本还会解压该 ZIP 再次运行离线验证。

修改目录或界面文字后，使用完整构建：

```bash
npm run mod:package
```

完整构建会从已随源码提供的数据生成 Lua 目录，首次字体构建会下载 Noto Sans SC；之后使用 `.cache/mod-font/` 缓存。Lua 5.3／5.4 测试覆盖目录、搜索、参数、执行分发、保存、输入、普通／增强模式和 HUD 恢复。测试中游戏 API 为模拟实现，不能替代真实游戏验收。

## 桌面工具

```bash
npm test
npm run build
npm start
```

Windows 便携包使用 `npm run package`。运行目录重建脚本 `scripts/build_catalog.py` 需要额外提供对应版本的本机游戏资料；正常构建使用已附目录，无需重新提取。

## 发布范围

普通模式与增强模式使用同一个 Mod ZIP；不随包分发 REPENTOGON，不安装桥接程序。`node_modules/`、`.cache/`、`test-artifacts/`、`release/`、环境变量文件和本机备份已排除在 Git 源码外。Release 只上传经过验证的产物及其 SHA-256 清单；桌面便携包另行发布。
