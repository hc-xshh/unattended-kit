#!/usr/bin/env bash
# 第 5 件事：告警 —— 出问题主动喊你，正常时闭嘴
#
# 设计要点：token / chat id 一律走环境变量或 0600 的凭据文件，
# 绝不写进脚本里（脚本会被复制、会被贴进聊天窗口）。
#
# 用法：
#   TG_TOKEN=xxx TG_CHAT=123 ~/bin/05-notify.sh "定时任务停了"
#   ~/bin/05-notify.sh --test          # 只验证通道通不通
#
# 其他通道（微信/钉钉/飞书/自建 webhook）：把下面 curl 的 URL 换掉即可，
# 只要保证「失败时返回非 0 退出码」，看门狗才能把发送失败记下来。
set -uo pipefail

MSG="${1:-任务出问题了}"
[ "$MSG" = "--test" ] && MSG="测试通知：通道正常（$(hostname) $(date '+%F %T')）"

if [ -z "${TG_TOKEN:-}" ] || [ -z "${TG_CHAT:-}" ]; then
  echo "缺少 TG_TOKEN / TG_CHAT（放环境变量，或 source 一个 0600 的凭据文件）" >&2
  exit 2
fi

CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 \
  -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
  -d "chat_id=${TG_CHAT}" --data-urlencode "text=${MSG}")

if [ "$CODE" = "200" ]; then
  echo "已发送：$MSG"
  exit 0
fi
echo "发送失败（HTTP $CODE）" >&2
exit 1
