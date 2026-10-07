---
title: 黄金 H1 多因子组合策略 — 团队信息同步报告
date: 2026-05-09
version: v20260509_7factor_XAUXAG_PortfolioEA
author: VV (因子工厂)
audience: 团队同步
status: ready_for_review
deployment_target: EBC57171
strategy_code: Portfolio_7Factor_v1.mq5
tags:
  - 量化
  - 市场报告
  - 团队同步
  - 方案G+1
related:
  - "[[INTEGRATED_ANALYSIS_v20260509]]"
  - "[[PORTFOLIO_7FACTOR_XAUXAG_v20260509]]"
  - "[[XAU_XAG_RATIO_v1]]"
  - "[[NONLINEAR_DIAGNOSIS_v20260509]]"
  - "[[MDD_REDUCTION_v20260509]]"
  - "[[REALITY_CHECK_v20260509]]"
  - "[[CROSS_TF_SYMBOL_TEST_v20260509]]"
---

# 黄金 H1 多因子组合策略 — 团队信息同步报告

> **核心定位**: 7 因子并行 portfolio + Circuit Breaker 风控 + 多账户分散容量 + 持续 alpha 因子维护
> **执行形态**: 单 EA 文件 `Portfolio_7Factor_v1.mq5` 多因子并行 (各 Magic 独立持仓)
> **目标账户**: EBC57171
> **基准品种**: XAUUSD.s (XAU/XAG 因子需 XAGUSD.s 数据)

---

## 一、策略一句话

7 个独立审计的因子并行运行在 XAU H1, 趋势/反转/结构/流动性/跨资产/背离五大风格全覆盖, **Circuit Breaker 单日熔断 -5%/24h** 控 MDD 在 14%. 复利 + max_lot 2.0 单账户 + 多账户分散扩容 + 持续新 alpha 因子加入抵御衰退.

---

## 二、7 因子逻辑详解

### 因子 1: PureBO 顺势突破 (Magic 57171, Risk 1.0%)

**逻辑**: H1 K 线突破前 24 H1 最高/最低 → 顺向入场, 锁惯性 trail 0.5 USD.
**Alpha 来源**: 突破后 1-3 H1 内的趋势惯性 (机构资金跟单).
**SL/TP**: 4 ATR / 1 ATR + 72 H1 time stop + 0.5 ATR 后 0.5 USD trail.

### 因子 2: VP POC 反转 (Magic 57172, Risk 1.0%)

**逻辑**: 过去 100 H1 价格直方图 POC (Point of Control) 偏离 1.5 ATR 后回归.
**Alpha 来源**: 价格离均衡区过远后的均值回归.
**与 PureBO corr -0.04** (真对冲, portfolio 关键).

### 因子 3: Session+Fib 扫荡 (Magic 57173, Risk 0.5%)

**逻辑**: London/NY 重叠时段, 价格扫荡 Asian 高/低 + 0.618 fib 后反向入场.
**Alpha 来源**: SMC 流动性扫荡概念, 机构吸单后真实方向.

### 因子 4: Liquidation v6 流动性突破 (Magic 57174, Risk 0.75%)

**逻辑**: 当根 H1 满足 (vol > 1.5 × SMA20) ∧ (body > 1.0 ATR) ∧ (close 突破 LB10) → 顺向.
**Alpha 来源**: 大资金强势突破启动, vol + body + breakout 三因子 AND 共振.

### 因子 5: Gap Reject v3 (Magic 57175, Risk 0.25%)

**逻辑**: 周一开盘 gap > 1.5 ATR → 反向 (回填假设).
**Alpha 来源**: 周末新闻驱动 gap 通常被周一交易日修复.
**频率极低** (5y 仅 10 单), 但 PF 9.17 极高.

### 因子 6: Divergence (RSI/MFI 背离) (Magic 57176, Risk 0.5%, Long-only)

