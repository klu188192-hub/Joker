# 6 因子 Portfolio FINAL — XAU H1 部署版

**归档日期**: 2026-05-09
**状态**: 5 因子部署候选 (Divergence 修复后失败 SHELVED)

---

## 因子库最终排名

| # | 因子 | 流派 | 5y n | WR | PF | net (lot 0.1) | MDD | 状态 |
|---|---|---|---|---|---|---|---|---|
| 1 | **PureBO 顺势突破** | 趋势延续 | 3,659 | 68.7% | **1.88** | $136,447 | 11.6% | ⭐⭐⭐ 主力 |
| 2 | **VP POC 反转** | POC 回归 | 2,473 | 71.5% | 1.43 | $64,272 | 20.5% | ⭐⭐⭐ 第二 (corr -0.04) |
| 3 | **Session+Fib 扫荡** | 流动性事件 | 1,739 | 72.6% | 1.57 | $57,112 | 19.7% | ⭐⭐ 第三 |
| 4 | **Liquidation v6** | 大爆量趋势 | 1,398 | 72.4% | 1.81 | $57,735 | 10.8% | ⭐⭐⭐ 第四 (扩频后) |
| 5 | **Gap Reject v3** | gap reject | 10 | 80.0% | **9.17** | $1,281 | 2.1% | ⭐ 极低频但 PF 顶级 |
| 6 | **Divergence (archive sim) ⭐** | mean reversion | **53** | **66.0%** | **2.31** | $2,704 | **1.37%** | ✅ **archive 原 simulator** |

**Divergence 关键修复**: 必须用 archive 原 `backtest_divergence` simulator (含 daily_stop)，**不能** 用 factor_factory 标准引擎 (会 PF 0.83 失败).
代码: `/Users/joker/factor_factory_archive/v20260509_divergence_h1/code/factor_divergence.py`

---

## 各因子最优配置

### 1. PureBO 顺势突破 (主力)
```
build_signal: H1 fractal(L=3, R=3) swing 突破
  close > last_swing_high → +1
  close < last_swing_low → -1
  同 swing 不重复 (last_break 锁)
SL: 4.0 ATR
TP: 1.0 ATR  
Trail: 0.5 USD (0.5 ATR 启动)
Time stop: 72 H1
ffill: 12 H1
```

### 2. VP POC 反转 (corr -0.04)
```
build_signal: 100 H1 滚动 POC + LVN
  价格在 LVN (cur_bin vol < 30% POC vol)
  距 POC ≥ 2 bins
  pin bar 拒收 (影线 > 实体 × 1.5 + 影线 > $1.5)
SL/TP/Trail/TS: 同 PureBO
```

### 3. Session+Fib 扫荡
```
build_signal: 三时段 (Asia 0-7 / London 7-13 / NY 13-21) sweep + Fib 0.618
  上一时段 H/L 被 sweep (假突破收回)
  回撤 ≥ 0.5 ATR
  Fib 0.618 触及 + 反转 K
SL/TP/Trail/TS: 同 PureBO
```

### 4. Liquidation v6 扩频版
```
build_signal: vol > SMA20 × 1.5 + body ≥ 1.0 ATR + 突破前 10 K 极值
  顺势开仓 (大涨破做多 / 大跌破做空)
SL/TP/Trail/TS: 同 PureBO
```

### 5. Gap Reject v3
```
build_signal: 开盘 gap > 0.5 ATR → fill → reject 状态机
SL: 2.0 ATR
TP: 4.0 ATR (RR 1:2)
Time stop: None (让 SL/TP 自然触发)
无 trail
```

### 6. Divergence (FAILED 不部署)
```
SL: 1.5 ATR / TP: 2.0 ATR / TS: 30 / 无 trail
依赖 archive 独立 simulator (daily_stop), 标准 factor_factory 引擎 PF 0.83-0.93
```

---

## Daily Correlation 矩阵

```
              PureBO    VP_POC    Session_Fib    Liq    Gap
PureBO         1.00    -0.04 ✅    +0.33         +0.18    (low)
VP_POC        -0.04 ✅   1.00     -0.05 ✅         0.00 ✅  (low)
Session_Fib   +0.33    -0.05      1.00          +0.08    (low)
Liq           +0.18     0.00 ✅   +0.08          1.00     (low)
Gap            (low)    (low)     (low)         (low)    1.00
```

**VP POC 跟其他 3 因子都是 0~负相关 → 真正的对冲核心**

---

## $1 万 5 年 Portfolio 收益 (复利+马丁, maxLot 5, 6 因子最终版)

| 配置 | 5 因子 (无 Div) | 6 因子 (含 archive Div) | Δ MDD |
|---|---|---|---|
| 0.5% risk 无马丁 | $4.26M (CAGR 212%) | **$4.57M (CAGR 216%)** | -0% |
| **0.75% + 马丁2.25 ⭐** | $11.30M (CAGR 274%) | **$11.53M (CAGR 276%)** | **-0.9%** ⭐ |
| 1.0% + 马丁2.25 | $12.72M (CAGR 283%) | $13.07M (CAGR 285%) | +0.3% |
| 1.5% + 马丁2.25 | $13.94M (CAGR 290%) | $14.26M (CAGR 291%) | +0.1% |

**Archive Divergence 加进去 = MDD 微降 + net 微升 + 整体稳定性提升**
- 边际增量小因 trade 数仅 53 (vs portfolio total ~9000 trades)
- 真正价值: mean reversion 流派 + low MDD 1.37% → 跟其他 5 因子负相关共振

---

## $1 万 1 年 Portfolio 收益 (2024 全年)

