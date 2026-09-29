#!/usr/bin/env bash
# 第 4 件事：看门狗 —— 挂了谁来发现
#
# 核心一句话：看门狗必须在「被监控的东西之外」。
# 程序自己已经死了，它没法告诉你说它死了；所以这只眼睛得由系统来当。
# 装法：放进系统 crontab（每 5 分钟一次）
#   */5 * * * * /home/你的用户名/bin/04-watchdog.sh >> /home/你的用户名/logs/watchdog.log 2>&1
#
# 可调（环境变量，写在脚本外更干净）：
#   WATCH_PROC     要盯的进程特征，默认 myjob.py
#   WATCH_DISK_MAX 磁盘告警阈值(%)，默认 90
#   WATCH_MEM_MIN  可用内存下限(MB)，默认 300
set -uo pipefail

PROC_PATTERN="${WATCH_PROC:-myjob.py}"
DISK_MAX="${WATCH_DISK_MAX:-90}"
MEM_MIN_MB="${WATCH_MEM_MIN:-300}"
NOTIFY="$(cd "$(dirname "$0")" && pwd)/05-notify.sh"

TS=$(date '+%F %T')
ISSUES=""
MODS=""

# 1) 进程还在不在
#    坑（实测踩过）：pgrep -f 会匹配到「自己」——因为看门狗自己的命令行里也带着这个特征串，
#    于是进程明明死了，它却报 OK。所以必须把自己和父进程排除掉。
MATCH=$(pgrep -f "$PROC_PATTERN" 2>/dev/null | grep -vx -e "$$" -e "$PPID" || true)
if [ -n "$MATCH" ]; then
  MODS="$MODS proc=OK"
else
  MODS="$MODS proc=DOWN"
  ISSUES="${ISSUES}进程不在了（$PROC_PATTERN）；"
fi

# 2) 磁盘使用率
DISK=$(df -h / | awk 'NR==2{print $5}' | tr -d '%')
if [ "${DISK:-0}" -lt "$DISK_MAX" ]; then
  MODS="$MODS disk=${DISK}%"
else
  MODS="$MODS disk=${DISK}%!"
  ISSUES="${ISSUES}磁盘用到 ${DISK}%（阈值 ${DISK_MAX}%）；"
fi

# 3) 可用内存（free 第二行；取第 7 列 available，单位 MB）
AVAIL=$(free -m | awk 'NR==2{print $7}')
if [ "${AVAIL:-0}" -ge "$MEM_MIN_MB" ]; then
  MODS="$MODS mem=$((AVAIL / 1024))G"
else
  MODS="$MODS mem=${AVAIL}M!"
  ISSUES="${ISSUES}可用内存只剩 ${AVAIL}M；"
fi

# 4) 心跳：被盯程序的日志里，最后一条带时间戳的记录离现在多久
#    （这条最重要 —— 进程在、但任务不再写日志，等于静默死亡）
LOG="${WATCH_LOG:-}"
if [ -n "$LOG" ] && [ -f "$LOG" ]; then
  LAST=$(grep -oE '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}' "$LOG" | tail -1)
  if [ -n "$LAST" ]; then
    GAP=$(( ( $(date +%s) - $(date -d "$LAST" +%s) ) / 60 ))
    if [ "$GAP" -le "${WATCH_HEARTBEAT_MAX:-15}" ]; then
      MODS="$MODS hb=${GAP}m"
    else
      MODS="$MODS hb=${GAP}m!"
      ISSUES="${ISSUES}心跳停了（最后一条 ${LAST}，已 ${GAP} 分钟）；"
    fi
  else
    MODS="$MODS hb=? "
    ISSUES="${ISSUES}日志里没有任何时间戳（$LOG）；"
  fi
fi

if [ -z "$ISSUES" ]; then
  echo "$TS STATUS=OK |$MODS"
  exit 0
fi

echo "$TS STATUS=ISSUE(1) |$MODS"
echo "$TS ALERT 🔴 $ISSUES"
[ -x "$NOTIFY" ] && "$NOTIFY" "看门狗告警（$(hostname)）：$ISSUES" || echo "$TS 通知脚本不可执行，跳过"
exit 1
