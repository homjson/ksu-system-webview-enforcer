# System WebView Enforcer

根据《优化 App 流畅度教程》的思路，将选中 App 的私有 WebView 内核目录删除后替换成 `root:root`、权限 `000` 的空目录，迫使 App 回退到 Android System WebView。

支持 **KernelSU** 和 **Magisk** 两种框架。

## 安装

1. 从 [Releases](https://github.com/homjson/ksu-system-webview-enforcer/releases) 页面下载最新版本的 zip 包。
2. 重启手机。
3. 打开管理器 App（KernelSU Manager 或 Magisk App），进入模块页面，点击本模块的 **Action 按钮**执行一次。
4. Action 页面会显示最后 40 行日志；完整日志位于模块目录的 `logs/manual.log`。

## 更新
更新模块不会覆盖apps.conf里的配置，如需要更新模块的apps.conf，删除本地的apps.conf。

## 配置

`config/apps.conf` 使用分段格式。每个 App 从 `app` 开始，到 `end` 结束：

```text
app Meituan
enabled 1
package com.sankuai.meituan
dir app_webview_mt_webview
dir files/cips/common/mtplatform/assets/mtwebview
end
```

含义：

- `app`：日志中显示的名称，可以写中文或英文。
- `enabled 1`：锁定该 App 的私有 WebView 目录。
- `enabled 0`：保留规则但跳过该 App。
- `enabled 2`：解锁该 App 的目录（恢复为 App 自身权限），用于单独解锁某个 App 而不影响其他。
- `package`：App 包名，对应 `/data/data/<package>`。
- `dir`：要锁死的目录，一行一个，只写相对 `/data/data/<package>` 的路径。

新增 App 时复制一整段；新增目录时只加一行 `dir ...`；禁用某个 App 时把 `enabled 1` 改成 `enabled 0`。

**升级模块时，`apps.conf` 和 `settings.conf` 会被自动保留，不会覆盖你修改过的配置。**

脚本仍兼容旧版 `enabled|package|label|dir,dir` 格式，但不再推荐手写旧格式。

默认启用：

- 美团
- 京东
- 淘宝
- 闲鱼
- 铁路 12306
- QQ
- 支付宝
- 天猫

默认禁用：

- 百度地图
- QQ 音乐
- 钉钉
- 微信
- 抖音

这些默认禁用项通常涉及更复杂的安全、风控或业务逻辑，建议确认能接受崩溃、功能异常、账号风控提示等风险后再启用。

脚本会先检查目标目录是否已经是 `root:root` 且权限为 `000`。已经锁好的目录不会重复删除；只有发生新的重锁操作时，才会停止对应 App 并清理缓存。

## 开机自动补锁

默认不开启开机自动执行。需要时在 `config/settings.conf` 中设置 `AUTO_RUN_ON_BOOT=1`：

```sh
AUTO_RUN_ON_BOOT=1
```

- **KernelSU**：使用 `boot-completed.sh`
- **Magisk**：使用 `service.sh`（late_start service 阶段）

两者互不冲突，zip 包同时包含两个脚本，在各自框架下自动生效。

## 回滚

卸载模块时，`uninstall.sh` 会尝试把配置中列出的占位目录恢复为 `0771`，并将所有者改回 App 数据目录的所有者。

注意：模块不会、也无法恢复已经删除的私有 WebView 原始文件。解除占位后，App 通常会在下次启动或更新时自行重建/下载。

## 风险

- 该模块会修改 `/data/data/<package>`，不是纯 systemless 的 `/system` overlay。
- App 更新后目录名可能变化，需要维护 `config/apps.conf`。
- 个别 App 可能因检测到数据目录异常而崩溃、降级或触发安全提示。
- 建议先备份重要 App 数据，再逐个启用规则测试。

## 免责声明

本模块仅供学习和研究用途。安装即视为您已阅读、理解并同意自行承担使用本模块所带来的一切风险。因使用或滥用本模块导致的任何数据丢失、系统异常、账号封禁、功能异常或其他直接或间接损失，模块作者概不负责。