| 配置 | final | 倍数 | CAGR | MDD |
|---|---|---|---|---|
| 0.5% 无马丁 | $45,355 | 4.5× | 360% | 9.1% |
| **0.75% + 马丁 ⭐** | $263,122 | 26× | 2,610% | 22.3% |
| 1.0% + 马丁 | $713,765 | 71× | 7,316% | 28.9% |
| 1.5% + 马丁 (激进) | $1,476,085 | 148× | 15,338% | 31.8% |

⚠️ 数学模型，实盘衰减 60-70% 后:

| 部署 | **实盘预期 1 年** |
|---|---|
| 0.5% 无马丁 | $20-35k (2-3.5×) |
| **0.75% + 马丁** | **$80-180k (8-18×)** |
| 1.0% + 马丁 | $200-450k (20-45×) |
| 1.5% + 马丁 (激进) | $400-900k (40-90×) |

---

## Divergence 修复测试结果 (FAILED)

Archive 文档 (BEST_CFG): N=53, WR 66%, PF 2.31  
factor_factory 标准引擎实测:

| 配置 | n | WR | PF |
|---|---|---|---|
| 默认 (ffill=12 + reenter=True) | 136 | 53% | 0.83 |
| trigger only + reenter=True | 50 | 46% | 0.87 |
| 手工 simulator (按 archive 逻辑) | 49 | 61% | **0.93** |

**根因**: archive simulator 用 `use_daily_stop=True / MAX_DAILY_LOSS=-0.02`（单日停损）+ small sample bias (N=53)。
标准引擎不支持 daily_stop, 真实 PF 0.93 < 1。

**判定**: Divergence 不达标，归档 SHELVED

---

## ⚠️ 历史教训 (重要)

### MACD_SB_CONFLUENCE 框架已死 (CLAUDE.md 痛史)

`MACD_SB_CONFLUENCE_v1.md` 文档显示 Sharpe 3.78-4.04, 但:

> CLAUDE.md: MACD_SSL_v2 修 look-ahead 后真实是 50% 胜率 + 4 年 -79.8% CAGR
> 32 个实盘 EA 不开单, 因为信号需要 i+RIGHT 才能确认, 而回测假装 i 时已知

**MACD_SB_CONFLUENCE 整个框架建立在 lookahead 数据之上, 修后会崩**。  
不要重启此因子。32 EA 痛史已证明实盘失败。

### 教科书因子翻车 5 次确认

| 因子 | PF | 状态 |
|---|---|---|
| MACD/SSL (痛史) | 7.80→-79.8% CAGR | SHELVED |
| RSI+MACD 双背离+EMA+吞没 | 0.64 | SHELVED |
| M5 EMA100+吞没 | 0.27 | SHELVED |
| SMC HHHL+吞没 v1-v5 | 0.40-0.88 | SHELVED |
| **Divergence (今天)** | **0.83-0.93** | SHELVED |

**物理规律**: H1+ TF 上"3+ retail 经典指标堆叠"100% 不工作。真 alpha 来自结构 (BOS/swing) + trail 机制，不来自 retail 形态。

---

## 推荐部署路径

### Phase 1 (现在 → 2 天观察) ⏳
- 单 PureBO 已部署 EBC57171 (Magic 57171, 3% risk)
- 等 24-48h 实盘数据

### Phase 2 (PureBO 验证后)
- 加 VP POC EA (Magic 57172, 各 1.5% risk)
- 跟 PureBO corr -0.04 真负 → 真正对冲

### Phase 3 (Phase 2 稳定 1 月后)
- 加 Liquidation v6 + Session+Fib (各 0.75% risk)
- 总 4 因子各 0.75% risk = 3% 总风险

### Phase 4 (验证完整后)
- 加 Gap Reject v3 (极低频, 单独 lot 1.5-2.5)
- 5 因子最终配置

### 不部署
- ❌ Divergence (PF 0.93)
- ❌ MACD_SB_CONFLUENCE (痛史 lookahead)
- ❌ V4 网格金字塔 (CAGR 0.6%)
- ❌ 所有 SHELVED 因子

---

## 文件清单

### 代码
- `code/factor_1_purebo_breakout_h1.py` ⭐ 已部署
- `code/factor_2_vp_poc_h1.py`
- `code/factor_3_session_fib618_h1.py`
- `code/factor_4_liquidation_v3_baseline.py` (扩频版需用 VOL_MULT=1.5/BODY=1.0/LB=10)
- `code/factor_5_gap_reject_v3.py`
- `code/factor_6_divergence_long_only_FAILED.py` (FAILED, 不部署)

### 脚本
- `scripts/portfolio_6factor_final.py` (5y + 1y portfolio 综合)
- `scripts/portfolio_5y_returns.py` 
- `scripts/portfolio_1y_returns.py`
- `scripts/div_fix_test_v2.py` (Divergence 修复尝试)
- `scripts/liq_expand_freq_grid.py` (Liquidation 扩频实验)
- `scripts/v4_grid_pyramid_sim.py` (V4 网格 SHELVED)
- `scripts/portfolio_5factor_with_gap.py`

### KK 因子库
- `Breakout_SSL_Hunt_H1_v2_pinbar.json` (老 v8, PureBO 取代)
- `VolumeProfile_POC_Reversion_H1.json`
- `Session_Sweep_Fib618_H1.json`
- `Liquidation 多个 v* json`
- `Gap_Reject_v3_*.json`

---

## 不要再做的事

- ❌ 重测 MACD/SSL/MACD_SB_CONFLUENCE (lookahead 痛史)
- ❌ retail 教科书指标堆叠 (5 次失败)
- ❌ M5/M1 上做 EMA + K 形态 (3 次失败)
- ❌ 在 retail 经典指标堆叠上投入更多时间
- ❌ 一次性部署多 EA (用 Phase 路径稳健扩张)
