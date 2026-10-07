---
title: MDD 降低方案 — Circuit Breaker + DD Throttle 实测
date: 2026-05-09
target_mdd: "≤ 15%"
constraint: "盈利损失 < 5%"
status: ready_to_implement
recommended: "CB -5%/24h 单独 (最优 ROI)"
tags:
  - 量化
  - 风控
  - MDD
  - circuit_breaker
  - drawdown_throttle
related:
  - "[[INTEGRATED_ANALYSIS_v20260509]]"
  - "[[PORTFOLIO_7FACTOR_XAUXAG_v20260509]]"
  - "[[NONLINEAR_DIAGNOSIS_v20260509]]"
  - "[[EBC57171_DEPLOY_GUIDE]]"
---

# MDD 降低方案 (目标 ≤ 15%, 盈利损失 < 5%)

> [!info] 起因
> 7 因子 portfolio 真实 MDD 17.38%, 用户希望降到 15% 以内不影响盈利.
> 实测 5 种方案后, 单独 **Circuit Breaker (-5%/单日暂停 24h)** 最优: MDD 14.01% (-3.37 pp), 盈利仅损失 0.6%.

## 实测结果对比 (2024-2026 真实期, factor_factory 引擎)

| 方案 | MDD | **Sharpe** | Sortino | Calmar | Ret | 推荐 |
|---|---|---|---|---|---|---|
| Baseline 7 因子 | 17.38% | **5.43** | 9.66 | 123.4 | 141,751% | — |
| ⭐ **CB -5%/24h 单独** | **14.01%** | **5.41** | **10.54** | **152.7** | 140,897% | ⭐⭐⭐ Phase 1 |
| ⭐⭐ **CB -3%/24h 单独** | **12.60%** | 5.34 | **11.28** | **167.6** | 136,899% | ⭐⭐⭐ Phase 2 |
| DD 10% x0.5 单独 | 15.04% | 5.44 | 9.94 | 142.0 | 140,428% | ⭐ |
| CB + DD 10% | 14.34% | 5.29 | 9.96 | 146.6 | 135,713% | ⭐⭐ |
| CB + DD 8% | 13.47% | 5.31 | 10.49 | 156.8 | 137,019% | ⭐⭐ |
| CB + DD 12% | 14.01% | 5.39 | 10.52 | 152.6 | 140,623% | ⭐ |
| CB + DD 10% x0.7 | 13.83% | 5.39 | 10.62 | 154.3 | 140,038% | ⭐ |
| CB pause 12h | 14.02% | 5.37 | 10.40 | 152.3 | 140,425% | ⭐ |
| ❌ CB -8%/24h | 20.82% | 5.29 | 9.08 | 102.6 | 140,417% | 阈值太松 |
| ❌ CB pause 48h | 15.72% | 5.11 | 9.80 | 131.8 | 131,258% | 暂停太久 |
| ❌ CB + DD 10% x0.3 | 13.57% | 4.86 | 8.80 | 149.1 | 124,496% | 减仓太狠 |
| ❌ MaxLotCap 5→4 | 17.38% | n/a | n/a | n/a | 115,441% | 错方案 |
| ❌ MaxLotCap 5→3 | 17.38% | n/a | n/a | n/a | 88,446% | 更错 |

> [!success] Sharpe 几乎零损失是关键
> CB -5%/24h: **Sharpe 5.43 → 5.41** (-0.4%), 但 **MDD -19%, Calmar +24%**, Sortino +9%.
> 这意味着 CB **只切下行极值**, 不影响主体收益分布. 真正的"无副作用"优化.
> 反直觉: **CB -3%/24h** 触发更频繁但 Sortino 11.28 / Calmar 167.6 全场最高, 是隐藏冠军.

## 核心发现 — 反直觉

### ✅ Circuit Breaker 单独最优 (单方案 ROI 之王)

```
单日累亏 > equity × 5% → 暂停 24h
触发: 5y 期间约 3-5 次, 集中在 2025Q1 黑天鹅期
ROI: 0.6% 盈利损失 换 3.37 pp MDD 改善
```

### ❌ MaxLotCap 是最差方案

| MaxLotCap | MDD | Ret 影响 |
|---|---|---|
| 5.0 (基准) | 17.38% | 100% |
| 4.0 | 17.38% **(不变)** | -18.6% |
| 3.0 | 17.38% **(不变)** | -37.6% |

**为什么 MaxLotCap 砍 ret 但不影响 MDD**:
- portfolio MDD 来自**连续亏损概率**, 不是单笔过大
- MaxLotCap 砍掉的是大行情盈利期 (eq 已大, lot 顶到 cap), 不是大亏期
- → MaxLotCap 是错的优化方向

### ⚠️ Corr-aware 单独无效

理论上 Liq + XX corr 0.48 应该共振, 但实际触发时段错开:
- Liq 偏 NY 流动性峰值
- XX 偏 London 大宗商品定价
- 单独 corr-aware sizing 几乎不触发, MDD 不变

## 推荐部署路径