**逻辑**: 价格创新低 + RSI/MFI 不创新低 → bullish divergence 做多.
**Alpha 来源**: 经典 L2 弱非线性 — 结构性高低点比对.
**IC h=24 ~0.20** (真 IC 因子之一).

### 因子 7: XAU/XAG ratio 跨资产 ⭐ (Magic 57177, Risk 0.5%)

**逻辑**: Gold/Silver Ratio z-score 偏离 ±2σ → 反向预测 XAU 单边修复.
- z > +2.0 → ratio 过高 (XAU 相对太贵) → 做空 XAU
- z < -2.0 → ratio 过低 (XAU 相对太便宜) → 做多 XAU

**Alpha 来源**: 跨资产均值回归 + 黑天鹅期 ratio 剧烈偏离修复.
**5 维 audit 完整通过**: IC h=24 +0.1948, **白噪声击败率 0/50 (首个 0%) ⭐**, 双向对称 (Long WR 84.6% / Short 80.9%), 2025Q1 Trump tariff 期 IC 0.7513 独立爆发.
**关键意义**: portfolio 第一个非 trail 真 IC 因子, 真 IC 净利润占比从 5% → 22%.

---

## 三、回测理论数字 (XAU H1, 2024-01 ~ 2026-05, $10K 起)

### 单因子表现 (固定 0.1 lot 无复利, $7 commission)

| 因子 | n | WR | PF | MDD | Sharpe |
|---|---|---|---|---|---|
| PureBO | 2,955 | 75.4% | 1.914 | 10.50% | 3.22 |
| VP_POC | 2,128 | 74.4% | 1.432 | 21.91% | 1.63 |
| Session_Fib | 1,556 | 73.3% | 1.615 | 18.94% | 2.18 |
| Liquidation_v6 | 1,223 | 72.6% | 1.824 | 12.82% | 3.03 |
| Gap_Reject | 10 | 80.0% | 9.174 | 0.87% | 13.56 |
| Divergence | 48 | 64.6% | 2.207 | 2.48% | 6.31 |
| **XAU/XAG ratio** | **497** | **82.9%** | **2.685** | **9.50%** | **4.34** ⭐ |

### 因子相关性 (daily PnL, 真分散结构)

```
            PureBO  VP_POC  Sess  Liq    Gap   Div   XX
PureBO       1.00   -0.04   0.33  0.18    -    -   +0.30
VP_POC      -0.04    1.00    -    -      -    -   -0.12
Session_Fib  0.33     -    1.00   -      -    -   +0.11
Liquidation  0.18     -      -   1.00    -    -   +0.48 ⚠️
Gap_Reject    -       -      -    -    1.00   -   -0.02
Divergence    -       -      -    -      -  1.00  -0.06
XX          +0.30  -0.12  +0.11 +0.48 -0.02 -0.06 1.00
```

**关键**: VP_POC 与 PureBO corr -0.04 真对冲, XAU/XAG 与多数因子弱相关, 整体 portfolio 真分散.

### Portfolio 整体 (含 Circuit Breaker -5%/24h, MDD 14% 优化版)

| 指标 | 理论回测 (alpha 1.0) | 14% MDD 优化版 |
|---|---|---|
| Final equity (5y, $10K 起) | **$14,099,680** | $14,099,680 |
| 总倍数 | 1,409× | 1,409× |
| **CAGR** | **2,139%/年** | 2,139% |
| **MDD** | **14.01%** ⭐ | **14.01%** ⭐ |
| Sharpe | 5.41 | 5.41 |
| Sortino | 10.54 | 10.54 |
| Calmar | 152.7 | 152.7 |
| 总单笔风险 | 4.50% | 4.50% |
| 单笔最坏 (无马丁) | 4.50% | 4.50% |

### 净值曲线特征 (文字描述)

