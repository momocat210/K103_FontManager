#!/system/bin/sh
# ================================================================
# K103 猫猫字体管理 v1.0 —— font_ctl.sh（root 控制脚本）
#
# 机制（实机确认的 K103 Android 8.1 字体链）：
#   系统字体配置 /system/etc/fonts.xml：
#     - 中文 UI 全部经 zh-Hans fallback → NotoSansCJK-Regular.ttc (index=2)
#       （zh-Hant 为 index=3；单 TTF 没有 TTC face，必须去掉 index）
#     - 西文/数字经 sans-serif 家族 → 12 个 Roboto-*.ttf
#   替换策略（systemless，不写 /system 分区）：
#     a. 字体内容放到模块 system/fonts/NotoSansCJK-Regular.ttc
#        （FreeType 认文件头不认扩展名，单 TTF 内容放 .ttc 路径没问题）
#     b. fonts.xml 从 backup 原版生成：去 index / Roboto 条目改指同一字体
#     c. 运行时逐文件 bind mount 到 /system 对应路径立即生效；
#        重启设备后由 Magisk magic mount 无缝接管同一内容。
#     d. 生效需重启 framework（flush：stop+start，界面重启 20~40 秒）。
#
# 用法：
#   font_ctl.sh list               列出字体库（"编号 文件名"）
#   font_ctl.sh status             状态（key=value，供 APP 解析）
#   font_ctl.sh apply <编号> [latin]  激活字体（latin=同时替换西文数字）
#   font_ctl.sh reset              还原系统默认（含卸载所有 bind 层）
#   font_ctl.sh flush              重启界面使字体生效
#   font_ctl.sh preview <编号>     复制字体到预览缓存（供 APP 渲染）
#   font_ctl.sh mountinfo          诊断挂载状态
#   font_ctl.sh rebind             按模块当前内容重新挂载
# ================================================================

MODDIR=$(cd "$(dirname "$0")/.." && pwd)
FONT_DIR=/sdcard/Fonts
PREVIEW_DIR=/sdcard/.fontpreview
CONF=$MODDIR/settings.conf
ORIG_XML=$MODDIR/backup/fonts.xml.orig
MOD_FONTS=$MODDIR/system/fonts
MOD_ETC=$MODDIR/system/etc
TTC=NotoSansCJK-Regular.ttc

# 挂载目标（fonts.xml + 字体文件，latin 模式也只挂这 2 项：
# fonts.xml 的 Roboto 条目直接改指 NotoSansCJK-Regular.ttc）
XML_SYS=/system/etc/fonts.xml
TTC_SYS=/system/fonts/$TTC

die() { echo "ERROR: $*"; exit 1; }

# ---------- 关键：确保在 global mount namespace 执行 ----------
# Magisk su 默认在调用方（requester）的 mount namespace 里跑命令。
# APP 进程 fork 自 zygote，拥有独立 namespace：在那里 bind mount，
# system_server（global namespace）完全看不到，字体替换永远不会生效。
# 自检：与本机 init 的 namespace 不同，则用 su -M（--mount-master）
# 切到 global namespace 重新执行本脚本（Magisk 31 无 --mount-namespace）。
# 参数全为 ASCII 单词/数字（list/status/apply/编号/latin…），可安全拼接。
ensure_global_ns() {
  typeset selfns initns
  selfns=$(readlink /proc/self/ns/mnt 2>/dev/null)
  initns=$(readlink /proc/1/ns/mnt 2>/dev/null)
  if [ -n "$selfns" ] && [ -n "$initns" ] && [ "$selfns" != "$initns" ]; then
    exec su -M -c "sh $0 $*"
  fi
}
ensure_global_ns "$@"

# ---------- 基础 ----------
get_conf() { sed -n "s|^$1=||p" "$CONF" 2>/dev/null | head -1; }
set_conf() {
  typeset v2 tmp
  v2=$(printf '%s' "$2" | tr -d '\n')
  tmp="$CONF.tmp"
  # grep -v 重写：绕开 sed 分隔符冲突（字体名可能含 | 等任意字符）
  grep -v "^$1=" "$CONF" 2>/dev/null > "$tmp"
  echo "$1=$v2" >> "$tmp"
  mv -f "$tmp" "$CONF"
}

list_files() { ls -1 "$FONT_DIR" 2>/dev/null | grep -iE '\.(ttf|otf|ttc)$' | sort; }

mounted_layers() { grep -c " $1 " /proc/mounts 2>/dev/null; }

# 循环 umount：把某目标路径上叠加的所有 bind 层全部卸掉
# （含运行时 bind 层与开机 magic mount 层），露出真正的原版文件
unbind_one() {
  typeset n
  n=0
  while grep -q " $1 " /proc/mounts 2>/dev/null; do
    umount "$1" 2>/dev/null || break
    n=$((n + 1))
    [ $n -ge 6 ] && break
  done
}

bind_one() { mount -o bind "$1" "$2" 2>/dev/null; }

