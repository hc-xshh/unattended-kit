# 无人值守 6 件事（unattended-kit）

一台机器要能 7×24 自己干活，只需要把这六件事装上。这份 kit 是**我自己那台机器上正在跑的配置的泛化版**，
每一条都对应一个真实踩过的故障或真实需求（不是教程里抄的）。

| # | 文件 | 解决什么 |
|---|---|---|
| 1 | `01-autostart.service` | 机器重启后，服务自己回来（而不是"记着手动开"） |
| 2 | `02-crontab.example` | 什么时候跑什么，以及**为什么有一条必须放在被调度的进程之外** |
| 3 | `03-logging.md` | 日志写哪里；写错地方，任务会安静地失败 |
| 4 | `04-watchdog.sh` | 挂了谁来发现——必须是**外部**的一只眼睛 |
| 5 | `05-notify.sh` | 出问题主动喊你，正常时闭嘴 |
| 6 | `06-backup.sh` | 数据比程序值钱：每天一份，只留最近 N 份 |

**安装顺序**：先读 03（日志规矩）→ 1 → 2 → 4 → 5 → 6。

**最短路径**（三分钟能跑起来）：

```bash
mkdir -p ~/logs ~/bin
cp 04-watchdog.sh 05-notify.sh 06-backup.sh ~/bin/ && chmod +x ~/bin/*.sh
# 1) 先让通知通：把 TG_TOKEN / TG_CHAT 放进环境（别写进脚本）
export TG_TOKEN=xxx TG_CHAT=xxx && ~/bin/05-notify.sh "测试通知"
# 2) 看门狗每 5 分钟一次（crontab -e 加这一行）
#    */5 * * * * /home/你的用户名/bin/04-watchdog.sh >> ~/logs/watchdog.log 2>&1
# 3) 备份每天一次，只留 7 份
#    0 4 * * * /home/你的用户名/bin/06-backup.sh >> ~/logs/backup.log 2>&1
```

判断它有没有在干活，只有一句话：**别看有没有报错，看还有没有心跳**——
`tail ~/logs/watchdog.log` 里每 5 分钟应该多一行带时间的记录。