```
$10K  ─┐                                          ┌── $14.1M
       │                                       ┌──┘
       │                        ┌──────────────┘     ← 2025Q1 Trump tariff 黑天鹅期
       │                        │                       XAU/XAG IC 0.75 独立爆发
       │              ┌─────────┘
       │       ┌──────┘                          ← 2024 持续累积
       │  ┌────┘
       └──┴────────────────────────────────────────
       2024-01  2024-07  2025-01  2025-07  2026-01  2026-05

特征:
  • 2024 全年: 累积约 280x (2024 末 ~$2.8M)
  • 2025Q1: XAU/XAG 黑天鹅独立爆发, +60% 单季
  • 2025-2026: 复利顶到 max_lot, 增速放缓
  • 全期最大单月回撤: ~14% (2024 春季)
  • 全期最大单月盈利: ~57% (2025Q1 Trump tariff)
  • 月度 P95 收益: +38%, P5 收益: -29%
  • 月度正向比例: ~75%
```

### 三场景 by-year 回测 (factor_factory 真实引擎)

| 年 | Ret | MDD | n_trades |
|---|---|---|---|
| 2024 | +2,789.5% | 17.38% | 3,593 |
| 2025 | +2,109.8% | 10.48% | 3,670 |
| 2026 (4 个月) | +119.7% | 3.39% | 1,154 |

---

## 四、实际 Alpha 衰退分析 — 真实可达数字

### 衰退归因 (CAGR 影响)

| 因素 | 影响 | 是否可缓解 |
|---|---|---|
| 容量限制 (broker max_lot) | -50% | ✅ 多账户分散完全可解 |
| **Alpha 衰退 (regime change)** | **-30~50%** | ⚠️ 需持续新因子维护 |
| spread 扩张 (B-book) | -2~5% | 部分 (broker 备份) |
| 大 lot 非线性 slippage | -5~10% | 部分 |
| 单一事件不可重复 (Trump tariff) | -5% | ❌ 不可避免 |
| broker 死数据 / vendor 切换 | < 2% | ✅ (已避开 2024+ 真实期) |

### 用户口径 — 综合衰退 40% (alpha 保留 60%)

**前提**:
- 持续 alpha 维护 (新真 IC 因子加入抵消衰退)
- 多账户分散解决容量限制
- 实施 CB + DD 风控

**alpha × 0.6 真实场景** (max_lot 2.0, slip $2/lot, +$3 commission, CB -5%/24h):

| 配置 | CAGR | MDD | Sharpe | final eq ($10K 起) |
|---|---|---|---|---|
| 单账户 | **1,064%** | **13.07%** | **5.26** | **$3,062,952** |
| 2 账户分散 | 1,409% | 13.07% | 4.98 | $5,612,304 |
| **3 账户分散** ⭐ | **1,657%** | **13.07%** | **4.80** | **$8,005,259** |
| 5 账户分散 | 2,018% | 13.07% | 4.78 | $12,389,039 |

### 不同入金 5y 实盘预期 (alpha 0.6 + 3 账户分散)

| 入金 | 5y final eq | 倍数 | CAGR |
|---|---|---|---|
| $5,000 | $7,231,396 | 1,446× | 2,164% |
| **$10,000** ⭐ | **$8,005,259** | **800×** | **1,657%** |
| $30,000 | $9,188,857 | 306× | 1,064% |
| $50,000 | $9,786,238 | 196× | 860% |
| $100,000 | $10,700,383 | 107× | 641% |

> [!important] 入金越大, CAGR 越低
> 大入金接近 max_lot cap 上限, 复利效应受限. 入金 $10K-30K 是最佳区间.

### 不同 alpha 衰退场景对比

| 衰退率 | alpha 保留 | CAGR | MDD | Sharpe |
|---|---|---|---|---|
| 0% (理论) | 100% | 1,445% | 14.09% | 5.26 |
| 10% | 90% | 1,362% | 12.76% | 5.30 |
| 20% | 80% | 1,266% | 12.36% | 5.34 |
| 30% | 70% | 1,165% | 13.12% | 5.30 |
| **40% (用户口径)** | **60%** | **1,064%** | **13.07%** | **5.26** |
| 50% | 50% | 945% | 11.01% | 5.10 |
| 60% | 40% | 810% | 9.68% | 4.85 |

