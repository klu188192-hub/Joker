---
rank: 10
broker: IC Markets RAW 10pt
frequency: 18.61/日
mdd: 19.28%
final_equity_compound: $83,994,960
final_equity_fixed: $213,174
cagr: 445.20%
status: ⭐⭐ IC 实战推荐
date: 2026-05-08
tags: [ic, raw, 4tf, cmin2, soft, compound, fixed_lot, profit_archive]
---

# 10 — IC 10pt / 4 TF cmin=2 soft（IC 实战 ⭐⭐）

> IC Markets RAW account (avg spread 10pt) 实战配置
> 4 TF 全部直接开仓（不像 EBC 上 M15 只能作 confluence 投票）

## 配置

```yaml
broker_spread: 10  # IC RAW
EA_filter: InpMaxSpreadPts=15  # 留 5pt buffer
RR: 1.0
SL: vanilla 0.5×ATR (10pt 下不需 dyn SL)
TF_subset: ALL 4 TFs (H4+M15, H1+M5, M30+M1, M15+M1) ← 全部实开
confluence_min: 2
bonus: soft (conf=2/3/4 → ×1.0/1.2/1.5)
SB_hour_filter: 关
risk_mode: 1% per trade compound 或 fixed 0.10 lot
```

## 复利 1%/笔（高资金）

| 项 | 值 |
|---|---:|
| **终值** | **$83,994,960** |
| ROI | +839,850% |
| CAGR | +445.20% |
| MDD% | 19.28% |
| MDD$ | $1,254,137 |

## 不复利 fixed 0.10 lot（低资金）

| 项 | 值 |
|---|---:|
| **终值** | **$213,174** |
| ROI | +2,031% |
| CAGR | +77.58% |
| MDD% | 4.1% |

## 笔数 / 质量（共通）

| 项 | 值 |
|---|---:|
| 总笔数 | 24,981 |
| /交易日 | **18.61** |
| WR | 63.21% (复利) / 63.2% (fixed) |
| PF | 2.04 / 2.07 |
| Sharpe | 5.91 (复利) |
| 最长连胜/连亏 | 26 / 15 |

## 单笔细节（复利）

- 平均每笔: +$3,362
- 最大单笔赢: +$751,202
- 最大单笔亏: -$651,694
- 首 10 笔均 lot: 0.901 手
- 末 10 笔均 lot: 50 手（broker max）

## 单 TF 数据 (RR=1 / 10pt / fixed 0.10)

| TF | 笔数 | WR | PF | MDD | Net |
|---|---:|---:|---:|---:|---:|
| H4+M15 | 1383 | 60.6% | 1.83 | 6.5% | +$27,753 |
| H1+M5 | 5553 | 61.6% | 1.87 | 3.6% | +$62,973 |
| M30+M1 | 11528 | 56.7% | 1.42 | 3.1% | +$33,840 |
| M15+M1 | 22736 | 59.2% | 1.68 | 3.1% | +$88,107 |

## 实战 EA 部署

```
EA1: H4 chart, magic 57171001, RR=1.0, vanilla SL, MaxSpread=15
EA2: H1 chart, magic 57171002, RR=1.0, vanilla SL, MaxSpread=15
EA3: M30 chart, magic 57171003, RR=1.0, vanilla SL, MaxSpread=15
EA4: M15 chart, magic 57171004, RR=1.0, vanilla SL, MaxSpread=15
+ Confluence dispatcher: ≥2 TF 同向 60min 内才允许开仓
```

**4 EA 全部直接开仓**（M15 不再仅作投票）。

## EBC vs IC 对比

| 项 | EBC 35pt | IC 10pt | 倍数 |
|---|---:|---:|---:|
| 频率/日 | 9.71 | 18.61 | 1.92x |
| 复利 5y 终值 | $32.8M | $84.0M | **2.56x** |
| 不复利 5y 终值 | $139K | $213K | 1.53x |
| MDD% | 14.06% | 19.28% | 1.37x |

## 适用

- 已开 IC RAW 账户
- 资金 ≥ 5 万（扛住 19% MDD）
- 想最大化收益（5y 复利 8400 倍 vs EBC 3300 倍）

## 复现

```bash
cd /Users/joker/factor_factory_archive/v2026-05-08_IC_4TF_RR1_compound
python3 macd_portfolio_compound_3tf.py \
  trades_h4m15_10rr1.csv "H4+M15" \
  trades_h1m5_10rr1.csv "H1+M5" \
  trades_m30m1_10rr1.csv "M30+M1" \
  trades_m15m1_10rr1.csv "M15+M1"
```
