---
title: Portfolio_G11_Master v3.3 终版 — 6 因子 + 5 层风控 + ATR Regime
date: 2026-05-10
version: v3.3
status: ready_for_mt5_tester
target: IC RAW broker (XAUUSD H1)
related:
  - "[[PORTFOLIO_G11_MASTER_EA_v20260509]]"
  - "[[SCHEME_G1_1_BROKER_SHIFT_v20260509]]"
  - "[[CROSS_TF_SYMBOL_TEST_v20260509]]"
tags:
  - 量化
  - master_ea
  - 终版
  - 5层风控
---

# Portfolio_G11_Master v3.3 — 完整集成终版

> [!success] 完整改造完成 (2026-05-10)
> v3.3 最终版: 6 因子 + 5 层风控 + ATR% regime detector + 全 Stage 1+2 优化参数
> 编译: 0 errors / 81,828 bytes
> archive: /Users/joker/factor_factory_archive/v20260510_portfolio_g11_full/

## 📊 5y XAU H1 实测 (IC RAW + 5 pt slippage, 复利)

| 指标 | 数值 |
|---|---|
| **总交易数** | **8,062 笔** (5.33 年, regime filter 后) |
| **工作日均交易** | **5.80 笔/天** (高波动期 11/天, 低波动期 0.4/天) |
| **总盈利 ($10k 起)** | **$13,657,900** (+136,579%, 复利) |
| **5y CAGR** | 287.4% |
| **最大回撤 (复利)** | **8.39%** (regime + 5 层风控) |
| **Calmar ratio** | 34.25 |
| **WR / PF** | 74.4% / 2.32 |

> [!note] 真实 MDD 区间 (按 broker)
> IC RAW: 8-10% / EBC: 12-14% / 高 spread broker: 18-20%
> 不要被 287% CAGR 数字迷惑 — 是 5y 不均匀分布:
> 2021-2022 累积 -5.6%(弱波动期), 2024-2025 +4173% (大牛市 + 高波动)

## 🏗️ 架构 (Master Magic 57180)

```
1 EA + 1 Chart 跑 7 因子 (Div 默认 disabled)
Sub-magic 区分 trade 来源:
  57181 PureBO       1.0% risk  ⭐ net 王 (38% 总盈利)
  57182 VP_POC       1.0% risk  + H4 EMA50 confluence (PF 1.45→3.91)
  57183 Session+Fib  0.5% risk  Stage 2 factor params (FIB 0.5)
  57184 Liquidation  0.75% risk + H4 PureBO + Range filter (MDD -55%)
  57185 Gap_Reject   0.25% risk SL 2 / TP 4 (5y 仅 10 笔)
  57186 Divergence   DISABLED (5y net 负 -$2,363)
  57187 XAU/XAG ratio 0.5% risk 真分散因子 corr 0.05-0.23

总 risk: 3.5% (含 Gap, 不含 Div)
```

## 🛡️ 5 层风控 (按触发时序)

### Layer 1: ATR% Regime Detector ⭐ 新加 (v3.3)
```
> 0.15% (Wilder ATR%) → NORMAL (full lot)
0.08-0.15%             → REDUCED (lot × 0.5)
< 0.08%                → PAUSE (skip entry, 类 2021-2022)

实测 5y: MDD 20.17% → 12.26% (-39%), Net 几乎不变 (-0.04%)
```

### Layer 2: Spread Hard Limit
```
> 50 pts → 暂停所有 entry (NFP/CPI 防护)
```

### Layer 3: Spread Spike (滚动)
```
当前 > 过去 200 ticks median × 3 → 跳过
```

### Layer 4: Range Filter (仅 Liq/Sess/VP)
```
当前 H1 (high-low) > 历史 120 H1 median × 2.5 → 跳过
实测: Liquidation MDD 15.42% → 6.94% (-55%) ⭐
```

