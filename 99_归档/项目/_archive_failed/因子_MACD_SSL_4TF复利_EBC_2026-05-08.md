---
project: 因子工厂
factor: MACD+SSL 4 TF 复利组合（EBC）
status: ⭐ EBC 35pt 实战方案敲定 — 1 万 → $32.8M / CAGR 357%
date: 2026-05-08
maintained_by: VV
tags: [factor, xau, macd, ssl_sweep, multi_tf, confluence, compound, ebc, real_alpha]
related:
  - "[[因子_MACD_SSL_TF矩阵_2026-05-07]]"
  - "[[因子_MACD底背离SSL扫荡_2026-05-07]]"
---

# MACD+SSL 4 TF 复利组合 — EBC 35pt 实战方案

> 5.33 年回测 (2021-01-04 → 2026-05-04, XAUUSD)
> 假设: EBC broker 平均 spread 35pt, EA 加 InpMaxSpreadPts=35 上限
> 风控: risk_per_trade = 1% × current_equity (复利)

## 🚀 推荐方案 ⭐（最高终值 / MDD 可控）

```
TF 子集:        H4+M15 + H1+M5 + M30+M1 (M15 仅作 confluence 投票, 不直接开仓)
SL 配置:        H4/H1 vanilla SL = 0.5×ATR
              M30+M1 用 sl_spread_mul=3.0 (SL ≥ spread × 3 = 105pt)
RR:             1.0
Confluence:     ≥2 TF 同向 60min 内才开仓
Bonus:          soft (conf=2/3/4 → lot ×1.0/1.2/1.5)
SB hour filter: 不用
```

### 1 万美金 5.33 年（复利 1%/笔）

| 项 | 值 |
|---|---:|
| **终值** | **$32,805,383** |
| 净盈利 | +$32,795,383 |
| 累计 ROI | +327,953% |
| **CAGR (年化)** | **+357.00%** |
| **MDD%** | **14.06%** |
| MDD$ | $818,553 |

### 笔数 / 质量

| 项 | 值 |
|---|---:|
| 总笔数 | 13,040 |
| **/交易日** | **9.71** |
| **WR** | **61.35%** |
| **PF** | **1.71** |
| **Sharpe** | **3.89** |
| 最长连胜/连亏 | 33 / 10 |

### 单笔细节

| 项 | 值 |
|---|---:|
| 平均每笔 PnL | **+$2,515** |
| 最大单笔赢 | +$333,389 |
| 最大单笔亏 | -$281,107 |
| 首 10 笔均 lot | 0.461 手 |
| 末 10 笔均 lot | 50.00 手（broker max） |
| 最大 lot | 50.00 手 |

## 完整 conf_min 对比（4 TF / RR=1 / 35pt / dyn SL）

| TF 集 | cmin | bonus | /日 | 笔数 | PF | WR | MDD% | Net 5.33y | 状态 |
|---|---:|---|---:|---:|---:|---:|---:|---:|:---:|
| ALL 4 TFs | 1 | flat | 1.93 | 2594 | 0.77 | 54.7% | 90% | -$9K | 💥爆仓 |
| ALL 4 TFs | 2 | flat | 17.57 | 23591 | 1.75 | 60.9% | 85.3% | +$14.2M | ⚠️ |
| ALL 4 TFs | 2 | soft | 17.57 | 23591 | 1.79 | 60.9% | 71.1% | +$24.7M | ⚠️ |
| ALL 4 TFs | 3 | flat | 3.59 | 4819 | 2.33 | 66.1% | 10.0% | +$13.4M | ✅ 安全 |
| **no smallest** ⭐ | **2** | **soft** | **9.71** | **13040** | **1.71** | **61.3%** | **14.1%** | **+$32.8M** | **⭐推荐** |
| no smallest | 2 | flat | 9.71 | 13040 | 1.73 | 61.3% | 19.9% | +$28.7M | ✅ |
| no smallest | 3 | flat | 2.66 | 3576 | 2.58 | 67.3% | 7.4% | +$13.7M | ✅ 极稳 |
| only H4+H1 | 2 | soft | 3.35 | 4497 | 2.06 | 63.5% | 10.3% | +$17.6M | ✅ |
| only H4+H1 | 3 | flat | 1.97 | 2639 | 2.99 | 68.7% | 9.7% | +$9.9M | ✅ 极稳 |

> ⚠️ "no smallest" = H4+M15 + H1+M5 + M30+M1（实际开仓的 3 TF）
> M15+M1 的信号用作 confluence 第 4 票（不开仓），让 H4/H1/M30 的 conf=2 命中率提升

## 关键洞察

