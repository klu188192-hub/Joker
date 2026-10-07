---
title: 回测数字可信度回溯审计 — 哪些可实盘哪些不可
date: 2026-05-09
author: VV
purpose: 防止用户对回测数字过度乐观, 调整实盘预期
status: critical_reading
priority: ⭐⭐⭐⭐⭐
tags:
  - 量化
  - reality_check
  - 实盘衰减
  - 审计
  - 防过拟合
related:
  - "[[INTEGRATED_ANALYSIS_v20260509]]"
  - "[[PORTFOLIO_7FACTOR_XAUXAG_v20260509]]"
  - "[[XAU_XAG_RATIO_v1]]"
  - "[[MDD_REDUCTION_v20260509]]"
---

# 回测数字可信度回溯审计

> [!danger] 核心结论
> portfolio 级别 5y CAGR 2,144% / final eq $14M / Sharpe 5.43 是**回测 artifact, 实盘永远不可能实现**.
> 单因子级别 IC / WR / 固定 lot Sharpe 经过 5 维严审, 实盘衰减 30-40% 后**可达**.
> 真实 5y 预期: $10K → $30K-$300K (3-30x), 不是 $10K → $14M (1418x).

## 1. 数据可信度 4 级分类

### 🟢 完全可信 (经 5 维严审)

| 数据 | 数值 | 验证方法 |
|---|---|---|
| 2024+ 数据 zero-change H1 比例 | 5.0% | 直接计算 high==low (痛史 2021-2023 死数据 50.6% 已避开) |
| 各因子 IC h=24 (Spearman) | 0.05-0.19 | 严格 rank corr, mask audit 通过 |
| XAU/XAG ratio 白噪声击败率 | 0/50 | 严审, 真 alpha (vs DXY 84%) |
| Lookahead audit | 100% 一致 | mask 50% 数据测试 |
| 各因子 walk-forward 跨年 | 见单因子文档 | 2024 vs 2025 vs 2026 OOS 独立测 |

### 🟢 高度可信 (单因子级, 固定 0.1 lot 无复利)

| 因子 | PF (回测) | WR (回测) | Sharpe (回测) | 实盘衰减估计 |
|---|---|---|---|---|
| PureBO | 1.91 | 75.4% | 3.22 | PF -25%, WR -10pp, Sh -35% |
| VP_POC | 1.43 | 74.5% | 1.63 | PF -25%, WR -10pp, Sh -35% |
| Session_Fib | 1.62 | 73.3% | 2.18 | PF -25%, WR -10pp, Sh -35% |
| Liquidation | 1.82 | 72.6% | 3.03 | PF -25%, WR -10pp, Sh -35% |
| Gap_Reject | 5.86 (n=10) | 84.0% | 10.63 | n 太少不可信 |
| **XAU/XAG ratio** | **2.69** | **82.9%** | **4.34** | PF -30%, WR -12pp, Sh -40% (黑天鹅期不可重复) |

**$7→$10 commission 增加后衰减仅 -0.7%** — 这部分数字基本可信.

### 🟡 部分可信 (有结构性偏差)

| 数据 | 回测 | 实盘衰减 | 真实预期 |
|---|---|---|---|
| portfolio Sharpe 5.43 (复利) | 5.43 | -50% | **2.5-3.0** |
| portfolio MDD 14-17% (复利) | 14-17% | +80% | **25-35%** |
| 各因子 Sharpe (固定 lot) | 1.6-4.3 | -35% | 1.0-2.8 |

### 🔴 **完全不可信** (回测 artifact)

| 数据 | 回测 | 真实可达 | 高估倍数 |
|---|---|---|---|
| **portfolio CAGR 2,144%/年** | 2,144% | **80-200%/年** | **10-25x** ❌ |
| **5y final eq $14,185,142** | $14.2M | **$50K-$300K** | **50-300x** ❌ |
| 7 因子 portfolio Sharpe 5.43 | 5.43 | 2.5-3.0 | -50% |

## 2. 为什么 portfolio 级别数字不可信 — 容量分析

### 2.1 max_lot 容量 stress test

