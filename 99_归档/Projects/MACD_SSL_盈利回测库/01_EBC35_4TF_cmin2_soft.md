---
rank: 1
broker: EBC 35pt
frequency: 9.71/日
mdd: 14.06%
final_equity: $32,805,383
cagr: 357.00%
status: ⭐ 推荐
date: 2026-05-08
tags: [ebc, 4tf, cmin2, soft, compound, profit_archive]
---

# 01 — EBC 35pt / no smallest cmin=2 soft ⭐

> **EBC 实战推荐方案**：H4+H1+M30 真交易，M15 作 confluence 第 4 票

## 配置

```yaml
broker_spread: 35  # EBC 平均
EA_filter: InpMaxSpreadPts=35
RR: 1.0
SL:
  H4+M15:  vanilla 0.5×ATR (~500pt)
  H1+M5:   vanilla 0.5×ATR (~200pt)
  M30+M1:  sl_spread_mul=3.0 (SL ≥ 105pt)
  M15+M1:  仅信号源, 不开仓
TF_subset: H4+M15, H1+M5, M30+M1  # M15 不开仓
confluence_min: 2  # 需 ≥2 TF 同向 60min 内
bonus: soft
  conf=2: lot×1.0
  conf=3: lot×1.2
  conf=4: lot×1.5
SB_hour_filter: 关
risk_mode: 1% per trade compound (max_lot=50)
```

## 1 万美金 5.33 年关键指标

| 项 | 值 |
|---|---:|
| **终值** | **$32,805,383** |
| 净盈利 | +$32,795,383 |
| ROI | +327,953% |
| **CAGR** | **+357.00%** |
| **MDD%** | **14.06%** |
| MDD$ | $818,553 |

## 笔数 / 质量

| 项 | 值 |
|---|---:|
| 总笔数 | 13,040 |
| /交易日 | 9.71 |
| **WR** | **61.35%** |
| **PF** | **1.71** |
| **Sharpe** | **3.89** |
| 最长连胜/连亏 | 33 / 10 |

## 单笔细节

- 平均每笔 PnL: **+$2,515**
- 最大单笔赢: +$333,389
- 最大单笔亏: -$281,107
- 首 10 笔均 lot: 0.461 手
- 末 10 笔均 lot: 50.00 手（broker max）

## 实战 EA 部署

```
EA1: H4 chart, magic 57171001, lot=动态(1% risk), MaxSpread=35
EA2: H1 chart, magic 57171002, lot=动态(1% risk), MaxSpread=35
EA3: M30 chart, magic 57171003, SLSpreadMul=3, lot=动态, MaxSpread=35
EA4 (signal-only): M15 chart, magic 57171004, 不实际开仓
+ Confluence dispatcher: ≥2 TF 同向 60min 内才允许 EA1/2/3 开仓
```

## 复现命令

```bash
cd /Users/joker/factor_factory_archive/v2026-05-08_EBC_3TF_RR1_compound
python3 macd_portfolio_compound_3tf.py \
  trades_h4m15_35rr1.csv "H4+M15" \
  trades_h1m5_35rr1.csv "H1+M5" \
  trades_m30m1_35rr1_sl3.csv "M30+M1" \
  trades_m15m1_35rr1.csv "M15+M1"  # M15 仅 confluence 用
# 结果: TF set = "no smallest" cmin=2 soft 行
```

## ⚠️ 实战风险

- 1 万账户连亏 10 笔（最长记录）+ 早期 lot 0.46 手 → 累计亏 ~$5K = 50% 本金
- 建议 **5 万起步** 缓冲冷启动
- 末期 lot 触顶 50 手，CAGR 实际打折 30-50%
- spread 突变 > 35 时 EA 自动停开仓
