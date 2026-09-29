#!/usr/bin/env bash
# 第 6 件事：备份 —— 每天一份，只留最近 N 份
#
# 为什么用数据库自带的 backup 接口，而不是 cp 文件：
#   cp 一个正在被写入的数据库，拿到的可能是「半个文件」；
#   sqlite 的 backup API 是联机热备 —— 备份期间服务不用停。
#
# 装法（每天 04:00）：0 4 * * * /home/你的用户名/bin/06-backup.sh >> /home/你的用户名/logs/backup.log 2>&1
#
# 可调：BACKUP_DB（要备份的文件）/ BACKUP_DIR（放哪）/ BACKUP_KEEP（留几份）
set -uo pipefail

DB="${BACKUP_DB:-$HOME/state.db}"
DIR="${BACKUP_DIR:-$HOME/backup}"
KEEP="${BACKUP_KEEP:-7}"
STAMP=$(date +%Y%m%d)
DEST="$DIR/$(basename "$DB").daily-$STAMP"

[ -f "$DB" ] || { echo "$(date '+%F %T') 找不到要备份的文件：$DB"; exit 1; }
mkdir -p "$DIR"

python3 - "$DB" "$DEST" <<'PY'
import sqlite3, sys
src, dst = sys.argv[1], sys.argv[2]
s = sqlite3.connect(f"file:{src}?mode=ro", uri=True)   # 只读打开正在使用的库
d = sqlite3.connect(dst)
with d:
    s.backup(d)                                        # 联机热备
d.close(); s.close()
print("备份完成 →", dst)
PY
[ $? -eq 0 ] || { echo "$(date '+%F %T') 备份失败"; exit 1; }

# 只留最近 N 份：不设上限的备份，最后一定把磁盘塞满
REMOVED=0
while IFS= read -r f; do
  rm -f "$f" && REMOVED=$((REMOVED + 1))
done < <(ls -1t "$DIR"/*.daily-* 2>/dev/null | tail -n +$((KEEP + 1)))

SIZE=$(du -h "$DEST" | awk '{print $1}')
COUNT=$(ls -1 "$DIR"/*.daily-* 2>/dev/null | wc -l)
echo "$(date '+%F %T') 已备份 $SIZE，现存 $COUNT 份（保留 $KEEP 份，本次清理 $REMOVED 份）"
