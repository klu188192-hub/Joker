---
date: 2026-05-10
time: 08:50 (UTC+8)
type: incident-report
project: KK-运维 / copier 实盘
status: diagnosed_pending_action
author: Joker (CC)
priority: ⭐⭐⭐⭐⭐ 实盘干扰
tags:
  - KK
  - MT5
  - copier
  - agent双实例
  - 实盘故障
  - 进程去重
related:
  - "[[2026-05-06_企微IP白名单60020故障]]"
  - "[[VOLUME_ACCEL_v1_2026-05-10]]"
---

# 2026-05-10 KK MT5 弹窗轰炸 — copier agent 双实例打架

## 用户主诉
> "什么mt5全部关闭了，而且一直在弹登陆成功失败的提示"

## 一句话根因
**copier 系统的 agent.agent 进程被 venv + uv 双部署各跑一份, 两个 agent 同时尝试控制同一个 terminal64.exe → 互相 kill/restart 死循环 → 用户看到反复"登录成功"+"连接丢失"弹窗轰炸**.

## 诊断证据

### 1. terminal64 进程异常
| PID | 路径 | 状态 |
|---|---|---|
| 10640 | `D:\新建文件夹\terminal64.exe` | ⚠️ **孤儿进程** (中文目录, 不在标准 EBC-mt5/EBC-2/EBC-3/IC-tester 任何一个里) |
| 23984 | `D:\IC-tester\terminal64.exe` | 正常 (用于 strategy tester) |

但 **D:\EBC-mt5 / D:\EBC-2 / D:\EBC-3 此刻都没有 terminal64 在跑** — 它们刚被 agent 启动又被 kill. log 显示 EBC-2 (57170) 在 07:07 还有 authorize 事件, 但进程列表已无.

### 2. 双实例进程对 (核心问题)

每对都是同一个脚本被 mt5_venv (旧) + uv (新) 各跑一份:

| 控制目标 | uv 实例 (新) | mt5_venv 实例 (旧) | 风险等级 |
|---|---|---|---|
| **agent.agent --terminal D:\EBC-mt5** | PID 16544 | PID 21936 | 🔴 极高 |
| **agent.agent --terminal D:\EBC-2** | PID 22884 | PID 24068 | 🔴 极高 |
| **coordinator.server :9100** | PID 24528 | PID 22964 | 🔴 极高 |
| monitor_starbridge.py | PID 1512 | PID 696 | 🟡 中 |
| monitor_57171.py | PID 8768 | PID 17172 | 🟡 中 |
| ds57170/controller.py | PID 22736 | PID 20356 | 🟡 中 (实盘决策) |
| streamlit run | PID 24004 | PID 8076 | 🟢 低 |
| main.py port 8188 | PID 29016 | PID 31200 | 🟢 低 |

### 3. MT5 log 证据 (反复掉线重连)

**EBC-3 (57169):**
```
06:08:24 connection to EBCFinancialGroupKY-Demo lost
06:09:18 authorized on EBCFinancialGroupKY-Demo  
07:07:22 connection lost
07:07:27 authorized
```
每小时一次掉线 + 重连 → broker 服务器看到的是被频繁断开重连的客户端.

**IC-tester (52872396):**
```
08:30:07 authorized
08:36:13 connection lost
08:36:27 authorized
08:41:15 startup successfully (再次重启)
```
6 分钟一次重启.

### 4. 编译触发的 reload (我助攻方)

`D:\EBC-mt5\Logs\metaeditor.log`:
```
06:20 M1_OB_Reversal compile
06:24 A1_Trend_Continuation compile
06:27 A2_Momentum_Breakout compile
06:30 M21_FVG_MultiTF compile
07:30 RandomSignal_v1 compile
07:43 RandomSignal_v1 (6 errors)
07:44 RandomSignal_v1 fixed
08:39 LiqHunt_v1 compile
```
今天前一会话有 CC 在反复编译新 EA. 每次 compile MT5 reload .ex5 → terminal 自动 reauthorize → 弹"登录成功". 双实例打架 + 编译 reload 叠加触发暴增.

## 死循环机制

```
[t=0]  agent_uv 启动 D:\EBC-mt5\terminal64.exe
[t=1]  弹"登录成功 EBCFinancialGroupKY-Demo"
[t=2]  agent_mt5_venv 也尝试启动 D:\EBC-mt5\terminal64.exe
[t=3]  发现已有实例 → kill 现有再启 → 弹"连接丢失"
[t=4]  agent_uv 检测到 terminal 退出 → 重启
[t=5]  弹"登录成功"
[t=6]  agent_mt5_venv 再 kill → 弹"连接丢失"
... 死循环
```