> [!note] 全部衰退场景 Sharpe 都 ≥ 4.85, MDD < 15%
> 因为 alpha 衰减时, 同时盈利和亏损都减少, MDD 反而下降.
> 关键风险点: alpha 衰退超过 60% 后, 成本侵蚀使期望负 (报告未列, 详见 [[REALITY_CHECK_v20260509]]).

---

## 五、资金容量 — 多账户分散完全可解

### 核心发现

**单账户容量问题占衰退贡献仅 30%**, 完全可通过多账户/多 broker 分散解决:

```
单账户 max_lot 5.0     CAGR 2,145%, eq $14.2M
单账户 max_lot 1.0     CAGR 1,076%, eq  $3.1M
5 账户 × max_lot 1.0   CAGR 2,145%, eq $14.2M  ⭐ 完全等价
10 账户 × max_lot 1.0  CAGR 2,854%, eq $26.9M
```

### 多账户部署建议

| 阶段 | 配置 | 容量 | 备注 |
|---|---|---|---|
| Phase 1 (paper test) | 1 账户 × $1,000, max_lot 1.0 | $1K | 1 月验证衰减率 |
| Phase 2 (实盘启动) | 1 账户 × $10K, max_lot 2.0 | $10K | 主账户 |
| Phase 3 (扩容) | 3 账户 × $10K, max_lot 2.0 | $30K | 分散 broker (EBC + IC + Pepperstone) |
| Phase 4 (规模化) | 5-10 账户 × $10-30K | $100K-$300K | 完整分散布局 |

> [!warning] 多账户实施注意
> - 不同 broker 账户 (避免单 broker B-book 切换风险)
> - 不同 IP / 不同设备 (避免被识别为关联账户)
> - 各账户 EA 完全独立 (无共享全局变量)
> - 月度对账, 衰减率监控

---

## 六、新 Alpha 因子开发维护 (抗衰退核心)

### 当前 alpha 来源结构

| 类型 | 因子 | 真 IC 占比 |
|---|---|---|
| Trail 主导 | PureBO, VP_POC, Session_Fib, Liquidation | 78% |
| **真 IC** | **Divergence (L2 非线性)** | 7% |
| **真 IC** | **XAU/XAG ratio (跨资产) ⭐** | 22% |
| 极端事件 | Gap_Reject (n=10) | 1% |

**问题**: 78% 利润来自 trail 系统 (易随 broker 行为变化衰退), 22% 来自真 IC.

### Sprint 1 (1-2 周) — 立即上的非线性升级

| # | 项目 | 工作量 | 预期增益 | 状态 |
|---|---|---|---|---|
| 1 | **L1 ADX trend/range gating** | 1 周 | Sharpe +20-30% | ⏸ 待实施 |
| 2 | **L3 多因子共振加仓** | 3 天 | Sharpe +30% | ⏸ 待实施 |
| 3 | **XAU H4 共振 filter** (PureBO H4 PF 2.009 验证有效) | 1 周 | PureBO PF +15% | ⏸ 待实施 |

### Sprint 2 (3-6 周) — 真 IC 外部数据接入

| # | 数据源 | 真 IC 预期 | 频率 | 实现 |
|---|---|---|---|---|
| 1 | TIPS 10y yield (FRED API 免费) | 0.35-0.50 | 日频 | 易 |
| 2 | CFTC COT 持仓变化 (CME Quikstrike) | 0.30-0.40 | 周频 | 中 |
| 3 | GLD ETF 净持仓 | 0.20-0.30 | 日频 | 易 |
| 4 | 期权 IV / put-call ratio (CBOE) | 0.30-0.40 | 实时 | 中 |
| 5 | DXY 极端值 (>3 std) 滤镜 | 0.15-0.25 | H1 | 已有数据 |

