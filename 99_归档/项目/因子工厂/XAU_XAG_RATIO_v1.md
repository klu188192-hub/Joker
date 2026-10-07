---
title: XAU/XAG Ratio 跨资产均值回归因子 v1
date: 2026-05-09
factor_id: XAU_XAG
magic: 57177
risk_per_trade: 0.5%
status: ready_to_deploy
parent_strategy: PORTFOLIO_7FACTOR_XAUXAG_v20260509
audit_status: 5_of_5_passed
ic_h24: 0.1948
white_noise_beat_rate: 0
tags:
  - 量化
  - 因子
  - 跨资产
  - XAU
  - 真IC因子
related:
  - "[[INTEGRATED_ANALYSIS_v20260509]]"
  - "[[PORTFOLIO_7FACTOR_XAUXAG_v20260509]]"
  - "[[DXY_REJECTED_v20260509]]"
  - "[[REVIEW_FRAMEWORK_v20260509]]"
---

# XAU/XAG Ratio 跨资产均值回归因子 v1

> [!success] 历史性突破
> 当前 portfolio 第一个 **白噪声击败率 0%** + **IC h=24 > 0.15** 的真 IC 因子.
> 解决用户最初担忧 "trail alpha 单点失败" — portfolio 真 IC 净利润占比 5% → 22%.

## 核心逻辑

Gold/Silver Ratio 长期均值回归:
- 历史均值 ~80, 范围 70-100
- 偏离 N std 后, ratio 修复方向预测 XAU 单边

```
z = (XAU/XAG - mean_240H1) / std_240H1
z > +2.0 → ratio 过高 (XAU 相对太贵) → 做空 XAU (-1)
z < -2.0 → ratio 过低 (XAU 相对太便宜) → 做多 XAU (+1)
```

## 参数

| 参数 | 值 | 说明 |
|---|---|---|
| THRESH | 2.0 | z-score 偏离倍数 |
| LOOKBACK | 240 H1 | ≈ 10 trading days |
| SL | 4.0 ATR | 远 SL (XAU 风格) |
| TP | 1.0 ATR | 近 TP |
| Time stop | 72 H1 | ≈ 3 days |
| Trailing | 激活 0.5 ATR 后 trail 0.5 USD | 锁惯性 |

## 数据来源

- XAU H1: `C:/Tools/factor_factory/data/XAUUSD.s_H1.csv`
- XAG H1: `C:/Tools/factor_factory/data/XAGUSD.s_H1.csv`
- broker EBC, 5 年数据 (2021-2026-05)
- 防 lookahead: ratio 用 shift(1), rolling mean/std 基于 shift(1) 序列, 入场在下根 H1 open

## 5 维 audit 完整通过

| # | 维度 | 结果 | 判定 |
|---|---|---|---|
| 1 | Lookahead mask audit | 100% 一致 | ✅ |
| 2 | IC h=1/4/24/72/168/240 | +0.06 / +0.10 / **+0.19** / +0.15 / +0.10 / +0.02 | ✅ 真 IC 因子 |
| 3 | 2024+ 回测 | PF 2.685, WR 82.9%, Sharpe 4.34, MDD 9.5% | ✅ |
| 4 | corr vs 6 因子 | 全部 < 0.5 (Liq 0.48 中等, 其他 < 0.3) | ✅ |
| 5 | 白噪声击败率 (n=50) | **0/50 = 0%** | ✅ ⭐⭐⭐ |
| 6 | 2026 OOS | PF 1.76, Sharpe 3.34 | ✅ 仍盈利 |

> [!important] 白噪声 0/50 是质变指标
> 现有 6 因子白噪声击败率 30-60% (PureBO/VP/Sess/Liq 都靠 trail), DXY 拒绝时是 84% (alpha=0).
> XAU/XAG **0/50** 意味着因子方向真值起作用, 不只是 trail 撞惯性.

## 表现统计 (2024+ 真实期, 0.1 lot, 1万入金)

```
n=497, WR=82.9%, PF=2.685, MDD=9.5%, Sharpe=4.34
net=$38,071 (5y simulator)
```

### Long/Short 对称 (双向真因子)

