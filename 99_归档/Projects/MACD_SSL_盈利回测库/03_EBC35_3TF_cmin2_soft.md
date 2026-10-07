---
rank: 3
broker: EBC 35pt
frequency: 3.40/日
mdd: 8.02%
final_equity: $17,803,799
cagr: 307.77%
status: ✅ 中频极低 MDD
date: 2026-05-08
tags: [ebc, 3tf, cmin2, soft, compound, profit_archive]
---

# 03 — EBC 35pt / 3 TF cmin=2 soft（无 M15 投票）

> 与 #01 区别：confluence 仅在 3 TF 间计算（M15+M1 完全不参与）

## 配置

```yaml
broker_spread: 35
RR: 1.0
SL:
  H4+M15:  vanilla 0.5×ATR
  H1+M5:   vanilla 0.5×ATR
  M30+M1:  sl_spread_mul=3.0
TF_subset_for_confluence: H4+M15, H1+M5, M30+M1  # 仅 3 TF
TF_subset_for_trading:    同上
confluence_min: 2  # 3 TF 中至少 2 个同向
bonus: soft
SB_hour_filter: 关
risk_mode: 1% per trade compound
```

## 关键指标

| 项 | 值 |
|---|---:|
| **终值** | **$17,803,799** |
| 净盈利 | +$17,793,799 |
| ROI | +177,938% |
| CAGR | +307.77% |
| **MDD%** | **8.02%** ← 比 #01 更低 |
| MDD$ | $524,853 |
| 笔数 | 4,562 |
| /日 | 3.40 |
| WR | 65.56% |
| PF | 2.20 |
| Sharpe | 3.73 |

## 与 #01 (4 TF 含 M15 投票) 对比

| 维度 | 03 (3 TF) | 01 (4 TF) | 差异 |
|---|---:|---:|---|
| 频率 | 3.40 | 9.71 | M15 加进 confluence 让 conf=2 命中率 ↑ 2.85x |
| WR | 65.56% | 61.35% | 3 TF 更严，质量更高 |
| PF | 2.20 | 1.71 | 3 TF PF 高 0.49 |
| MDD% | 8.02% | 14.06% | 3 TF 更稳 |
| 终值 | $17.8M | $32.8M | 4 TF 高频赚更多但风险更大 |

## 何时选 #03 vs #01

- **选 #03**：偏好稳健 / 资金小 / 不想管 M15 EA
- **选 #01**：追求最大终值 / 5 万+ 起始资金能扛 14% MDD

## 复现

```bash
python3 macd_portfolio_compound_3tf.py \
  trades_h4m15_35rr1.csv "H4+M15" \
  trades_h1m5_35rr1.csv "H1+M5" \
  trades_m30m1_35rr1_sl3.csv "M30+M1"
# 推荐行: ALL TFs cmin=2 soft
```