### Layer 5: Portfolio Circuit Breaker
```
单日 MDD > 5%  → 暂停 12h
单周 MDD > 10% → 暂停 72h
Divergence daily_stop: 单日 -1.5% → 仅停该因子
```

### Bonus: Dynamic Trail
```
trail = max(base_trail, spread × 2)
防 spread 飙升时 trail 被瞬间穿
```

## 💰 Inputs 关键默认值 (v3.3 已优化)

```
=== 全局风控 ===
UseCompound = true
UseMartingale = false
MaxLotCap = 5.0
DailyMDDStopPct = 5.0 / WeeklyMDDStopPct = 10.0

=== ATR% Regime ===
RegimeATRPctNormal = 0.15
RegimeATRPctReduced = 0.08
RegimeReducedMult = 0.5

=== 因子 1: PureBO (57181) Risk=1.0% ===
PureBO_SLAtr=4.5 (优化: 4.0→4.5)
PureBO_TPAtr=1.0 / TimeStop=24

=== 因子 2: VP_POC (57182) Risk=1.0% + H4 EMA50 ===
UseH4Filter_VP=true (实测 MDD -85%, PF +157%)
VP_SLAtr=4.5 / VP_TPAtr=0.7 / TimeStop=24
TrailActivate=0.8 (反转因子等深浮盈)

=== 因子 3: Session+Fib (57183) Risk=0.5% ===
Sess_FibRatio=0.5 (Stage 2 优化, 0.618→0.5)
Sess_PullbackMinAtr=0.3 / BreakFailAtr=0.5
Sess_PullbackTimeout=8 / FibTouchTimeout=18
Sess_SLAtr=4.5 / TPAtr=1.0 / TimeStop=48

=== 因子 4: Liquidation (57184) Risk=0.75% + H4 PureBO ===
UseH4Filter_Liq=true
Liq_SLAtr=4.5 / TPAtr=1.0 / TimeStop=24

=== 因子 5: XAU/XAG (57187) Risk=0.5% ===
Ratio_SLAtr=4.5 / TPAtr=0.7 / TimeStop=48

=== 因子 6: Gap_Reject (57185) Risk=0.25% ===
Gap_SLAtr=2.0 / TPAtr=4.0 / 无 trail / 无 timestop

=== Trail (共用) ===
TrailFixedUSD = 0.3 (优化: 0.5→0.3, MDD -33%)
TrailActivateAtr = 0.3 (PureBO/Liq) / 0.8 (VP/Sess)

=== Spread 防护 ===
HardSpreadLimitPts = 50
SpreadSpikeMult = 3.0
RangeFilterLookback = 120 / RangeFilterMult = 2.5

=== EA 控制 ===
MasterMagic = 57180
MaxSlippagePts = 30
```

## 📊 Daily 开仓分布 (5 层风控全开)

| 单日交易数 | 占工作日% |
|---|---|
| 0 笔 (PAUSE) | 29.9% |
| 1 笔 | 22.1% |
| 2-5 笔 | 6.3% |
| 6-15 笔 (活跃日) | 31.0% |
| 16-25 笔 | 11.0% |
| 26+ 笔 | 0.7% |

按年:
- 2021-2022 (低波动): 0.40-0.45 笔/天 (regime PAUSE)
- 2024-2026 (高波动): 10-12 笔/天 (NORMAL)

## 💼 $10,000 账户单笔仓位

| 因子 | Risk% | 风险 USD | SL/lot | 实际 Lot/笔 |
|---|---|---|---|---|
| PureBO | 1.0% | $100 | $1,366 | 0.073 |
| VP_POC | 1.0% | $100 | $1,129 | 0.089 |
| Session+Fib | 0.5% | $50 | $2,013 | 0.025 |
| Liquidation | 0.75% | $75 | $1,370 | 0.055 |
| XAU/XAG | 0.5% | $50 | $2,631 | 0.019 |
| Gap_Reject | 0.25% | $25 | $824 | 0.030 |

总 lot 极限 (6 因子同向): 0.291 lot, 名义敞口 $130k = 13× equity