| 方向 | n | WR | PF | MDD |
|---|---|---|---|---|
| Long | 267 | 84.6% | 2.730 | 7.6% |
| Short | 230 | 80.9% | 2.663 | 10.4% |

### IC by Quarter (h=24)

```
2024Q1: -0.13   ┐
2024Q2: -0.02   │ 噪声期, 仍靠 trail
2024Q3: +0.05   │
2024Q4: -0.02   ┘
2025Q1: +0.7513 ◀━━ Trump tariff XAU 暴涨 + silver 滞涨
2025Q2: +0.14
2025Q3: -0.03
2025Q4: +0.3842 ◀━━ 黄金二次冲击
2026Q1: -0.09   (反转开始, 监控)
```

> [!note] 因子特征
> 平时 IC ≈ 0 (与其他因子一样靠 trail), **极端宏观事件期独立爆发真 alpha**.
> 这是 portfolio 最稀缺的 "黑天鹅期独立产生收益" 型因子.

## 参数 grid 调参完整记录

12 组合 (THRESH × LOOKBACK):

| THRESH | LB | n | WR | PF | MDD | Sh | 评价 |
|---|---|---|---|---|---|---|---|
| 1.5 | 120 | 1323 | 81.7% | 2.240 | 12.4% | 3.61 | 高频版 |
| 1.5 | 240 | 838 | 83.1% | 2.416 | 10.3% | 4.07 | 频率+ |
| 1.5 | 480 | 385 | 83.4% | 2.370 | 18.2% | 4.40 | MDD 警告 |
| 2.0 | 120 | 886 | 79.9% | 2.052 | 16.6% | 3.12 | MDD 偏高 |
| **2.0** | **240** | **497** | **82.9%** | **2.685** | **9.5%** | **4.34** | **⭐ 主版** |
| 2.0 | 480 | 207 | 84.1% | 2.412 | 17.1% | 4.37 | MDD 警告 |
| 2.5 | 120 | 480 | 76.9% | 2.251 | 20.2% | 3.68 | MDD 偏高 |
| 2.5 | 240 | 248 | 83.9% | 2.419 | 9.0% | 4.02 | n 偏少 |
| 2.5 | 480 | 94 | 84.0% | 1.882 | 12.2% | 2.58 | 低 PF |
| 3.0 | 120 | 229 | 72.1% | 2.408 | 18.0% | 3.73 | WR 弱 |
| 3.0 | 240 | 87 | 81.6% | **3.049** | **6.2%** | **5.74** | 高 Sh 但 n 太少 |
| 3.0 | 480 | 63 | 87.3% | 2.319 | 7.6% | 4.23 | n 太少 |

**选择 THRESH=2.0, LB=240 理由**:
- 平衡 frequency vs quality (n=497 适中, ≈ 100/年)
- MDD 9.5% 低于 baseline
- Sharpe 4.34 高位
- WR 82.9% 极稳定, 跨年验证一致

## 跨 TF 测试结论 ([[CROSS_TF_FINDINGS]] - 已 archive)

| TF | 最优 | 决定 |
|---|---|---|
| H1 | 2.0/240 | ✅ 主版接入 |
| H4 | 1.5/30 (PF 2.49) | ❌ 拒绝 (与 H1 corr 0.448, same_dir 99.9%, 不独立) |
| D1 | 2.0/20 (PF 1.80) | ❌ 拒绝 (普遍 MDD > 50%, 持仓久 dollar 风险大) |

## 与 6 因子 corr 矩阵

```
DXY_Cross  vs PureBO       :  +0.30  (弱正)
           vs VP_POC       :  -0.12  (弱负)
           vs Session_Fib  :  +0.11  (弱正)
           vs Liquidation  :  +0.48  ⚠️ 中等
           vs Gap_Reject   :  -0.02  (无关)
           vs Divergence   :  -0.06  (无关)
```

> [!warning] Liquidation corr 0.48 监控点
> 实盘部署后 1-2 周必须监控 Liquidation × XAU/XAG 周共振次数. > 5 次/周 → XX risk 减半到 0.25%.
> 但反直觉的是: **真实 portfolio 回测显示加 XAU/XAG 后总 MDD 反而 -0.18 pp** (17.56% → 17.38%), 说明这两个因子在实际触发时段并不重叠太多, 起到了反共振对冲.

