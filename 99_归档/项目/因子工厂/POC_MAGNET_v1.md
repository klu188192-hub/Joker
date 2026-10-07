# POC Magnet Breakout H1 因子方案 v1

**生成日期**: 2026-05-08
**状态**: 已通过 5y 历史回测验证，**推荐独立账户/独立仓位部署**

---

## 核心结论

POC Magnet Breakout 是 35+ 版扫荡里**第二个 Tier C 因子**（仅次于 Structure Breakout），且**单独绩效全面优于 SB**（PF 1.36 vs 1.06, Sharpe 1.14 vs 0.32, MDD 17% vs 33%）。

但它跟 MACD 的 Pearson corr 高达 **0.580**（vs SB 仅 0.081），所以**不适合做 MACD confluence 加权**——任何权重组合都让 Sharpe 下降。

**推荐定位：独立资金部署**（不与 MACD 加权，单独账户/子仓位运行赚自己的 alpha）。

---

## 因子规格

**POC（成交量加权平均价）**：
```
POC = sum(close × tick_volume, 过去20根H1) / sum(tick_volume, 过去20根H1)
```

**磁吸区** = [POC - 0.5×ATR(14), POC + 0.5×ATR(14)]

**做多条件（同 K 全部成立）：**
1. 过去 5 根 H1 close 全部在磁吸区内（共识区）
2. 当前 K 阳线 + 实体 > 前 5 根平均实体 × 2
3. close 突破磁吸区上沿 (POC + 0.5×ATR)
4. tick_volume > 前 20 根均量 × 1.3

**做空条件**: 镜像（阴线 + close 突破下沿）

**入场**: 触发 K 收盘后下根 K 开盘市价
**SL**: POC 位置（实测 sl_atr_mult=0.7 等价）
**TP**: 入场 + 2 × SL_dist（RR=1:2，tp_atr_mult=1.4）
**信号 ffill 12 H1** 让 ATR SL/TP 真出场

---

## 5y 真实回测（XAU H1, dukascopy 数据 2021-01 ~ 2026-05）

| 指标 | 数据 |
|---|---|
| n_trades | 203 (5y, 月均 3.2) |
| WR | 43.8% |
| PF | **1.36** |
| Sharpe (bar-level) | 0.541 |
| **Sharpe (monthly)** | **1.14** (年化) |
| Max Drawdown | **17.24%** |
| net_pnl (10000 本金) | **+$2,869** (+28.7%, CAGR 5.2%) |
| Tier | **C** ⭐ |
| factor_factory score | **24.5** |

## Trades 真实诊断（88% ATR 出场，无脉冲假象）

| reason | n | WR | sum | avg/笔 |
|---|---|---|---|---|
| **tp** | 70 | 100% | +$9,824 | +$140 |
| **sl** | 110 | 0% | -$7,887 | -$72 |
| signal | 23 | 82.6% | +$932 | +$41 |
| **合计** | 203 | 43.8% | +$2,869 | +$14.13 |

**实际 RR = 140/72 = 1.94**（设计 RR=1:2，几乎完美还原）。
**bars_held median 1, max 12**（多数交易在 1-3 H1 内出场）。

## 月度统计（22 个月活跃）

| | 数据 |
|---|---|
| 月度均值 | +$130 |
| 月度 std | $397 |
| 正月数 | 11/22 (50%) |
| 月度 Sharpe (年化) | **1.14** |
| 触发月份 | 2023-10 ~ 2026-03 |

## 跟 MACD_div 的关系

| | 数据 |
|---|---|
| Pearson corr | **0.580** (高) |
| Spearman corr | 0.360 |
| Combo 50/50 Sharpe | 2.45 (vs MACD 单独 2.56) |
| **结论** | **不适合加权组合** |

但**资金独立分配可行**：因为 POC 自身 Sharpe 1.14 不弱，单独账户跑能赚自己的钱，不进入 MACD 仓位加权计算。

---

## Confluence 验证（确认不适合）

POC 当 MACD 过滤层加权（amp/damp 1.5/0.5 等多种配置）：

| 状态 | n | WR | PF | avg/笔 |
|---|---|---|---|---|
| amplify (POC 共振) | 70 | 50.0% | **1.88** | +$35.70 |
| dampen (POC 反向) | 68 | 36.8% | 1.46 | +$21.53 |
| neutral | 1302 | 44.1% | 1.45 | +$20.65 |

amplify 状态有真增益，**但命中率仅 5%**（vs SB 26%）—— POC 触发太稀+ corr 高，confluence 净效应中性偏负。

---

## 实战部署架构（最终版）

```
EBC-3 主账户 ($10,000)
├── 70% — MACD_div_SSL + SB confluence (主力, Sharpe 3.78)
│   └── 0.10 lot baseline
│       ├── SB 共振 → 0.15 lot
│       └── SB 反向 → 0.05 lot
├── 30% — POC Magnet 独立子仓位 (Sharpe 1.14, 不加权 MACD)
│   └── 0.05 lot per signal
└── Silent Breakout 事件警报 (不开仓, 给人工提示)
```

**预期组合 Sharpe ≈ 3.5+**（主仓占主导, POC 微提）

**风险预算**：
- 主仓 max drawdown: 5-8% (MACD_div MDD 3% × SB confluence 风险加成)
- POC 子仓 max drawdown: 17% (但只占 30% 资金 → 账户级 5%)
- 总账户 max drawdown 预期 < 12%

---

## 文件位置

- **因子代码**: `/tmp/poc_magnet_breakout_h1.py`（mac）
- **因子库**: `factor_library/POC_Magnet_Breakout_H1.json`（KK + mac）
- **trades CSV**: `reports/_poc_magnet_trades.csv`（KK）
- **monthly CSV**: `reports/_poc_magnet_monthly.csv`（KK）

---

## 因子库总状态（38 版扫荡后）

| 因子 | n/5y | PF | Sharpe (月) | corr vs MACD | 实战定位 |
|---|---|---|---|---|---|
| **MACD_div_SSL** (8 变种) | 5,553 | 2.09 | **2.74** | 1.00 | 主力 alpha |
| **Structure Breakout** | 1,058 | 1.06 | 0.32 | **0.081** | confluence 加权器 |
| **POC Magnet** ⭐ | 203 | **1.36** | **1.14** | 0.580 | **独立部署候选** |
| EMA Divergence Pullback | 167 | 1.02 | -0.03 | 0.186 | 接近平衡，不用 |
| Silent Breakout | 55 | 1.03 | N/A | N/A | 事件警报 |
| DXY 跨品种 | 1,139 | 1.17 | 0.53 | 0.529 | 不用 |
| RSI 极端反转 (8 版) | 247 | 0.73 | -0.58 | — | 负 alpha |
| 亚盘突破伦敦 (4 版) | 1,239 | 0.77 | — | — | 负 alpha |
| 趋势延续 (2 版) | — | 0.25 | — | — | 显著负 |

**总结：5 因子方案构建完毕（MACD 主 + SB confluence + POC 独立 + Silent 警报 + EMA Div 候补）**。
