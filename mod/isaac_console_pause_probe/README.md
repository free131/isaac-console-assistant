# 原版控制台暂停探针

独立测试 Mod，目录 `isaac_console_pause_probe`。保留指令面板原有功能，测试时请让 F8 面板关闭。本探针不添加物品、不执行控制台命令、不冻结实体、不修改配置或原游戏存档；只写自身 Mod 诊断数据和游戏日志。

## 只需要进行这一次实机测试

1. 重启游戏，确认 Mods 菜单启用本探针，进入可以丢弃的单人试验对局。上方应显示英文 `ICP Pause Probe`。
2. 按 **F6** 一次，松开并等待两秒：观察原版控制台是否自动打开。如果自动打开，先按一次 F7，看探针标记是否更新；不要输入游戏命令。
3. 如果没有自动打开，就手动按 **` / ~** 打开原版控制台。在控制台执行下面第一行，等待约 5 秒，再执行第二行：

```lua
lua ICPPauseProbe.Mark("console_A")
lua ICPPauseProbe.Mark("console_B")
```

4. 观察控制台下是否仍能看到探针的两行计数，以及它们是否变化。在控制台开启时按一次 **F7**，随后按空 Enter 关闭控制台。返回游戏后再按一次 F7，然后退出到主菜单。

之后告诉助手“测完了”，助手读取 `Documents/My Games/Binding of Isaac Repentance/log.txt` 中的 `[ICP-PauseProbe]` 记录。日志包括回调次数、时间和暂停状态，不记录输入的普通文字。

## 如何判断

- `request_expired_no_hook`：F6 的请求期内没有引擎询问 ACTION_CONSOLE；不能把模拟回调当作已打开控制台。
- `hook_value_emitted` / `request_finished_result_unverified`：曾向真实钩子返回值；是否真的打开仍需画面确认。
- `console_A` 到 `console_B` 等待约 5 秒时，`delta.ms` 增长但 `delta.updates`、`delta.game_frame`、`delta.timer` 为 0：世界更新停止。
- 同时 `delta.renders` 为 0：Lua 的 MC_POST_RENDER 也停止，现有纯 Lua 面板无法在原版控制台之上保持工作，应转向引擎扩展路线。
- `delta.renders` 持续增长且暂停期间的 F7 标记出现：绘制及键盘读取仍有入口，但还需要进一步验证输入隔离，不能仅凭此宣称完整方案成功。

请求最多持续一秒，每种 InputHook 只返回一次，并限制在同一游戏帧；不会一直强制打开控制台。不依赖任何外部程序。关闭控制台按空 Enter；若输入框有内容，先清空。退出游戏后删除 `mods/isaac_console_pause_probe` 即可移除探针。

基准为 Repentance 1.7.9b。原版文档只明确 ACTION_CONSOLE 用于 hooking，并没有保证它能主动打开控制台：[ButtonAction](https://wofsauge.github.io/IsaacDocs/rep/enums/ButtonAction.html)。**离线检查只能验证探针不会重复发射及统计逻辑，不能替代以上实机结果。**
