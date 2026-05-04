---
type: master-index
maintained_by: TT
last_updated: 2026-05-04 03:55
update_rule: 每完成一项 / 接到新任务 立即更新
tags: [index, master, tasks]
---

# 总工作清单 — 全局指挥中心

> 用户决策时只看这一张表. 每个任务标注 状态 / 负责人 / 当前阻塞.

## 🟢 活跃运行中 (24/7 不停)

| ID | 任务 | 负责 | 状态 | 备注 |
|---|---|---|---|---|
| M1 | DS controller 主导 57170 交易 | TT | ✅ Running PID 29136 | 等开盘第一笔 |
| M2 | Scalper20_M1 multi-symbol 跑 57171 | TT (EA 已部署) | ✅ Monitor PID 15152 | 等用户挂 chart |
| M3 | Star Bridge 实盘 8010234 monitor | TT | ✅ Running PID 27408 | 反向工程, 等开盘抓 |
| M4 | Copier coordinator + agents | TT | ✅ PID 31492/24716/5260 | http://kk-win:9100/ |
| M5 | Wecom-bridge 企微 Joker | Joker | ✅ PID 7540 | 8765 端口 |
| M6 | Watchdog (3 min 自愈) | TT | ✅ Schtask KKWatchdog | 任何 monitor 死了自动救 |
| M7 | iCloud Vault → iPhone Obsidian | TT 已配 | ✅ 实时 | 30s-2min 延迟 |
| M8 | Vault → GitHub 每日 push | TT 已配 | ✅ 20:30 | klu188192-hub/Joker |

## 🟡 进行中 / 调试 / 等用户决策

| ID | 任务 | 负责 | 状态 | 阻塞/下一步 |
|---|---|---|---|---|
| P1 | TT-Joker 协调 wecom-bridge 优化 | TT (提议) | ⏳ 等 Joker 回复 | 30 min 内 (04:15) 没拒绝则 TT 静默写 tt_modules/ |
| P2 | tt_modules/trade_recap.py | TT | 🚧 草稿写完, 待测 | 等 Joker 确认后部署 KK |
| P3 | tt_modules/smc_detector.py | TT | ⏸️ 排队 | P2 完成后 |
| P4 | tt_modules/query_real_data.py | TT | ⏸️ 排队 | P2 完成后 |
| P5 | Joker 企微图文优化 (按用户聊天记录抱怨) | Joker | 🚧 进行中 | Tailscale funnel + 真实数据接入 |
| P6 | Scalper20 v0.27 回测 | ❓ | ❓ | 用户问过, TT 不确定状态 |

## 🔵 待启动 (有具体触发条件)

| ID | 任务 | 触发条件 |
|---|---|---|
| L1 | 实盘 smoke test 跟单 | 用户白天选 master/slave demo + 加路由 |
| L2 | AI 决策架构 D1 (LLM 过滤层) | v0.25 forward test PF ≥ 1.25 + 一致性 ≥ 80% |
| L3 | A/B 4 周对照 (57170 vs 57171) | D1 跑通 |
| L4 | 实盘 IC Markets VPS 部署 | A/B 胜出 |
| L5 | 推 copier 到 GitHub | 用户决定要不要新建 repo |

## ⚪ 暂停 / 低优先

| ID | 任务 | 状态 |
|---|---|---|
| X1 | 黑龙 EA 反向工程 | 用户暂停 |
| X2 | 备忘录指令通道 | ✅ 下架 (2026-05-04 03:30) |

## 📍 关键文件锚点

- 项目根 (Mac): `/Users/joker/{copier,tt_modules,ObsidianVault}/`
- KK 部署: `kk:C:\Tools\{copier,ds57170,wecom-bridge,monitor_*.db}\`
- iCloud Vault: `~/Library/Mobile Documents/iCloud~md~obsidian/Documents/ObsidianVault/`
- 当前每日 log: `Projects/每日工作_2026-05-04.md`

## 🔗 关联文档

- `Projects/明日早安_2026-05-04.md` — 今早状态摘要
- `Projects/MT5跟单系统_进度_2026-05-04.md` — 跟单 P1 详细
- `Projects/TT-Joker-协调_2026-05-04.md` — TT-Joker 协议
- `Trades/Scalper20/Scalper20_项目全貌_2026-05-03.md` — Scalper20 主文档
- `Trades/Scalper20/仓位bug修复报告.md`

## 🚦 决策待确认 (用户 → TT)

1. 跟单实盘 smoke 用哪 2 个 demo (EBC-4 ~ EBC-10)?
2. copier 推 GitHub (新 repo or 加到 obsidian repo 子目录)?
3. tt_modules/ 等 Joker 回复后立即部署 还是等用户白天明确?
4. 是否需要每天早 6:00 自动企微 push 状态报告?
