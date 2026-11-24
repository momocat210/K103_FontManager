#!/system/bin/sh
# 面具 → 模块 → 「操作」：按模块当前内容重新挂载（安全操作，不重启界面）
ctl=/data/adb/modules/k103_font_manager/tools/font_ctl.sh
[ -f "$ctl" ] && sh "$ctl" rebind
exit 0
