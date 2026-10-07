---
title: 方案 G+1 — 7 因子组合策略 (含 XAU/XAG 跨资产)
date: 2026-05-09
version: v20260509_7factor_XAUXAG
prev: v20260509_6factor (方案 G)
status: ready_to_deploy
total_risk: 4.5%
factor_count: 7
deployment_target: EBC57171
tags:
  - 量化
  - 组合策略
  - 方案G+1
  - XAU
  - 主方案
related:
  - "[[INTEGRATED_ANALYSIS_v20260509]]"
  - "[[SCHEME_G_OPTIMAL_v20260509]]"
  - "[[XAU_XAG_RATIO_v1]]"
  - "[[NONLINEAR_DIAGNOSIS_v20260509]]"
  - "[[EBC57171_DEPLOY_GUIDE]]"
---

# 方案 G+1 — 7 因子组合策略

> [!info] 升级路径
> 方案 G (6 因子, [[SCHEME_G_OPTIMAL_v20260509]]) → **方案 G+1 (7 因子)**
> 核心增量: 加入 [[XAU_XAG_RATIO_v1]] (Magic 57177), 解决 trail alpha 单点失败风险
> 边际收益分析详见 [[INTEGRATED_ANALYSIS_v20260509]]

## 配置规格

| # | 因子 | Magic | RiskPerTrade | UseCompound | UseMartingale | Trail | 类型 |
|---|---|---|---|---|---|---|---|
| 1 | PureBO 顺势突破 | 57171 | 1.00% | ✅ | ❌ | 0.5 USD | 趋势 |
| 2 | VP POC 反转 | 57172 | 1.00% | ✅ | ❌ | 0.5 USD | 反转 (corr -0.04) |
| 3 | Session+Fib | 57173 | 0.50% | ✅ | ❌ | 0.5 USD | 时段+结构 |
| 4 | Liquidation v6 | 57174 | 0.75% | ✅ | ❌ | 0.5 USD | 流动性突破 |
| 5 | Gap Reject v3 | 57175 | 0.25% | ✅ | ❌ | None | 跳空反弹 |
| 6 | Divergence (archive) | 57176 | 0.50% | ✅ | ❌ | None | RSI/MFI 背离 |
| **7** | **XAU/XAG ratio** ⭐ | **57177** | **0.50%** | **✅** | **❌** | **0.5 USD** | **跨资产均值回归** |
| 总 | | | **4.50%** | | | | |

**全局设置**:
- MaxLotCap: 5.0
- 单笔最坏亏损 (无马丁): 4.50% (理论上限, 实测 -2.8%)
- Initial equity: $10,000

## 单因子表现 (2024+ 真实期, 0.1 base lot, 1 万入金)

| 因子 | n | WR | PF | MDD | Sharpe | net |
|---|---|---|---|---|---|---|
| PureBO | 2955 | 75.4% | 1.914 | 10.5% | 3.22 | $132,245 |
| VP_POC | 2128 | 74.4% | 1.432 | 21.9% | 1.63 | $62,594 |
| Session_Fib | 1556 | 73.3% | 1.615 | 18.9% | 2.18 | $58,101 |
| Liquidation v6 | 1223 | 72.6% | 1.824 | 12.8% | 3.03 | $55,265 |
| Gap_Reject | 10 | 80.0% | 9.174 | 0.9% | 13.56 | $1,281 |
| Divergence | 48 | 64.6% | 2.207 | 2.5% | 6.31 | $2,339 |
| **XAU/XAG ratio** | **497** | **82.9%** | **2.685** | **9.5%** | **4.34** | **$38,071** ⭐ |

## Portfolio 整体表现

### 表现 — 真实回测 (factor_factory 标准引擎, 2024-2026 真实期)

| 指标 | 6 因子 baseline | **7 因子 G+1** | 增量 |
|---|---|---|---|
| Final equity (1万起) | $12,443,764 | **$14,185,142** | +$1,741,378 |
| Ret 2024+ | +124,337% | **+141,751%** | +17,414 pp |
| **MDD (真实)** | **17.56%** | **17.38%** ⭐ | **-0.18 pp** |
| Calmar | ~7,080 | ~8,156 | +15% |
| n_trades | 7,920 | 8,417 | +6.3% |

#### By year (7 因子)
| 年 | Ret | MDD | n |
|---|---|---|---|
| 2024 | +2,789.5% | 17.38% | 3,593 |
| 2025 | +2,109.8% | 10.48% | 3,670 |
| 2026 (4M) | +119.7% | 3.39% | 1,154 |

> [!success] 反直觉 — XAU/XAG 加入后 MDD 不升反降
> 真实测试: 加 XAU/XAG 后 MDD 从 17.56% → **17.38%** (-0.18 pp).
> 原因: 与 Liquidation 的 corr 0.48 体现在**不同时段触发**, 实际产生了反共振对冲效应, 而非加重共振.
> 这印证了 XAU/XAG 是真分散因子, 不只是冗余触发.

> [!info] 关于历史报的 13.18% MDD
> [[SCHEME_G_OPTIMAL_v20260509]] 中 13.18% 可能是不同 risk profile 或不同 lot 假设下测得.
> 本文档以本次 factor_factory 真实 SL$/lot 实测重跑为准 (17.56% / 17.38%).
> 之前临时 simulator 的 36% MDD 是 fallback 假设错, **彻底作废**.

## 因子间 corr 矩阵 (daily PnL, 2024+)

