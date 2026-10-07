---
type: portfolio_combination
mode: 1% risk compound
date: 2026-05-08
status: ✅ 精确组合验证 — Gap v3 在复利账户中放大 19-20x
tags: [portfolio, macd, gap_reject_v3, compound, profit_archive]
---

# MACD 4 TF + Gap Reject v3 组合（复利）

> 同一账户跑 MACD 主力 + Gap v3 极低频精射手
> Gap v3 trades 按当时账户余额复利放大 lot

## 配置

```yaml
broker: IC 10pt 或 EBC 35pt
risk_mode: 1% per trade compound (max_lot=50)

MACD 主力:
  TF: H4+M15 + H1+M5 + M30+M1 + M15+M1 (IC) / 仅前 3 TF 实开 (EBC)
  RR: 1.0
  confluence_min: 2
  bonus: soft (1.0/1.0/1.2/1.5)
  M30+M1 EBC sl_spread_mul: 3.0

Gap v3 精射手:
  TF: H1
  样本: 10 笔 / 5y (2024-04 ~ 2025-07)
  SL: 600pt (2×ATR)
  TP: 1200pt (4×ATR, RR=1:2)
  WR: 80% (8/10)
  PF (单跑 lot 2.5): 8.57
```

## 5y 复利结果

| 方案 | 纯 MACD | + Gap v3 | Gap 实际贡献 | Gap 放大倍数 | MDD |
|---|---:|---:|---:|---:|---:|
| **IC 10pt 4TF 全开** | $83.99M | **$84.63M** | +$623,664 | **20.0x** | 19.3% |
| **EBC 35pt no smallest** | $32.81M | **$33.52M** | +$591,179 | **19.0x** | 14.1% |

## Gap v3 触发时账户余额

| broker | 第 1 笔 Gap (2024-04-01) | 实际 lot | 单笔 PnL |
|---|---:|---:|---:|
| IC 10pt | $22,150,256 | 50 (撞顶) | +$60K-120K |
| EBC 35pt | $2,486,359 | 41.4 | +$50K-100K |

vs 单跑 $10K 起 lot 2.5：
- IC 第 1 笔账户已被 MACD 长大 **2,215x**
- EBC 第 1 笔账户已被 MACD 长大 **249x**

## Gap v3 增益占比

```
IC: +$623K / $84M = 0.74%   (Gap 是次要贡献者)
EBC: +$591K / $33M = 1.79%  (相对贡献略高)
```

## 关键洞察

1. **Gap v3 自身复利效应**：5y 共 10 笔，几乎全程撞 broker max_lot=50。但因 risk per trade 1% 在大账户上对应 lot 远超 50，所以 Gap v3 吃满了 broker 限额
2. **MDD 几乎不变**：Gap v3 极低频 + WR 80% + PF 8.57 = 几乎无负贡献
3. **不要被单跑 +$31K 误导**：复利账户里实际放大 20x，但相对 MACD 主力仍占比小
4. **Gap v3 是"锦上添花"不是"主力"**：MACD 4 TF 已是绝对主力，Gap 加分但不改大局

## ⚠️ 实盘风险

- Gap v3 仅 10 笔 / 5y → **统计不显著**（p>0.1）
- 触发集中 2024-04-06 + 2025-07，可能纯属市场环境偶然
- 实盘前必须 **demo 跟踪 4-8 周** 验证
- 部署初期 **不要用 lot 2.5**，先 lot 0.10 观察 5-10 笔

## 复现命令

```bash
cd /Users/joker/factor_factory_archive/v2026-05-08_IC_4TF_RR1_compound/
python3 portfolio_with_gap.py
# 输出 portfolio_with_gap_v2_out.txt
```

## 输入数据

- `_gap_v3_a_trades.csv` — Gap v3 10 笔 (lot 2.5)
- `trades_h4m15_*.csv` 等 — MACD 4 TF
- 转换：Gap v3 pnl_net / 25 = 等价 lot 0.10 PnL

## 下一步

- [ ] 加 SB confluence（amp 1.5x / damp 0.5x）到 MACD 主力
- [ ] 验证 SB 对 4 TF 复利的影响（Obsidian baseline 是 H1+M15 single TF）
- [ ] 实盘 demo Phase 1（纯 MACD 4 TF）跟踪 4-8 周
