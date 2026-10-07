---
title: 方案 G+1.1 — IC RAW broker 切换 + ToD filter (重大优化)
date: 2026-05-09
prev: SCHEME_G_OPTIMAL_v20260509 (G+1, EBC + 全 factor 同等开机)
status: ready_to_deploy
deployment_target: IC RAW (从 EBC57171 迁移)
tags:
  - 量化
  - broker_shift
  - ToD_filter
  - 方案G+1.1
related:
  - "[[SCHEME_G_OPTIMAL_v20260509]]"
  - "[[INTEGRATED_ANALYSIS_v20260509]]"
  - "[[PORTFOLIO_7FACTOR_XAUXAG_v20260509]]"
---

# 方案 G+1.1 — Broker 切换 + ToD Filter

> [!success] 核心发现
> **broker spread 是实盘衰减的真凶, 不是因子设计** —
> Dukascopy mean spread 66 pts vs IC RAW ECN 15 pts
> 仅切换 broker → portfolio avg Sharpe **1.20 → 2.24 (+87%)**

## 1. 实测对比 (5y XAU H1, 7 因子)

| Scenario | Spread | ToD Filter | avg Sharpe | PureBO | Liquidation | XAU/XAG |
|---|---|---|---|---|---|---|
| 1 Baseline | 30 pts | no | 1.84 | 3.03 | 2.40 | 2.91 |
| 2 Realistic Duka | 66 pts | no | 1.20 | 1.32 | 1.73 | 2.56 |
| 3 ToD only Duka | 66 pts | yes | 1.16 | 1.08 | 1.67 | 2.58 |
| **4 IC RAW + ToD** | **15 pts** | **yes** | **2.24** ⭐ | **3.78** | **2.87** | **3.20** |
| 5 IC RAW only | 15 pts | no | 2.11 | 3.76 | 2.68 | 3.06 |

## 2. 关键决策

### 2.1 主账户切换到 IC RAW
- **原因**: Spread 30→66 时 PureBO Sharpe -56%; spread 66→15 时 +186%
- **影响**: Trend 系因子 (PureBO/Liquidation) 极敏感, MDD 从 77% → 14%
- **EBC57171 处置**: 保留作为 backup, 主账户切到 IC RAW
- **新 Magic 编号**: 57181-57187 (IC RAW 系列, 跟 EBC 区分)

### 2.2 ToD Filter 选择性应用
**仅对 mean rev 因子**:
- VP_POC: 排除 20-22 UTC (Sharpe +0.64)
- Session+Fib: 排除 20-22 UTC (Sharpe +0.34)
- **不加 ToD filter** 的因子: PureBO, Liquidation, Gap_Reject, XAU/XAG

**实施**:
```mql5
input int ExcludeStartHourUTC = 20;  // 默认 20:00 UTC
input int ExcludeEndHourUTC   = 22;  // 默认 22:00 UTC
// 在 OnTick / OpenSignal 之前加:
int hour_utc = TimeHour(TimeCurrent()) - TimeGMTOffset()/3600;
if (hour_utc >= ExcludeStartHourUTC && hour_utc <= ExcludeEndHourUTC) return;
```

### 2.3 Divergence 暂 SHELVED ⚠️
- 标准 factor_factory 引擎 5 个 scenarios 全部 Sharpe -0.20~-0.47
- archive simulator 跑出 PF 2.31 是因为 daily_stop=True 机制
- 部署需要特殊 EA 实现 daily_stop, 工程量大
- **决策**: 暂不部署, Phase 4 再 revisit

## 3. 最终 6 因子配置 (G+1.1)

| 因子 | RiskPerTrade | ToD Filter | Magic (IC RAW) | 5y Sharpe (实测) |
|---|---|---|---|---|
| PureBO | 1.0% | no | **57181** | **3.78** ⭐ |
| VP_POC | 1.0% | **20-22 UTC** | **57182** | **2.67** ✅ |
| Session+Fib | 0.5% | **20-22 UTC** | **57183** | **2.75** ✅ |
| Liquidation v6 | 0.75% | no | **57184** | **2.87** ⭐ |
| Gap Reject v3 | 0.25% | no | **57185** | 0.76 |
| XAU/XAG ratio | 0.5% | no | **57187** | **3.20** ⭐⭐ |
| **总单笔风险** | **4.0%** | | | **avg 2.67** |

**Divergence (Magic 57186) 暂留, 待 daily_stop EA 实现后激活**

## 4. 5y portfolio 预期 (IC RAW + ToD)

```
单因子层面 avg Sharpe: 2.67 (实盘衰减 30% 后 1.87)
组合层面 (复利 + 无马丁):
  CAGR: 280-320% (回测)
  Real Sharpe: 1.8-2.5 (实盘)
  MDD: 12-18%
  Calmar: 18-25

vs G+1 baseline (EBC):
  +87% avg Sharpe
  -50% MDD (PureBO 23.99% → 14.36%)
```

## 5. 部署 Phase 路线 (修正版)

### Phase 1 (现在 → 1 周)
- [ ] **切换主账户到 IC RAW** (开新 demo 或 live $1k 试)
- [ ] 写 PureBO_v2.mq5 (G+1.1 配置: 1% risk, 关马丁) Magic 57181
  - 已编译于 EBC, scp 到 IC RAW MT5
- [ ] 部署 PureBO 单 EA, 跟 EBC 对比 1 周 (验证 spread 真低)

### Phase 2 (PureBO IC RAW 验证后, 1-2 周)
- [ ] 写 VP_POC_v1.mq5 (含 ToD filter) Magic 57182
- [ ] 写 Liquidation_v6.mq5 Magic 57184
- [ ] 写 XAU_XAG_Ratio_v1.mq5 Magic 57187
- [ ] 实测 corr (PureBO 与 VP/Liq/XAUXAG)

### Phase 3 (Phase 2 稳定 1 月后)
- [ ] 写 Session_Fib_v1.mq5 (含 ToD filter) Magic 57183
- [ ] 写 Gap_Reject_v3.mq5 Magic 57185
- [ ] 完整 6 因子部署

### Phase 4 (Phase 3 稳定 2 月)
- [ ] 写 Divergence_archive.mq5 (含 daily_stop 机制) Magic 57186
- [ ] 实测 daily_stop 效果, 决定是否激活

## 6. 风险登记 (新增)

| # | 风险 | 触发 | 缓解 |
|---|---|---|---|
| R8 | IC RAW spread 实际 > 25 pts | 实盘 1 周 mean spread > 25 | 回 EBC + 重测 |
| R9 | ToD filter 砍太多 mean rev | VP_POC trade -50% 但 Sharpe 持平 | 调整为 21-22 UTC (1h) |
| R10 | IC RAW broker 风控 | margin / lot 限制 | 降单笔 risk 50% |

## 7. 不做的事

- ❌ ADX gating (实测 trend 系 -0.5~1.7 Sharpe)
- ❌ Trail 异构化 (实测 -77~97% Calmar 灾难)
- ❌ ATR-based trail (实测 Sharpe -0.33)
- ❌ 扩 trail 距离防 spread (反而砍 alpha)
- ❌ Divergence 用标准引擎部署 (PF 0.83)

## 8. 文件位置

- 测试脚本: `/tmp/spread_filter_icraw_test.py`
- 测试日志: `/tmp/icraw_test.log`
- 真实 spread 数据: `/tmp/duka_m1/XAU_H1_with_spread_2025.csv`
- session backup: `/Users/joker/.claude/session_backups/factor_hardening_latest.md`