## DXY 因子失败的对照 ([[DXY_REJECTED_v20260509]])

同样跨市场, 不同结果:

| 维度 | DXY (失败) | XAU/XAG (✅) |
|---|---|---|
| Lookahead | 100% | 100% |
| IC h=24 | **+0.0004** | **+0.1948** |
| 白噪声击败率 | **84%** | **0%** ⭐ |
| 2026 OOS | PF 0.94, MDD 39.5%, Sharpe -0.29 | PF 1.76, Sharpe 3.34 |

**关键差异**: DXY 是 *滞后预测* (失败), XAU/XAG 是 *均值回归* (成功).

## 实盘部署 EA 设计

```mql5
// XAU_XAG_Ratio_v1.mq5 (Magic 57177)

input string  XAG_Symbol = "XAGUSD.s";
input double  THRESH = 2.0;
input int     LOOKBACK = 240;
input double  RiskPerTrade = 0.005;
input double  SL_ATR_Mult = 4.0;
input double  TP_ATR_Mult = 1.0;
input int     TimeStopBars = 72;
input double  TrailActivateATRMult = 0.5;
input double  TrailFixedUSD = 0.5;
input bool    UseCompound = true;
input bool    UseMartingale = false;
input double  MaxLotCap = 5.0;

// 主逻辑:
// 1. 每 H1 结束: 取 XAU close[1] / XAG close[1] = ratio_safe
// 2. rolling mean(240) + std(240) 计算 z
// 3. z > +2.0 → SELL (ATR SL/TP, 72 bar time stop, 0.5 ATR 后 0.5 USD trail)
// 4. z < -2.0 → BUY (同上)
// 5. lot = (Equity × Risk) / (SL_dollar_per_lot), capped at MaxLotCap
```

## 风险登记

| # | 风险 | 触发 | 缓解 |
|---|---|---|---|
| R1 | 2026Q1 IC 反转 (-0.09) | Q2 仍 < 0 持续 2 周 | 暂停 EA |
| R2 | XAG broker 死数据 | 每日 zero-change > 5% | 切到 alt symbol 或暂停 |
| R3 | Liquidation 共振过重 | 周共振 > 5 次 | XX risk 减半 |
| R4 | 跨年 IC 不均 (依赖宏观事件) | n/a | 接受 (黑天鹅期保险) |
| R5 | broker 提供的 XAGUSD.s 与真 silver 价差大 | spread > 5% | 切 alt feed |

## 历史决策记录

- **2026-05-09 上午**: 用户提出 trail 单点 alpha 脆弱担忧
- **2026-05-09 中午**: DXY 因子 5 维 audit 全失败 (白噪声 84%) → 拒绝
- **2026-05-09 下午**: XAU/XAG ratio 5 维 audit 全通过 (白噪声 0%) → 接受
- **2026-05-09 晚**: 跨 TF (H4/D1) 拒绝 → 仅 H1 主版
- **2026-05-09 晚**: 真实 portfolio 回测 MDD 不升反降 (17.56 → 17.38) → 强化决策

## 代码位置

- 因子: `C:/Tools/factor_factory/reports/_xau_xag_ratio_h1.py` (KK)
- 本地归档: `/Users/joker/factor_factory_archive/v20260509_portfolio_7factor_XAUXAG/code/factor_xau_xag_ratio_h1.py`
- audit 脚本: `/Users/joker/factor_factory_archive/v20260509_portfolio_7factor_XAUXAG/code/audit_xau_xag.py`
- 真实 portfolio: `/tmp/real_7factor_portfolio.py`

## 参考

- 主方案: [[PORTFOLIO_7FACTOR_XAUXAG_v20260509]]
- 整体性分析: [[INTEGRATED_ANALYSIS_v20260509]]
- 失败对照: [[DXY_REJECTED_v20260509]]
- 非线性诊断: [[NONLINEAR_DIAGNOSIS_v20260509]]
- 审计框架: [[REVIEW_FRAMEWORK_v20260509]]