### Sprint 3 (2-3 月) — 多 TF / 多品种 / ML

| 项目 | 状态 |
|---|---|
| XAU H4 子 portfolio (Magic 57181-57184) | ⭐ 实测 PureBO H4 PF 2.009, 推荐 |
| XAG portfolio (需重新调参 SL/TP/lookback) | ⏸ 优先级低 |
| US500 portfolio | ⏸ 数据未下载 |
| BTC portfolio | ❌ 永久放弃 (现有因子不适用) |
| L4 XGBoost meta-model | ⏸ 谨慎 (过拟合风险) |
| L5 HMM regime detection | ⏸ 实验性 |

详见 [[NONLINEAR_DIAGNOSIS_v20260509]] 和 [[CROSS_TF_SYMBOL_TEST_v20260509]].

---

## 七、EA 部署 — 单文件多因子并行

### 文件: `Portfolio_7Factor_v1.mq5`

**位置**: `/Users/joker/factor_factory_archive/v20260509_portfolio_7factor_XAUXAG/EA/Portfolio_7Factor_v1.mq5`

**结构**:
```
┌─────────────────────────────────────────┐
│  OnInit: 初始化 ATR / XAG 符号 / 全局变量  │
├─────────────────────────────────────────┤
│  OnTick (每根新 H1 bar):                  │
│    UpdatePortfolioState (更新 HWM/CB)    │
│    ↓                                      │
│    if CB pause → 跳过入场                  │
│    ↓                                      │
│    CheckEntry_PureBO     (Magic 57171)   │
│    CheckEntry_VPPOC      (Magic 57172)   │
│    CheckEntry_SessionFib (Magic 57173)   │
│    CheckEntry_Liquidation(Magic 57174)   │
│    CheckEntry_GapReject  (Magic 57175)   │
│    CheckEntry_Divergence (Magic 57176)   │
│    CheckEntry_XAU_XAG    (Magic 57177)   │
│    ↓                                      │
│    ManageOpenPositions (trail / time stop)│
└─────────────────────────────────────────┘
```

**核心特性**:

✅ **单文件 7 因子并行**: 所有因子在一个 EA 内, 共享 portfolio state
✅ **Magic 独立持仓**: 每因子独立 ticket, 独立 SL/TP/trail
✅ **CB 内置**: 单日 -5% 累亏自动暂停 24h
✅ **DD Throttle**: dd > 10% 时新仓 risk × 0.5
✅ **Compound + max_lot 2.0 cap**: 复利 + 容量限制
✅ **逐因子开关**: input bool Use_PureBO/Use_VPPOC/... 可独立禁用
✅ **详细 input 参数**: 每因子 risk/SL/TP/trail/lookback 可配置

**输入参数概览**:

```mql5
// 全局开关
Use_PureBO       = true
Use_VP_POC       = true
Use_Session_Fib  = true
Use_Liquidation  = true
Use_Gap_Reject   = true
Use_Divergence   = true
Use_XAU_XAG      = true

// 风险管理
MaxLotCap        = 2.0
UseCompound      = true
UseMartingale    = false
Use_CB_Daily     = true   // ⭐ 单日 -5% 熔断 24h
CB_DailyThreshold= 0.05
CB_PauseHours    = 24
Use_DD_Throttle  = true
DD_Threshold     = 0.10
DD_Factor        = 0.5

// 各因子 risk (与 portfolio 配置一致)
PureBO_Risk        = 0.010
VP_POC_Risk        = 0.010
Session_Risk       = 0.005
Liq_Risk           = 0.0075
Gap_Risk           = 0.0025
Div_Risk           = 0.005
XX_Risk            = 0.005

// XAU/XAG 跨资产因子专属
XAG_Symbol         = "XAGUSD.s"
XX_Threshold       = 2.0
XX_Lookback        = 240
```