每次 reload 双方向 broker 发 auth request → broker 每隔几小时主动断连 (rate limit) → 又一波 reauthorize.

## 不动的进程 (实盘关键, 风险大不要 kill)

- ❌ **wecom_bridge.py** 双实例: 一个是 Flask threaded worker fork, 不是真重复, 不要动.
- ❌ **ds57170/controller.py** 双实例: 实盘 DS 决策器, 可能在执行 trade 决策, 关错会停掉实盘. **需要用户确认 uv 还是 mt5_venv 是主版本后再 kill**.

## 待用户决策的行动方案

### 方案 A: CC 自动去重 (快但有风险)
1. 关闭 agent.agent + coordinator.server 的 mt5_venv 副本 (PID 21936/24068/22964)
2. 关闭 monitor 的 mt5_venv 副本 (PID 696/17172)
3. 关闭 streamlit/main.py 重复 (PID 8076/31200)
4. 杀掉孤儿 terminal64 (PID 10640, D:\新建文件夹\)
5. 重启 EBC-mt5 / EBC-2 / EBC-3 实例

**风险**: 如果 mt5_venv 副本是真正主进程而 uv 是僵尸, kill 错会停掉实盘 monitor. 用户备份 (`wecom_latest.md`) 之前提到 "venv+uv 双跑" 是已知 todo, 但没明确哪个是主.

### 方案 B: 用户先手动操作
1. 在 KK desktop 关闭 D:\新建文件夹\terminal64.exe (孤儿)
2. 用户告诉 CC 哪些 EBC 实例正在实盘 trade (跑着的 magic 号)
3. 用户告诉哪份 venv 是主版本
4. CC 据此精准去重

### 方案 C: 全停, 物理重启 (最干净)
1. 停所有 scheduled task: `Stop-ScheduledTask -TaskName MonitorEbc2,MonitorEbc3,MonitorEbcMt5,MonitorPois,MonitorStarBridge`
2. 用户用 Task Manager 强杀所有 python.exe + terminal64.exe
3. 选定的 task 重新 enable + start
4. **代价**: 实盘 trade monitor 中断 5-10 min

## 顺带发现的小坑

1. **`D:\新建文件夹` 是中文路径, 不应放 MT5 实例** — 中文路径在 EA 编译 / log 写入时容易触发编码 bug. 应迁移到 `D:\IC-tester2` 或类似 ASCII 路径.
2. **monitor_starbridge.log 大量 [err]**:
   ```
   [err] table market_at_event has 23 columns but 22 values were supplied
   ```
   monitor 在反复尝试写入 schema 不匹配的数据. 不致命但 log 占用 821KB 增长中.
3. **scheduled tasks 全是 "Ready" 状态** — 没自动跑. 双实例可能是手动启动后忘记 stop 旧版.

## 经验教训 (为下次)

1. **进程双实例**(venv + uv 各跑一份)是 KK 上**已知顽疾** (2026-05-06 wecom_latest.md 已列 todo, 拖到现在爆发). 应一次性彻底处理:
   - 选择标准: 优先保留 uv (因为更新), 除非旧 venv 有 uv 还没装的依赖
   - 部署新版本时强制 stop 老版本 ScheduledTask + kill 残留 PID
2. **MetaEditor 编译会 reload terminal64** → 多 CC 实例同时编译会触发风暴. 应:
   - 编译只在一个 terminal 实例上做 (推荐 D:\IC-tester, 不持仓)
   - 或者把测试 EA 编译目录跟实盘隔离
3. **看到反复弹"登录成功失败"** → **第一步检查是否 agent 双实例**, 不要先怀疑网络.

## 关联事件

- 2026-05-06 wecom 60020: 误诊 4h, 真因小龙虾(myclaw)掉线 → 学到"先问小龙虾在不在"
- 2026-05-10 (本次) MT5 弹窗轰炸: 真因 agent 双实例 → 应学到"先看 PowerShell Get-Process 双实例"

## 文件 / 工具

| 项 | 路径 |
|---|---|
| 诊断脚本 | `/tmp/diag_mt5.ps1` (mac) → `C:\Tools\diag_mt5.ps1` (KK) |
| 诊断输出 | session_backups/quant_latest.md 内嵌 |
| metaeditor.log | `D:\EBC-mt5\Logs\metaeditor.log` |
| MT5 日志 | `D:\EBC-2\Logs\20260510.log` 等 |