## 🔍 Leave-One-Out 因子贡献排名 (G+1 7 因子)

| Rank | 因子 | ΔCalmar (移除后) | 评价 |
|---|---|---|---|
| 📉 #1 最边缘 | PureBO_H1 | +6.61 | net 王但跟其他因子 corr 高 |
| ⚠️ #2 边缘 | VP_POC | +0.15 | 单点贡献小 (已被 H4 砍频率) |
| ⚠️ #3 边缘 | **Divergence** | +0.01 | **5y net 负, 已禁用** |
| ✅ #4 价值 | Gap_Reject | -0.01 | 中性 |
| ✅ #5 价值 | Session+Fib | -0.08 | |
| ✅ #6 价值 | XAU/XAG | -0.24 | 真分散 corr 0.05-0.23 |
| ✅ #7 **最有价值** | **Liquidation** | **-0.31** | portfolio 单点价值最高 |

## 🎯 工作流核心修复

之前用自己写的 simple_trail_bt 做 audit, PureBO 跑 PF 0.935 vs archive 1.883.
v3.3 改用 archive `factor_factory/backtest/engine.py` ground truth, 1:1 复现 baseline.

```python
import sys
sys.path.insert(0, "/tmp/factor_factory_engine")
from backtest.engine import run_event_driven
from backtest.types import BacktestConfig, SymbolSpec, CostConfig
# 真实 spread 注入: use_data_spread=False, spread_points=N
```

## 📁 完整归档

```
/Users/joker/factor_factory_archive/v20260510_portfolio_g11_full/
├── code/
│   ├── Portfolio_G11_Master_v3.3.mq5      (终版 EA 源)
│   ├── factor_factory_engine/             (archive 真实引擎)
│   ├── factor_*_param.py (3 个参数化因子)
│   ├── repro_*.py (1:1 复现脚本)
│   ├── grid_*.py (4 个 grid search)
│   ├── multi_tf.py / portfolio_*.py / regime_stress_test.py
│   ├── spread_*.py (2 个 spread 测试)
│   ├── verify_regime.py / daily_breakdown.py
│   └── forex_test.py
├── data/ (XAU H1/H4, XAG H1)
└── docs/ (历史报告)
```

## ✅ 编译状态

```
Portfolio_G11_Master.ex5  81,828 bytes  v3.3
Result: 0 errors, 0 warnings, 462 ms
位置: D:\EBC-mt5\MQL5\Experts\Portfolio_G11_Master.ex5 (KK)
归档: /Users/joker/factor_factory_archive/v20260510_portfolio_g11_full/code/
```

## ⏭️ 下一步: MT5 Strategy Tester 完整验证

启动测试:
1. RDP → KK MT5 (建议 IC RAW 实例)
2. 加载 Portfolio_G11_Master.ex5
3. 设置:
   - Symbol: XAUUSD
   - Timeframe: H1 (主)
   - Period: 2021-01-04 → 2026-05-04
   - Model: Every tick based on real ticks
   - Initial deposit: $10,000
   - Spread: 实际 broker
4. 跑完后对账:
   - 总交易: 期望 ~8,000 (±10%)
   - MDD (复利): 期望 8-13% (broker 决定)
   - Net: 期望 $10M+ (5y, $10k 起)
   - PF: 期望 ~2.3
5. 如果 MT5 PF/MDD 跟 Python ground truth 差距 < 15% → 翻译正确, 可部署
   差距 > 30% → EA 翻译有 bug, 回去找

## 风险提示

1. ⚠️ 不要假设 287% CAGR 是常态 — 5y 含 2 年亏损 + 3 年暴涨
2. ⚠️ 低波动期 (类 2021-2022) regime PAUSE 是正常, 不是 EA 失效
3. ⚠️ 实盘前必须 KK demo 跑 1 周对账 spread / slippage / margin 行为
4. ⚠️ $1,000 以下账户 lot floor 强制 → 实际 risk 高于设定, 不建议使用
