---
rank: 2
broker: EBC 35pt
frequency: 3.35/日
mdd: 10.30%
final_equity: $17,649,753
cagr: 306.80%
status: ✅ 中频低风险
date: 2026-05-08
tags: [ebc, 2tf, cmin2, soft, compound, profit_archive]
---

# 02 — EBC 35pt / only H4+H1 cmin=2 soft

> 简化版：仅 2 个高 TF + confluence 共振，不需 dyn SL

## 配置

```yaml
broker_spread: 35
RR: 1.0
SL: vanilla 0.5×ATR (no dyn SL needed for H4/H1)
TF_subset: H4+M15, H1+M5  # 仅 2 个 TF
confluence_min: 2  # H4 与 H1 必须同向才开仓
bonus: soft (conf=2: ×1.0, =3: ×1.2, =4: ×1.5)
SB_hour_filter: 关
risk_mode: 1% per trade compound
```

## 关键指标

| 项 | 值 |
|---|---:|
| **终值** | **$17,649,753** |
| 净盈利 | +$17,639,753 |
| ROI | +176,398% |
| CAGR | +306.80% |
| **MDD%** | **10.30%** |
| 笔数 | 4,497 |
| /日 | 3.35 |
| WR | 63.50% |
| PF | 2.06 |
| Sharpe | (推算 ~3.5) |

## 优势

- **极简部署**：只需 2 个 EA + confluence dispatcher
- 不需 dynamic SL（H1+H4 SL 本来 > spread×3）
- WR 63.5% 接近 Obsidian 0pt 基准 (63.7%)

## 适用场景

- 不想管 M30+M1 的 dyn SL 配置
- 偏好低频（3.35/日 vs 9.71/日）
- 单 EA 调试简单