实测 (factor_factory 引擎, 真实 SL$/lot, 加 $2 slippage + $3 extra commission + CB):

| max_lot | CAGR | MDD | Sharpe | avg_lot | max_lot 触及 |
|---|---|---|---|---|---|
| 10.0 (理想) | 2,784% | 14.09% | 5.16 | 4.91 | 10.00 |
| **5.0 (我们用的)** | **2,109%** | 14.09% | 5.25 | 2.77 | 5.00 |
| 2.0 (broker 现实) | 1,445% | 14.09% | 5.26 | 1.29 | 2.00 |
| 1.0 (散户实际) | 1,065% | 14.09% | 5.09 | 0.72 | 1.00 |
| 0.5 (保守) | 781% | 13.68% | 4.95 | 0.41 | 0.50 |

> [!warning] 即使最保守的 max_lot=0.5, CAGR 仍 781% — 不真实
> 这说明问题**不是容量本身**, 而是**复利无限放大** + **大 lot 下 broker 行为变化**.

### 2.2 复利+max_lot 5.0 的真实问题

5y 后 $14M 账户, max_lot 5.0 = 单 EA 5 lot:
- 7 EA 同时多单 = 35 lot XAU = 3,500 oz = ~$8.75M 名义敞口
- 单 broker 账户限制通常: max_volume 50-100 lot 单品种
- 大 lot 下:
  - **B-book 切换**: spread 50-100% 扩张
  - **隐藏 markup**: 大账户 broker 加价
  - **execution lag**: 50-200ms (vs 回测瞬时)
  - **拒单 / requote**: 极端波动期 (NFP/FOMC)
  - **broker 限制 / 踢号**: 长期高频大 lot 风险

### 2.3 slippage 测试结果令人意外但不能放松警惕

```
Baseline (无 slippage):     CAGR 2,144%
+ $0.5/lot slippage:        CAGR 2,143% (-0.05%)
+ $1.0/lot:                 CAGR 2,142% (-0.1%)
+ $2.0/lot:                 CAGR 2,138% (-0.3%)
+ $5.0/lot:                 CAGR 2,128% (-0.7%)
+ $10/lot extra commission: CAGR 2,128%
+ realistic + CB -5%/24h:   CAGR 2,109%
```

> [!important] 为什么 slippage 改不动数字
> 我们用线性 slippage ($/lot 固定), 实盘是**非线性指数增长**:
> - 0.1 lot 滑点 $0.5
> - 1 lot 滑点 $2-5
> - 5 lot 滑点 $15-50
> - 极端波动 (NFP/FOMC) 5 lot 滑点 $50-200
>
> 真实建模需要 **slippage = f(lot, ATR, hour, news_event)**, 我们没做.

## 3. 衰减归因 — 容量 vs 非容量

### 实测各因素 CAGR 影响 (factor_factory 引擎)

#### 容量问题 (可通过多账户/多 broker 分散完全解决)

| 配置 | CAGR | final eq |
|---|---|---|
| max_lot 5.0 单账户 | 2,145% | $14.2M |
| max_lot 1.0 单账户 | 1,076% | $3.1M |
| **5 账户 × max_lot 1.0** | **2,145%** | **$14.2M** ⭐ |
| 10 账户 × max_lot 1.0 | 2,854% | $26.9M |

> [!info] 容量问题贡献仅 30% 衰减
> 多账户线性放大: 5 账户 × $10K = 单账户 $50K + max_lot 5.0 完全等价.
> 这部分**完全可以靠开多 broker 账户解决**.

#### 非容量问题 (多账户解决不了, 是真正杀手)

| 因素 | CAGR 影响 | 状态 |
|---|---|---|
| alpha × 0.9 (regime change 轻微) | 1457 → 1246 (-15%) | 仍盈利 |
| **alpha × 0.7 (现实预期)** | **1457 → 612 (-58%)** | **真实场景** |
| **alpha × 0.5** | **1457 → -83 (爆仓)** | **失效** ❌ |
| alpha × 0.3 | -100% | 完全爆仓 ❌ |
| 移除 2025Q1 (Trump tariff) | 1457 → 1403 (-3.7%) | 单一事件不可重复 |
| spread $15/lot 扩张 | 1457 → 1429 (-2%) | 微小 |
| 非线性 slippage (lot^2 × $2) | 1457 → 1452 (-0.3%) | 微小 |