# ---------- fonts.xml 生成 ----------
# $1=latin(0/1)  $2=输出路径
# 注意：目标已存在时用 cat 原地覆盖（保 inode，bind 层不会死结）
gen_fonts_xml() {
  typeset out
  [ -f "$ORIG_XML" ] || die "缺少原版 fonts.xml 备份（backup/fonts.xml.orig）"
  out="$2.tmp"
  sed -e 's|<font weight="400" style="normal" index="2">NotoSansCJK-Regular.ttc</font>|<font weight="400" style="normal">NotoSansCJK-Regular.ttc</font>|' \
      -e 's|<font weight="400" style="normal" index="3">NotoSansCJK-Regular.ttc</font>|<font weight="400" style="normal">NotoSansCJK-Regular.ttc</font>|' \
      "$ORIG_XML" > "$out" || die "fonts.xml 生成失败"
  if [ "$1" = "1" ]; then
    for r in Thin ThinItalic Light LightItalic Regular Italic Medium MediumItalic Black BlackItalic Bold BoldItalic; do
      sed -i "s|>Roboto-$r.ttf<|>NotoSansCJK-Regular.ttc<|" "$out"
    done
  fi
  # 验证：中文条目 index 必须已去除；latin 模式不能残留 Roboto 条目
  grep -q 'index="[23]">NotoSansCJK' "$out" && { rm -f "$out"; die "fonts.xml 校验失败（index 未去除）"; }
  if [ "$1" = "1" ]; then
    grep -q '>Roboto-[A-Za-z]*\.ttf<' "$out" && { rm -f "$out"; die "fonts.xml 校验失败（Roboto 条目残留）"; }
  fi
  if [ -f "$2" ]; then
    cat "$out" > "$2" && rm -f "$out"
  else
    mv -f "$out" "$2"
  fi
}

# ---------- 挂载管理 ----------
do_unbind_all() {
  unbind_one "$TTC_SYS"
  unbind_one "$XML_SYS"
}

do_bind_all() {
  typeset ok
  ok=0
  if [ -f "$MOD_FONTS/$TTC" ]; then
    bind_one "$MOD_FONTS/$TTC" "$TTC_SYS" && ok=$((ok + 1))
  fi
  if [ -f "$MOD_ETC/fonts.xml" ]; then
    bind_one "$MOD_ETC/fonts.xml" "$XML_SYS" && ok=$((ok + 1))
  fi
  chmod 644 "$MOD_FONTS/$TTC" "$MOD_ETC/fonts.xml" 2>/dev/null
  echo "bound $ok/2"
}

# 若存在待合并升级包（modules_update），下次重启 Magisk 会用它覆盖正式目录，
# 把升级安装后用户新做的激活/切换回滚成安装时的快照。脚本已双目录同步，
# 直接取消待合并升级，彻底消除回滚窗口。
clear_pending() {
  typeset upd
  upd=/data/adb/modules_update/k103_font_manager
  [ -d "$upd" ] && rm -rf "$upd"
}

# ---------- 命令 ----------
cmd_list() {
  i=0
  list_files | while IFS= read -r f; do
    i=$((i + 1))
    echo "$i|$f"
  done
}

cmd_status() {
  echo "active=$(get_conf ACTIVE_FONT)"
  echo "latin=$(get_conf LATIN)"
  echo "fonts_total=$(list_files | wc -l)"
  echo "module_xml=$([ -f "$MOD_ETC/fonts.xml" ] && echo 1 || echo 0)"
  echo "module_ttc=$([ -f "$MOD_FONTS/$TTC" ] && echo 1 || echo 0)"
  echo "orig_xml=$([ -f "$ORIG_XML" ] && echo 1 || echo 0)"
  echo "layers_ttc=$(mounted_layers "$TTC_SYS")"
  echo "layers_xml=$(mounted_layers "$XML_SYS")"
}

# 字体魔数校验：TTF=00 01 00 00 / OTF="OTTO" / TTC="ttcf" / "true"
check_font() {
  magic=$(od -An -tx1 -N4 "$1" 2>/dev/null | tr -d ' \n')
  case "$magic" in
    00010000|4f54544f|74746366|74727565) return 0 ;;
    *) return 1 ;;
  esac
}