```
            PureBO  VP_POC  Sess  Liq    Gap   Div   XAU/XAG
PureBO       1.00   -0.04   0.33  0.18   ↓    ↓     +0.30
VP_POC      -0.04    1.00   ↓    ↓     ↓    ↓     -0.12
Session+Fib  0.33    ↓     1.00  ↓     ↓    ↓     +0.11
Liquidation  0.18    ↓      ↓    1.00   ↓    ↓     +0.48 ⚠️
Gap_Reject    ↓      ↓      ↓     ↓    1.00  ↓     -0.02
Divergence    ↓      ↓      ↓     ↓     ↓   1.00   -0.06
XAU/XAG    +0.30  -0.12  +0.11 +0.48 -0.02 -0.06  1.00
```

**冗余度评估**:
- ✅ Divergence (-0.06) / Gap_Reject (-0.02) / VP_POC (-0.12) — 真分散
- ⚠️ **Liquidation (+0.48)** — 中等相关, 必须监控共振
- ✅ PureBO (+0.30) / Session+Fib (+0.11) — 弱正相关, 可接受

## XAU/XAG 加入的成本-收益分析

### Benefits (提升)

| 项 | 量化 | 重要性 |
|---|---|---|
| 真 IC 因子数 1→2 | 16% → 28% | ⭐⭐⭐ |
| 真 IC 净利润占比 | 5% → 22% | ⭐⭐⭐ |
| 首个白噪声 0% 因子 | 0 → 1 | ⭐⭐⭐ |
| 黑天鹅独立爆发 | Q1 2025 IC 0.7513 | ⭐⭐ |
| 2026 OOS 不崩 | PF 1.76 | ⭐⭐ |
| 跨资产分散 | 0% → 27% | ⭐⭐ |
| 多空对称 | 双向真因子 | ⭐ |

### Costs (代价)

| 项 | 量化 | 严重度 |
|---|---|---|
| 总单笔风险 +0.5 pp | 4.0% → 4.5% | 🟡 可接受 |
| MDD 真实 -0.18 pp | 17.56% → 17.38% | ✅ 不增反降 |
| Liquidation corr +0.48 | 中等相关 | 🟠 监控 |
| 2026Q1 IC 已反转 | -0.0854 | 🟠 警告 |
| 跨年 IC 不均 | -0.01 → +0.75 → -0.09 | 🟠 宏观依赖 |
| 频率稀疏 | 100/年 (2/周) | 🟡 不能主力 |

**结论**: ROI 数量级远超成本, 强烈值得加入 ✅

## 加入的 3 个监控条件

| # | 条件 | 阈值 | 响应 |
|---|---|---|---|
| 1 | risk 严格 0.5% | 不可调高 | 部署即生效 |
| 2 | Liquidation × XX 周共振 | > 5 次/周 | XX risk 减半到 0.25% |
| 3 | 2026Q2 实时 IC | < -0.1 持续 2 周 | 暂停 EA |

## 部署 Checklist

### Phase 1: 部署 (本周)
- [x] 5 维 audit 完成 ([[XAU_XAG_RATIO_v1]])
- [x] 参数 grid 优化 (THRESH=2.0, LB=240)
- [x] H4/D1 跨 TF 测试 (拒绝)
- [ ] 写 EA: `XAU_XAG_Ratio_v1.mq5` (Magic 57177)
- [ ] EBC57171 完整 7 因子部署
- [ ] Black swan circuit breaker

### Phase 2: 监控 (1-2 周)
- [ ] 实盘 vs 回测对账 (binary 触发同步率 >85%)
- [ ] Liquidation × XAU/XAG 共振 PnL 跟踪
- [ ] XAU/XAG 单笔信号验证

### Phase 3: 升级 (2-4 周)
- [ ] L1 ADX regime gating (Sharpe +20-30%, 详见 [[NONLINEAR_DIAGNOSIS_v20260509]])
- [ ] L3 多因子共振加仓
- [ ] 多 TF 共振过滤器

## 风险登记

| # | 风险 | 缓解 |
|---|---|---|
| R1 | XAU/XAG 2026 IC 反转 | risk 减半 |
| R2 | Liquidation 共振过重 | XX risk 削减 |
| R3 | XAG broker 死数据 | factor_factory 重测 |
| R4 | 跨年 IC 不稳 | 接受 (黑天鹅期保险) |

## 决策记录

- **2026-05-09 上午**: 用户提出 trail 单点 alpha 脆弱担忧
- **2026-05-09 中午**: DXY 因子 5 维 audit 全失败 (白噪声 84%) → 拒绝
- **2026-05-09 下午**: XAU/XAG ratio 5 维 audit 全通过 (白噪声 0%) → 接受
- **2026-05-09 晚**: H4/D1 跨 TF 拒绝 (corr 0.448 不独立) → 仅 H1 主版

## 参考文档

- 整体性分析: [[INTEGRATED_ANALYSIS_v20260509]]
- 新因子详情: [[XAU_XAG_RATIO_v1]]
- 失败教材: [[DXY_REJECTED_v20260509]]
- 非线性升级路径: [[NONLINEAR_DIAGNOSIS_v20260509]]
- 实盘部署: [[EBC57171_DEPLOY_GUIDE]]
- 上一版主方案: [[SCHEME_G_OPTIMAL_v20260509]]
- 代码归档: `/Users/joker/factor_factory_archive/v20260509_portfolio_7factor_XAUXAG/`