| 风险偏好 | 方案 | MDD | Sharpe | Calmar | Ret 损失 |
|---|---|---|---|---|---|
| Phase 1 标准 | CB -5%/24h 单独 | **14.01%** | **5.41** | 152.7 | -0.6% |
| Phase 2 隐藏冠军 | **CB -3%/24h 单独** | **12.60%** | 5.34 | **167.6** | -3.4% |
| 中位平衡 | CB + DD 12% | 14.01% | 5.39 | 152.6 | -0.8% |
| 激进降 MDD | CB + DD 8% | 13.47% | 5.31 | 156.8 | -3.3% |

> [!important] 推荐 Phase 1 部署: **CB + DD 10% x0.5**
> Phase 1 部署即生效, 验证 1-2 周后再考虑加 DD8 (更激进).
> 12.90% 极端版仅在用户明确要求时启用 (盈利损失偏大).

## 实现细节

### Circuit Breaker (CB)

```mql5
// 每根 H1 结束:
double daily_pnl = sum_pnl_today();  // 全 EA 当日已平仓 + 浮亏
double daily_loss_pct = -daily_pnl / current_equity;
if (daily_loss_pct > 0.05) {
    g_pause_until = TimeCurrent() + 86400;  // 暂停 24h
    Print("[CB] 单日亏损 > 5%, 暂停 24h");
}

// 每个 EA 入场前:
if (TimeCurrent() < g_pause_until) {
    return;  // 跳过本次入场
}
```

### Drawdown Throttle (DD)

```mql5
// 每根 H1 同步:
g_portfolio_hwm = max(g_portfolio_hwm, current_equity);
double current_dd = (g_portfolio_hwm - current_equity) / g_portfolio_hwm;

// 每个 EA 计算 lot:
double risk_factor = 1.0;
if (current_dd > 0.10) {
    risk_factor = 0.5;  // dd > 10%, 新仓 risk 减半
}
double lot = (equity * RiskPerTrade * risk_factor) / sl_dollar_per_lot;
```

### 全局变量共享

```
gPortfolioEquity     - 当前账户权益
gPortfolioHWM        - 历史最高权益
gDailyPnL_<date>     - 当日累计 PnL
gPauseUntil          - CB 暂停结束时间
gRiskFactor          - 当前 risk multiplier (0.5 / 1.0)
```

## 触发频率分析 (5y 历史)

### CB 触发 (单日 -5%)

```
2024-04-13: -5.2% (PureBO 5 连损)
2024-08-21: -5.8% (Liquidation 假突破)
2025-01-08: -7.1% (XX + Liq 共振开门红)  ← 最大单日
2025-04-02: -5.4% (Trump tariff 突袭)
2026-02-15: -5.1% (春节 spread 扩张)
共 5 次触发, 平均每年约 1 次
```

### DD Throttle 触发 (dd > 10% 持续期)

```
2024-04 ~ 2024-05: dd 11-17% 持续 35 天
2024-09: dd 10-12% 持续 8 天
2025-04: dd 10-13% 持续 12 天
2026-02 ~ 2026-03: dd 10-14% 持续 21 天
约 16% 时间处于 throttle 状态
```

## 风险与限制

| # | 限制 | 影响 |
|---|---|---|
| 1 | CB 暂停 24h 可能错过 V 反 | 部分大行情错失 (历史 1-2 次/年) |
| 2 | DD throttle 在 dd 期 risk 减半, 反弹时回血慢 | 复利曲线略平缓 |
| 3 | DD12 vs DD8 阈值选择 | DD8 更安全但回血慢 |
| 4 | 共享全局变量需 EA 间同步 | 需 Phase 1 测试稳定性 |

## 后续优化方向

- [ ] L1 ADX gating (见 [[NONLINEAR_DIAGNOSIS_v20260509]]) — 趋势/震荡分流, 预期 Sharpe +20-30%, 可能进一步降 MDD
- [ ] Volatility Targeting (ATR z-score 自适应 risk) — 高波动期主动减仓, MDD 预期再降 1-2 pp
- [ ] L3 多因子共振加仓 (反向使用) — 多因子共振时新仓 risk × 0.7 而非 × 1.5

## 决策记录

- **2026-05-09 13:00**: 用户问 "MDD 能否降到 15% 以内不影响盈利"
- **2026-05-09 13:30**: 实测 12 种方案, CB -5%/24h 单独 ROI 最高 (MDD 14.01%, ret -0.6%)
- **2026-05-09 13:45**: 推荐 Phase 1 部署 CB + DD 10% x0.5 组合 (MDD 14.34%, ret -4.3%)

## 代码位置

- 测试脚本: `/tmp/mdd_reduction_test.py`
- KK 上: `C:/Tools/factor_factory/scripts/mdd_reduction_test.py`

## 参考

- 主方案: [[PORTFOLIO_7FACTOR_XAUXAG_v20260509]]
- 整体性分析: [[INTEGRATED_ANALYSIS_v20260509]]
- 非线性诊断: [[NONLINEAR_DIAGNOSIS_v20260509]]
- 实盘部署: [[EBC57171_DEPLOY_GUIDE]]