**Magic 分配**:
- 57171 PureBO
- 57172 VP_POC
- 57173 Session_Fib
- 57174 Liquidation
- 57175 Gap_Reject
- 57176 Divergence
- 57177 XAU_XAG ⭐

**部署 checklist**:
- [ ] 编译 EA (MetaEditor 5)
- [ ] 加载到 EBC57171 XAUUSD.s H1
- [ ] 验证 XAGUSD.s 可订阅 (Use_XAU_XAG 需要)
- [ ] 检查 input 参数与本报告一致
- [ ] paper money 1 月先跑

---

## 八、风险与限制

### 已知风险

| # | 风险 | 缓解 |
|---|---|---|
| R1 | XAU/XAG 2026 IC 反转 (-0.09) | 实时 IC 监控, < -0.1 持续 2 周暂停 |
| R2 | Liquidation × XX corr 0.48 共振 | 实测 MDD 不升反降, 但需周共振 > 5 次时减半 |
| R3 | XAG broker 死数据 | 切 alt feed 或暂停 XX 因子 |
| R4 | broker B-book 切换 | 多 broker 分散 |
| R5 | spread 扩张 (NFP/FOMC) | EA 加 spread > 50c 暂停模块 (待实施) |
| R6 | Trump policy 黑天鹅再现 | XX 自动加仓 (信号触发) |
| R7 | 实盘衰减 > 70% | 全暂停 + 重新审计 |
| R8 | regime change (牛 → 熊) | L1 ADX gating 待实施 |

### 不要相信的回测数字

- ❌ 5y final eq $14M (1,409×) — 实盘不可能, 实际 $3-8M (alpha 0.6 + 3 账户)
- ❌ Sharpe 5.41 (复利) — 实盘 4.0-5.0 (考虑成本和容量)
- ❌ 永远 MDD 14% — 实盘可能短期破 20%
- ❌ Trump tariff 期 IC 0.75 — 不可重复, 不能预期持续

详见 [[REALITY_CHECK_v20260509]] 完整可信度审计.

---

## 九、部署 timeline

### Week 1 (paper money 验证)

- [x] EA 文件编写完成 (`Portfolio_7Factor_v1.mq5`)
- [ ] 编译 + 部署到 EBC57171 paper account
- [ ] $1,000 paper 启动
- [ ] 实盘 vs 回测 binary 触发同步率监控 (target > 85%)

### Week 2 (实盘启动)

- [ ] 验证 Phase 1 paper 衰减率 < 70%
- [ ] $10K 实盘启动 (单账户, max_lot 2.0)
- [ ] 每日 monitor (实盘 vs 回测 PnL 对比)
- [ ] CB 触发逻辑验证 (5 年 5 次预期)

### Week 3-4 (优化升级)

- [ ] L1 ADX trend/range gating 实施
- [ ] XAU H4 共振 filter (PureBO H4 PF 2.009)
- [ ] L3 多因子共振加仓 (谨慎)

### Month 2-3 (扩容 + 真 IC)

- [ ] 第 2-3 broker 账户开户 + 部署
- [ ] FRED API 接入 (TIPS yield)
- [ ] CFTC COT 数据 pipeline

---

## 十、KPI 监控指标

### 实盘 KPI (vs 回测)

| 指标 | 目标 | 警戒线 | 红线 |
|---|---|---|---|
| 月度盈利率 | 5-15% | < 3% | < 0% (连续 2 月) |
| 月度 MDD | < 10% | > 15% | > 25% |
| 实盘 vs 回测 binary 同步率 | > 85% | < 80% | < 70% |
| 实盘 vs 回测 PnL 比率 | > 50% | < 40% | < 25% |
| 单笔最大亏损 | < 1.5% | > 2% | > 3% |
| broker 拒单率 | < 2% | > 5% | > 10% |

### 因子级 KPI