cmd_apply() {
  typeset n f latin src sz
  [ -n "$1" ] || die "用法: apply <编号> [latin]"
  n="$1"
  latin=0
  [ "$2" = "latin" ] && latin=1
  f=$(list_files | sed -n "${n}p")
  [ -n "$f" ] || die "字体库中没有编号 $n"
  src="$FONT_DIR/$f"
  [ -f "$src" ] || die "文件不存在: $src"
  check_font "$src" || die "$f 不是有效的 ttf/otf/ttc 字体"
  sz=$(wc -c < "$src" 2>/dev/null)
  [ "$sz" -gt 10000 ] || die "$f 太小（${sz}B），疑似损坏"

  mkdir -p "$MOD_FONTS" "$MOD_ETC"
  # chmod 644 必须在挂载前：system_server 是 uid=1000，640 它读不到、字体加载失败
  cp -f "$src" "$MOD_FONTS/.stage.tmp" || die "复制字体失败"
  chmod 644 "$MOD_FONTS/.stage.tmp"
  gen_fonts_xml "$latin" "$MOD_ETC/fonts.xml" || { rm -f "$MOD_FONTS/.stage.tmp"; exit 1; }
  chmod 644 "$MOD_ETC/fonts.xml"
  sync
  # 关键：不用 mv！mv 会 unlink 旧 inode，使已建立的 bind 层指向
  # unlinked inode，之后 umount 与新 mount 双双 ENOENT，运行时死结。
  # cat 原地覆盖：inode 不变，已挂载的层自动读到新内容。
  if [ -f "$MOD_FONTS/$TTC" ]; then
    cat "$MOD_FONTS/.stage.tmp" > "$MOD_FONTS/$TTC" || { rm -f "$MOD_FONTS/.stage.tmp"; die "写入字体失败"; }
    rm -f "$MOD_FONTS/.stage.tmp"
  else
    mv -f "$MOD_FONTS/.stage.tmp" "$MOD_FONTS/$TTC"
  fi

  do_unbind_all
  do_bind_all
  set_conf ACTIVE_FONT "$n|$f"
  set_conf LATIN "$latin"
  clear_pending
  echo "OK: activated [$n] $f (latin=$latin)"
  echo "next: 执行 flush 重启界面生效（约 20~40 秒）"
}

cmd_reset() {
  do_unbind_all
  rm -f "$MOD_FONTS/$TTC" "$MOD_ETC/fonts.xml"
  set_conf ACTIVE_FONT "none"
  set_conf LATIN 0
  clear_pending
  echo "OK: 已还原系统默认（flush 后完全生效）"
}

cmd_flush() {
  echo "flush: 重启界面（20~40 秒，请勿操作设备）"
  sync
  stop
  sleep 2
  start
  echo "flush: done"
}

cmd_preview() {
  typeset f tgt
  [ -n "$1" ] || die "用法: preview <编号>"
  f=$(list_files | sed -n "$1p")
  [ -n "$f" ] || die "字体库中没有编号 $1"
  check_font "$FONT_DIR/$f" || die "$f 不是有效字体"
  # 优先 APP 私有 cache：WebView 免存储权限即可读（sdcard 需要 APP 动态授权，8.1 上易失败）
  if [ -d /data/data/com.momocat.k103.font/cache ]; then
    tgt=/data/data/com.momocat.k103.font/cache/current.ttf
    cp -f "$FONT_DIR/$f" "$tgt.tmp" && mv -f "$tgt.tmp" "$tgt"
    chmod 666 "$tgt" 2>/dev/null
    echo "OK: $tgt"
  else
    mkdir -p "$PREVIEW_DIR"
    cp -f "$FONT_DIR/$f" "$PREVIEW_DIR/current.ttf" || die "复制预览字体失败"
    chmod 666 "$PREVIEW_DIR/current.ttf" 2>/dev/null
    echo "OK: $PREVIEW_DIR/current.ttf"
  fi
}

cmd_mountinfo() {
  echo "--- /proc/mounts 相关条目 ---"
  grep -E "fonts|Font" /proc/mounts
  echo "--- 模块文件 ---"
  ls -la "$MOD_FONTS" "$MOD_ETC" 2>/dev/null
  echo "--- 系统字体文件校验 ---"
  echo "orig  xml md5: $(md5sum "$ORIG_XML" 2>/dev/null | cut -d' ' -f1)"
  echo "sys   xml md5: $(md5sum "$XML_SYS" 2>/dev/null | cut -d' ' -f1)"
  echo "sys   ttc md5: $(md5sum "$TTC_SYS" 2>/dev/null | cut -d' ' -f1)"
  echo "sys   ttc head: $(od -An -tx1 -N4 "$TTC_SYS" 2>/dev/null)"
}

cmd_rebind() {
  if [ ! -f "$MOD_FONTS/$TTC" ] || [ ! -f "$MOD_ETC/fonts.xml" ]; then
    echo "未激活任何字体，无需挂载"
    exit 0
  fi
  do_unbind_all
  do_bind_all
}

case "${1:-}" in
  list)       cmd_list ;;
  status)      cmd_status ;;
  apply)       shift; cmd_apply "$@" ;;
  reset)       cmd_reset ;;
  flush)       cmd_flush ;;
  preview)     shift; cmd_preview "$@" ;;
  mountinfo)   cmd_mountinfo ;;
  rebind)      cmd_rebind ;;
  *) echo "K103 猫猫字体管理 font_ctl.sh v1.0"
     echo "用法: $0 list|status|apply <编号> [latin]|reset|flush|preview <编号>|mountinfo|rebind" ;;
esac
