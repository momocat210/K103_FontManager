#!/system/bin/sh
# Magisk 卸载时执行：运行时立即还原（重启设备后 magic mount 一并消失）
MODDIR=${0%/*}
for t in /system/fonts/NotoSansCJK-Regular.ttc /system/etc/fonts.xml; do
  n=0
  while grep -q " $t " /proc/mounts 2>/dev/null; do
    umount "$t" 2>/dev/null || break
    n=$((n + 1)); [ $n -ge 6 ] && break
  done
done
rm -rf /sdcard/.fontpreview 2>/dev/null
echo "字体已还原系统默认（如需立即生效请重启界面或重启设备）"
exit 0
