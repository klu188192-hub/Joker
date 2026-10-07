---
rank: 4
broker: EBC 35pt
frequency: 2.66/日
mdd: 7.40%
final_equity: $13,730,524
cagr: 288.10%
status: ✅ 极低风险
date: 2026-05-08
tags: [ebc, 3tf, cmin3, flat, compound, profit_archive]
---

# 04 — EBC 35pt / no smallest cmin=3 flat（极保守）

> 极严格 confluence：仅在 3 TF 全同向时开仓

## 配置

```yaml
broker_spread: 35
RR: 1.0
SL:
  H4+M15:  vanilla
  H1+M5:   vanilla
  M30+M1:  sl_spread_mul=3.0
TF_subset_for_confluence: 4 TFs (含 M15 投票)
TF_subset_for_trading: 3 TFs (no smallest)
confluence_min: 3  # 至少 3 TF 同向 60min 内
bonus: flat (无 lot 加权, 全 ×1.0)
risk_mode: 1% per trade compound
```

## 关键指标

| 项 | 值 |
|---|---:|
| **终值** | **$13,730,524** |
| CAGR | +288.10% |
| **MDD%** | **7.40%** ← 极低 |
| 笔数 | 3,576 |
| /日 | 2.66 |
| **WR** | **67.27%** |
| **PF** | **2.58** |

## 适用

- 风险极度厌恶
- 资金 <5 万起步
- 想要 MDD < 10% 的极稳方案
- WR 67% 接近 Obsidian RR=1 H1+M5 0pt 基准（63.7%）+ confluence 增益