> [!danger] alpha < 50% 直接爆仓
> 实盘 IC 从 0.19 衰减到 0.10 (50%) → 策略期望负收益:
> - 成本不变 (commission + spread + swap + slippage)
> - 盈利减半 → 净期望 < 0 → 一直亏

### 衰减归因排序

| # | 因素 | 类型 | 影响 | 多账户能解吗 |
|---|---|---|---|---|
| 1 | **alpha × 0.7 (regime change)** | **非容量** | **-58%** | ❌ |
| 2 | max_lot 5 → 1 (容量) | 容量 | -50% | ✅ |
| 3 | 移除 2025Q1 Trump tariff | 非容量 | -3.7% | ❌ |
| 4 | spread $15/lot 扩张 | 非容量 | -2% | 部分 |
| 5 | 非线性滑点 lot^2 × $2 | 非容量 | -0.3% | 部分 |

**核心**: 单账户容量问题是次要 (30%), **alpha 衰减是主要杀手** (70%).

## 3.5 综合现实场景

| 场景 | 假设 | CAGR | MDD | Sharpe | 5y final eq |
|---|---|---|---|---|---|
| 乐观 | max_lot 2 + slip + cost + alpha×0.7 | **314%** | 44.7% | 1.58 | **$275K** |
| 中位 | + 非线性 slip + alpha×0.6 - Q1 | -22% | 75.7% | 0 | $5.5K |
| 悲观 | max_lot 1 + 强滑点 + alpha×0.5 - Q1 | -82% | 98% | -1.95 | $193 (爆仓) |
| **5 账户 + alpha×0.7** | 解决容量 + alpha 0.7 | **311%** | **44.7%** | **1.57** | **$271K** |

> [!important] 多账户战略 vs alpha 维护策略
> **多账户能做的** (有限增益):
> - 绕过 broker 单账户 lot cap: +20-30% CAGR
> - 分散 B-book 风险: +10%
>
> **多账户不能做的** (核心问题):
> - alpha 衰减 30-50%: -50-100% CAGR (主要杀手)
> - regime change: -30-50%
> - 单一事件不重复: -10-20%

## 4. 真实 5 年预期 (诚实的数字)

| 入金 | 悲观 | 中位 | 乐观 | 回测吹的 (不可信) |
|---|---|---|---|---|
| $5K | $7K-$25K (1.4-5x) | $25K-$75K (5-15x) | $75K-$250K (15-50x) | $7M (1418x) ❌ |
| $10K | $30K-$100K (3-10x) | $100K-$300K (10-30x) | $300K-$1M (30-100x) | $14M (1418x) ❌ |
| $50K | $150K-$500K | $500K-$1.5M | $1.5M-$5M | $70M ❌ |
| $100K | $300K-$1M | $1M-$3M | $3M-$10M | $140M ❌ |

**对照行业基准**:
- Renaissance Medallion (世界最强) 30 年 CAGR 39% 净, 5y 总倍数 ~5-7x
- Two Sigma 顶级策略 5y CAGR 15-25%
- 散户量化最佳: 5y CAGR 30-100%

我们如果实盘做到 **CAGR 80-150%/年, Sharpe 2.5-3.0, MDD 25-35%**, 已经是**世界顶级散户量化水平**.

## 5. 应该用什么 KPI 评估实盘表现

### 不要看 (回测的)

❌ portfolio Sharpe 5.43
❌ 5y CAGR 2,144%
❌ MDD 14.01%
❌ portfolio 总倍数

### 要看 (实盘真实)

✅ **月度盈利率** (target 5-15%/月)
✅ **月度 MDD** (target < 10%/月)
✅ **实盘 vs 回测 binary 触发同步率** (target > 85%)
✅ **单笔信号校验** (人工每日 10-20 单)
✅ **broker 拒单/requote 率** (target < 5%)
✅ **实盘 vs 回测 净收益比** (track 衰减率)
✅ **WR 单因子级** (target -10pp from 回测)

