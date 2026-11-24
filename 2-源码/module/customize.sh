#!/sbin/sh
# Magisk 安装脚本（系统运行时执行）
ui_print " "
ui_print "- K103 猫猫字体管理 v1.0（systemless 字体替换）"
ui_print "- 适用: Boyue Likebook K103 / Android 8.1 / arm64 / 已 root+面具"

set_perm_recursive "$MODPATH" 0 0 0755 0644
for f in tools/font_ctl.sh action.sh uninstall.sh; do
  [ -f "$MODPATH/$f" ] && set_perm "$MODPATH/$f" 0 0 0755
done
[ -f "$MODPATH/settings.conf" ] && chmod 666 "$MODPATH/settings.conf" 2>/dev/null

# ---- 原版 fonts.xml 备份（替换模板的唯一来源，必须干净）----
ORIG=/system/etc/fonts.xml
if [ -f "$MODPATH/backup/fonts.xml.orig" ]; then
  ui_print "- 升级安装：保留已有原版 fonts.xml 备份"
else
  # 防御：若此刻 /system/etc/fonts.xml 正被本模块 bind（异常安装场景），
  # 先卸掉所有 bind 层再备份，保证备份的一定是出厂原版
  n=0
  while grep -q " $ORIG " /proc/mounts 2>/dev/null; do
    umount "$ORIG" 2>/dev/null || break
    n=$((n + 1)); [ $n -ge 6 ] && break
  done
  mkdir -p "$MODPATH/backup" "$MODPATH/system/fonts" "$MODPATH/system/etc"
  if cp "$ORIG" "$MODPATH/backup/fonts.xml.orig" 2>/dev/null; then
    ui_print "- 已备份原版 fonts.xml → backup/fonts.xml.orig"
  else
    ui_print "  !! 备份 fonts.xml 失败，模块将无法激活字体"
  fi
fi

# ---- 字体库目录 ----
FONTDIR=/sdcard/Fonts
mkdir -p "$FONTDIR" 2>/dev/null
cnt=$(ls -1 "$FONTDIR" 2>/dev/null | grep -iE '\.(ttf|otf|ttc)$' | wc -l)
ui_print "- 字体库: $FONTDIR （现有 $cnt 个字体）"
if [ "$cnt" -lt 1 ]; then
  cat > "$FONTDIR/PUT-FONTS-HERE.txt" <<'EOT'
请把要用于系统替换的字体文件（ttf / otf / ttc）放进本目录。
一个字体一个文件；激活后中文字体立即替换，可选同时替换西文数字。
建议使用 GBK/GB2312 覆盖完整的中文字体（含常用符号）。
EOT
  chmod 664 "$FONTDIR/PUT-FONTS-HERE.txt" 2>/dev/null
  chown -R media_rw:media_rw "$FONTDIR" 2>/dev/null
  ui_print "  !! 目录为空，请先放入至少 1 个字体文件"
fi

# ---- enabled 必须存在：Magisk 以此判定模块启用，缺失则 magic mount 不挂载 ----
[ -f "$MODPATH/enabled" ] || echo 1 > "$MODPATH/enabled"

# ---- 升级：保留激活状态与已激活字体（否则升级后回到默认字体）----
OLD=/data/adb/modules/k103_font_manager
if [ -d "$OLD" ]; then
  if [ -f "$OLD/settings.conf" ]; then
    cp -f "$OLD/settings.conf" "$MODPATH/settings.conf" 2>/dev/null
    ui_print "- 已保留激活状态 settings.conf"
  fi
  for f in system/fonts/NotoSansCJK-Regular.ttc system/etc/fonts.xml; do
    if [ -f "$OLD/$f" ]; then
      mkdir -p "$MODPATH/$(dirname "$f")"
      cp -f "$OLD/$f" "$MODPATH/$f" 2>/dev/null
      chmod 644 "$MODPATH/$f" 2>/dev/null
    fi
  done
  [ -f "$OLD/system/fonts/NotoSansCJK-Regular.ttc" ] && ui_print "- 已保留当前激活字体"
fi
chmod 666 "$MODPATH/settings.conf" 2>/dev/null

ui_print "- 本模块不改 /system 分区、不改 EPD/HWC/boot，卸载即还原"
ui_print "- 激活/切换请用「猫猫字体管理」APP，或："
ui_print "  su -c sh /data/adb/modules/k103_font_manager/tools/font_ctl.sh list"
ui_print " "
