# K103 猫猫字体管理（v1.0）

> 适用于 **Boyue Likebook K103**（Android 8.1 / arm64 / Magisk root）的 systemless 字体替换方案。
> 把 `/sdcard/Fonts` 里的自定义字体一键替换为系统字体，随时还原，不写入 `/system` 分区。

## 功能

- 支持 `ttf` / `otf` / `ttc` 字体，真实字体预览后再激活
- 两档替换：**仅中文**（zh-Hans / zh-Hant）或 **中文 + 西文数字**（Roboto 全家）
- 运行时 `bind mount` 即时生效，重启后由 Magisk magic mount 接管，状态一致
- 原版 `fonts.xml` 自动备份，还原完整可靠
- 提供控制端 APP 与命令行脚本两种操作方式

## 目录结构

| 路径 | 说明 |
| --- | --- |
| `1-模块安装包/K103-FontManager-v1.0.zip` | Magisk 模块，面具 → 模块 → 从本地安装 → 重启 |
| `1-模块安装包/猫猫字体管理forK103-v1.0.apk` | 圆角控制端 APP，首次打开在 Magisk 里授权 |
| `2-源码/module/` | 模块源文件，`tools/font_ctl.sh` 为全部控制逻辑 |
| `2-源码/app/` | 控制端 APP 源码（apktool 解包结构 + `assets/index.html` 界面） |
| `2-源码/apps/` | 已编译的 APP |
| `2-源码/build_zip.py` / `package_all.py` | 重新打包脚本 |
| `移植说明.md` | 替换机制、实机验证记录、命令速查与常见问题 |
| `README-先看我.txt` | 原始说明文件 |

## 使用方法

1. 把想用的字体（`ttf` / `otf` / `ttc`）放进 `/sdcard/Fonts/`
2. 刷入 Magisk 模块并安装控制端 APP
3. 打开「猫猫字体管理」→ 选择一个字体 → 查看预览 → 点「激活」
4. 点「立即生效」重启界面（约 20~40 秒），系统字体即完成替换

命令行同样可用：

```sh
su -c "sh /data/adb/modules/k103_font_manager/tools/font_ctl.sh list"
su -c "sh /data/adb/modules/k103_font_manager/tools/font_ctl.sh apply 10"
su -c "sh /data/adb/modules/k103_font_manager/tools/font_ctl.sh flush"
```

## 实现机制

K103 的中文经 `fonts.xml` 的 zh-Hans fallback 指向 `NotoSansCJK-Regular.ttc`（TTC 集合 index=2）。模块通过「去掉 index 属性 + 字体内容原地覆盖 + bind mount」的方式，让任意单 TTF 都能安全替换系统字体：

- 不修改 `/system` 分区，属于 systemless 方案
- 使用 `cat` 原地覆盖文件，避免 `mv` 换 inode 造成挂载层死结
- 脚本自动检测 mount namespace，必要时 `su -M` 切到 global namespace 执行
- `flush` 重启 framework 让所有进程重新加载字体

更多细节与实机验证记录见 [移植说明.md](./移植说明.md)。

## 兼容性

设备要求：Boyue Likebook K103 / Android 8.1 / arm64 / Magisk root。

理论上也适用于其他 `fonts.xml` 结构相同的 Android 8.x 墨水屏设备；若系统字体文件名不同，修改 `font_ctl.sh` 顶部的 TTC 变量与 `sed` 规则即可。

> 注意：apktool / aapt 无法处理中文路径，回编译 APP 请在纯 ASCII 路径下进行。

## 版本

v1.0 — 首个完整发布版（2026-11-21）