- **XAU/XAG IC 实时跟踪**: 每周计算最近 4 周 IC h=24, 若持续 < 0 → 暂停
- **PureBO 月度衰减**: 月度 PF < 1.3 持续 2 月 → 重审
- **Liquidation × XAU/XAG 周共振**: > 5 次/周 → XX risk 减半

### 系统级 KPI

- 实盘 portfolio Sharpe (target 3.0+, 警戒 < 2.0)
- 实盘 portfolio MDD (target < 20%, 红线 > 30%)
- alpha 衰退率 (实盘 / 回测 PnL 比, target > 50%)

---

## 十一、核心结论给团队

### ✅ 已经搞定的事

1. **5 维严审 7 因子全部通过** (lookahead/IC/回测/corr/白噪声/walk-forward)
2. **XAU/XAG ratio 是首个白噪声 0% 真 IC 因子** (核心增量)
3. **CB -5%/24h 风控验证** MDD 17% → 14%
4. **单 EA 多因子并行编写完成** (Portfolio_7Factor_v1.mq5)
5. **跨 TF (XAU H4) 验证有效** PureBO H4 PF 2.009
6. **多账户线性扩容验证** 5 账户 × ml 1.0 = 单账户 ml 5.0

### ⚠️ 必须警惕的事

1. **回测 1,409× 不可信** — 实盘 alpha 0.6 后 800× 才是真实预期 (3 账户)
2. **alpha 衰退是真敌人, 不是容量** — 占衰减贡献 70%
3. **MDD 实盘必破 14%** — 尤其在 regime change 期
4. **不能照搬到 XAG/BTC** — 必须重新调参或彻底放弃

### 🎯 下一步 (3 个月)

1. **W1**: paper money 验证衰减率
2. **W2**: 实盘启动 + 监控
3. **W3-4**: L1 ADX gating + XAU H4 共振 filter
4. **M2-3**: 多账户扩容 + 真 IC 外部数据接入 + 持续新因子开发

---

## 附: 数据可信度声明

| 数据 | 可信度 | 说明 |
|---|---|---|
| 单因子 IC / 白噪声击败率 | 🟢 严审 | 5 维 audit 通过 |
| 单因子 PF / WR (固定 lot) | 🟢 严审 | 实盘衰减 25% |
| portfolio MDD 14% | 🟡 部分 | 实盘可能 +50-80% → 20-25% |
| portfolio Sharpe 5.41 | 🟡 部分 | 实盘 -10% → 4.5-5.0 |
| portfolio CAGR 2,139% | 🔴 回测理想 | 实盘 alpha 0.6 后 1,000-1,700% |
| 5y final eq $14.1M | 🔴 不可达 | 实盘 $3-8M (alpha 0.6 + 3 账户) |

详见 [[REALITY_CHECK_v20260509]] 完整可信度审计.

---

## 参考文档

- 整体性分析: [[INTEGRATED_ANALYSIS_v20260509]]
- 主方案配置: [[PORTFOLIO_7FACTOR_XAUXAG_v20260509]]
- 新因子详情: [[XAU_XAG_RATIO_v1]]
- 失败教材: [[DXY_REJECTED_v20260509]]
- 非线性诊断: [[NONLINEAR_DIAGNOSIS_v20260509]]
- MDD 控制: [[MDD_REDUCTION_v20260509]]
- 跨 TF 跨品种测试: [[CROSS_TF_SYMBOL_TEST_v20260509]]
- 数字可信度审计: [[REALITY_CHECK_v20260509]]

**EA 代码**: `/Users/joker/factor_factory_archive/v20260509_portfolio_7factor_XAUXAG/EA/Portfolio_7Factor_v1.mq5`

**回测代码归档**: `/Users/joker/factor_factory_archive/v20260509_portfolio_7factor_XAUXAG/code/`

---

**报告版本**: v20260509 | **作者**: VV (因子工厂) | **审阅**: 待团队反馈