### 为什么 M15+M1 不直接开仓？

35pt spread 下 M15+M1 数学不通过：
- 单 TF M15+M1 PF 1.05 / MDD 253% 边缘亏损
- 加进 portfolio 直接交易会拖累整体（4 TF cmin=2 ALL TFs MDD 71-85%）
- 但 M15+M1 信号源**质量是好的**（0pt 时 PF 1.98 / Sharpe 2.67）
- 最优用法：**作为 confluence 投票，不直接开仓**

### 为什么 conf=1 必爆仓？

35pt spread 下，**单 TF 独立信号 PF<1**：
- conf=1 全开放 PF 0.77
- conf=2 多 TF 共振 PF 1.71
- conf=3 三 TF 同向 PF 2.33+

confluence ≥2 是 EBC 35pt 下的**数学硬约束**，不是策略偏好。

### 为什么 SB hour filter 拖累？

SB sweet hours (UTC 1/4/6/8/10-19) 的 ×1.5 lot 加大波动，增加 MDD。
EBC 实战可考虑 SB **黑名单**（只跳过 UTC 7/9）但不加 lot 倍数。

## 备选档（不同风险偏好）

### A. 高频中等回撤（推荐）⭐
```
no smallest cmin=2 soft
9.71/日, MDD 14.1%, 1万→$32.8M
```

### B. 中频低回撤
```
only H4+H1 cmin=2 soft
3.35/日, MDD 10.3%, 1万→$17.6M
```

### C. 低频极低回撤
```
no smallest cmin=3 flat
2.66/日, MDD 7.4%, 1万→$13.7M
```

### D. 含 M15 高频高风险（不推荐）
```
ALL 4 TFs cmin=2 soft
17.57/日, MDD 71%, 1万→$24.7M
```

## 实战 EA 部署

```
EA1: H4 chart, magic 57171001
     InpRR=1.0, InpSLATRMul=0.5
     InpMaxSpreadPts=35
     lot = 1% risk_per_trade（动态）

EA2: H1 chart, magic 57171002
     InpRR=1.0, InpSLATRMul=0.5
     InpMaxSpreadPts=35
     lot = 1% risk_per_trade

EA3: M30 chart, magic 57171003
     InpRR=1.0, InpSLATRMul=0.5
     InpSLSpreadMul=3.0  ← M30+M1 关键参数
     InpMaxSpreadPts=35
     lot = 1% risk_per_trade

EA4 (signal-only, no order): M15 chart, magic 57171004
     仅生成信号给 confluence dispatcher
     不实际开仓

Confluence dispatcher (独立进程或 EA5):
     聚合 4 EA 的 entry signal
     当 ≥2 TF 同向 60min 内 → 允许 EA1/2/3 开仓
     conf=2 → lot×1.0
     conf=3 → lot×1.2
     conf=4 → lot×1.5
```

## ⚠️ 重要 caveat

1. **broker max_lot=50 起作用**：账户 > $5M 后 lot 触顶，复利停止线性放大
   - CAGR 357% 是前期真实增长 + 后期触顶混合数字
   - 真实 5y 累计应折扣 30-50%（$32M → 估 $15-22M 实际）

2. **1 万账户冷启动风险高**：
   - 早期单笔最大亏 ~$281K（按末期 lot 算），早期 0.46 lot 时单笔亏估 $2-5K
   - 1 万账户连亏 10 笔（最长记录）可能直接爆仓
   - 建议 5 万起步，避免冷启动死亡螺旋

3. **EBC spread 突变风险**：
   - InpMaxSpreadPts=35 是必须的，跳过 spread > 35 的瞬间
   - 数据公布前后 spread 可能瞬变 100pt+

4. **回测假设**：
   - 固定 35pt spread（实际 EBC 平均 30-60pt）
   - 加 spread filter 后实际开仓 spread ≤ 35（更乐观）
   - 真实表现应介于此回测和 0pt 基准之间

## 归档位置

- mac: `/Users/joker/factor_factory_archive/v2026-05-08_EBC_3TF_RR1_compound/`
- KK: `D:\factor_factory_archive\v2026-05-08_EBC_3TF_RR1_compound\` (待同步)
- trades csv 全部冻结
- 复现命令见 MANIFEST.md

## 待补

- IC Markets RAW (10pt) 4 TF 复利方案（数据跑中，~30 分钟）
- 净值曲线 PNG（1 万 → $32.8M 路径）
- 月度 PnL 分布
- 实战 demo forward test（57171）

---

*v0.1 · 2026-05-08 · VV 写于 4 TF compound + dynamic SL + EBC 35pt 实战配置敲定后*