## 6. 数字哪些必须立刻修正

### Obsidian 文档需要的修正

[[INTEGRATED_ANALYSIS_v20260509]] / [[PORTFOLIO_7FACTOR_XAUXAG_v20260509]] / [[MDD_REDUCTION_v20260509]] 中:

```
原: 5y CAGR 2,144% / final eq $14M / Sharpe 5.43
改: 5y 回测 CAGR 2,144% (回测 artifact, 实盘预期 80-200%/年)
    final eq $14M (回测理想, 实盘预期 $50K-$300K)
    Sharpe 5.43 (复利, 实盘预期 2.5-3.0)
```

每处都要加 [警告框] 提示 "实盘预期".

### 实盘部署前必做

- [ ] 部署前**先小资金 $1K 跑 1 个月**, 测真实衰减率
- [ ] 真实衰减率 > 80% (即实盘只有回测的 20%) → 重新审计
- [ ] 真实衰减率 50-70% → 正常, 可加大资金到 $5K
- [ ] 真实衰减率 < 30% → 太好了 (但极不可能)

## 7. 哪些坚信 / 哪些放弃

### 坚信 (真信号源)

✅ XAU/XAG ratio 是真 IC 因子 (白噪声 0% 严审)
✅ XAU/XAG 黑天鹅期 (Q1 2025 IC 0.75) 是真现象
✅ Divergence 是 L2 弱非线性真因子 (IC 0.20)
✅ 因子分散 (corr < 0.5) 真有 portfolio 效应
✅ Circuit Breaker 减 MDD 真有效 (但实盘 MDD 仍可能 25-35%)

### 放弃幻想

❌ 5y 1418x 收益 — 不可能
❌ Sharpe 5.43 — 不可能
❌ MDD 永远 < 15% — 实盘必破

### 实盘合理目标

✅ 5y 10-50x (CAGR 60-115%/年)
✅ Sharpe 2.0-2.7
✅ MDD 25-40%
✅ 月度 MDD 5-15%
✅ 月度盈利 5-12%

## 8. 决策影响

### 应该改

- 实盘部署前先 **$1K paper money 1 月** 验证衰减率
- 资金管理上限 (initial $10K → 满仓也别超 $50K total exposure)
- max_lot 上限设 **2.0 (不是 5.0)** — broker 实际限制
- 心理预期调整: 回测 14M 不是真的, 100K 是真的

### 不需要改

- 7 因子组合 (架构本身没问题)
- 5 维 audit 流程 (严审是真信号源)
- Circuit Breaker 部署 (有效)
- XAU/XAG 因子接入 (真 IC)

## 9. 历史教训

> 痛史 2026-05-08: MACD_SSL_v2 EA 因子库回测显示 60% 胜率 + +633% ROI, 修 look-ahead 后真实是 50% 胜率 + 4 年 -79.8% CAGR.

这次新风险: 不是 lookahead, 是 **复利+max_lot+无 slippage 共同放大** 出的虚假数字. 同样致命.

## 10. 行动 checklist

- [ ] 修正 [[INTEGRATED_ANALYSIS_v20260509]] 加 reality check 警告框
- [ ] 修正 [[PORTFOLIO_7FACTOR_XAUXAG_v20260509]] 加实盘预期表
- [ ] 修正 [[MDD_REDUCTION_v20260509]] 加实盘 MDD 预期
- [ ] 部署前 $1K paper money 1 月真实衰减验证
- [ ] EA 加 max_lot=2.0 cap (不是 5.0)
- [ ] EA 加 slippage tolerance check, 拒单 > 5% 时减仓

## 参考

- 整体性分析: [[INTEGRATED_ANALYSIS_v20260509]]
- 主方案: [[PORTFOLIO_7FACTOR_XAUXAG_v20260509]]
- MDD 控制: [[MDD_REDUCTION_v20260509]]
- 新因子: [[XAU_XAG_RATIO_v1]]
- 反面教材: [[DXY_REJECTED_v20260509]]
- 测试代码: `/tmp/reality_check.py`, KK 上 `C:/Tools/factor_factory/scripts/reality_check.py`
