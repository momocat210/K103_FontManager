================================================================
 Boyue Likebook K103 猫猫字体管理 —— 源码 + 安装包（v1.0）
================================================================

【1-模块安装包】直接用于设备安装
  K103-FontManager-v1.0.zip
      Magisk 模块（标准结构）：面具 → 模块 → 从本地安装 → 重启。
      systemless 替换系统字体：把 /sdcard/Fonts 里的 ttf/otf/ttc
      一键替换系统中文（zh-Hans/zh-Hant），可选同时替换西文数字
      （Roboto 全家）。不写 /system 分区，卸载即还原。
  猫猫字体管理forK103-v1.0.apk
      圆角控制端 APP：文件管理器点击安装，首次打开在 Magisk 里授权。
      字体列表 / 真实字体预览 / 一键激活 / 西文开关 / 立即生效 / 还原。

【怎么用】
  1. 把想用的字体（ttf/otf/ttc）放进 /sdcard/Fonts/
  2. 刷模块 + 装 APP，打开「猫猫字体管理」
  3. 点一个字体 → 看预览 → 点「激活」
  4. 点「立即生效」重启界面（20~40 秒），系统字体即替换
  5. 命令行同样可用：
       su -c "sh /data/adb/modules/k103_font_manager/tools/font_ctl.sh list"
       su -c "sh /data/adb/modules/k103_font_manager/tools/font_ctl.sh apply 10"
       su -c "sh /data/adb/modules/k103_font_manager/tools/font_ctl.sh flush"

【机制（为什么是安全的）】
  - K103 系统中文经 fonts.xml 的 zh-Hans fallback → NotoSansCJK-Regular.ttc
    （TTC 集合 index=2）；本模块用「去掉 index + 字体内容 bind mount」
    的方式让任意单 TTF 都能替换，不改 /system 分区。
  - 运行时逐文件 bind mount 即时生效；重启设备后由 Magisk magic mount
    无缝接管同一内容，无需再次操作。
  - fonts.xml 从安装时备份的原版生成，原版随时完整还原。

【2-源码】可修改后自行重新构建
  build_zip.py   重新打包 Magisk 模块 zip
  module/        模块源文件（tools/font_ctl.sh 为全部控制逻辑）
  apps/          控制端 APP
  app/           控制端 APP 源码（apktool 解包结构 + assets/index.html 界面）
  注意：apktool/aapt 无法处理中文路径，请在纯 ASCII 路径下回编译 APP。

【文档】
  移植说明.md   机制说明、实机验证记录、命令速查、常见问题

设备要求：Boyue Likebook K103 / Android 8.1 / arm64 / Magisk root。
兼容提示：也适用于其他 fonts.xml 结构相同的 Android 8.x 墨水屏设备，
  若系统字体文件名不同，改 font_ctl.sh 顶部的 TTC 变量与 sed 规则即可。
