---
title: DXY 跨市场因子失败记录 (反面教材)
date: 2026-05-09
factor_id: DXY_Cross
status: REJECTED
audit_status: 5_of_5_failed
ic_h24: 0.0004
white_noise_beat_rate: 0.84
oos_2026_pf: 0.94
oos_2026_sharpe: -0.29
tags:
  - 量化
  - 因子
  - 跨市场
  - REJECTED
  - 反面教材
related:
  - "[[INTEGRATED_ANALYSIS_v20260509]]"
  - "[[XAU_XAG_RATIO_v1]]"
  - "[[REVIEW_FRAMEWORK_v20260509]]"
---

# DXY 跨市场因子失败记录 (反面教材)

> [!failure] 5 维 audit 全部失败, 永久 SHELVED
> IC h=24: +0.0004 (thesis 完全失效) | 白噪声击败率: 84% (alpha=0) | 2026 OOS: PF 0.94, Sharpe -0.29 (崩盘)

## 初衷

解决用户最初担忧 — "trail alpha 单点失败, 没有真 IC 因子"
跨市场因子是首选 — DXY 历史 corr -0.85 with XAU.

## 假设 (失败的 thesis)

```
DXY 与 XAU 历史 corr -0.85
DXY 滞后 1-3 H1 变化预测 XAU 反向方向

触发:
  DXY (t-3 → t-1 H1) 涨幅 > 1.5 std → XAU 做空 (反向)
  DXY (t-3 → t-1 H1) 跌幅 > 1.5 std → XAU 做多 (反向)
```

## 5 维 audit 完整失败结果

| 维度 | DXY | 判定 |
|---|---|---|
| 1. Lookahead mask audit | 100% 一致 | ✅ |
| 2. **IC h=1/4/24/72/168/240** | **全部 \|IC\| < 0.02** | ❌ thesis 完全失效 |
| 3. 2024+ 回测 | PF 1.54, Sharpe 1.96 | ⚠️ 漂亮但欺骗性 |
| 4. corr vs 6 因子 | 全部 < 0.1 | ✅ (但意义不大) |
| 5. **白噪声击败率 (n=50)** | **42/50 = 84%** | ❌ 灾难 |
| 6. **2026 OOS** | **PF 0.94, MDD 39.5%, Sharpe -0.29** | ❌ 崩盘 |

### IC 详细数据

```
h=  1H1: n=7718, IC=+0.0041
h=  4H1: n=7718, IC=+0.0128
h= 24H1: n=7718, IC=+0.0004  ◀━━ 接近完全 0
h= 72H1: n=7718, IC=-0.0147
h=168H1: n=7694, IC=-0.0137
h=240H1: n=7681, IC=-0.0055

  -- IC by year (h=24) --
  2024: n=5626, IC=+0.0070  (噪声)
  2025: n=1767, IC=-0.0035  (噪声)
  2026: n= 306, IC=-0.1574  (反转, 但 n 小不可信)
```

### 白噪声基线灾难

```
Real DXY PF: 1.542
Random 50 因子 PF mean: 1.512  (几乎完全一样!!!)
Random 50 因子 PF range: 1.291 - 1.777
Beat rate: 42/50 = 84%
```

> [!important] 这彻底证明 PF 1.54 全部来自 trail 0.5 USD 系统
> 任意 50 个**纯随机**入场点 + 同样的 trail 系统 = 一模一样的 PF mean 1.51.
> DXY 因子的"alpha"完全是统计幻觉.

### 2026 OOS 已死

```
2024 PF 1.63 / Sharpe 2.84
2025 PF 1.74 / Sharpe 3.01
2026 PF 0.94 / Sharpe -0.29 / MDD 39.5%  ◀━━ 崩盘
```

不是统计噪声, 是 thesis 真死.

## 失败根因 — 为什么 thesis 错了

### 1. 同期相关 ≠ 滞后预测

DXY corr -0.85 是 **同期** 相关 (H1 同时段闭环), 不是 *滞后预测*.

实证: IC h=1/4/24/72/168/240 全部 |IC| < 0.02. 在所有时间尺度上, DXY 都不能 *预测* XAU.

### 2. 算法套利吃光信息

DXY 1-3 H1 滞后信息 **早已被算法套利在分钟级吃光**:
- ETF (GLD/UUP) 高频套利
- 期货 (GC/DX) 跨市场算法
- 中央做市商 (Citadel/Two Sigma) 实时对冲

等 H1 收盘信号出来时, XAU 已经反映完毕. H1 时间尺度上的 DXY 信号是 **完全 stale**.

### 3. trail 系统让随机信号也漂亮

DXY 的 PF 1.54 / WR 74% / Sharpe 1.96 看似不错, 但与白噪声 1.51 几乎一样.

**关键认知**: 在 ATR-based SL/TP + 0.5 USD trail 系统下, **任何随机 ±1 信号** 都会得到类似数字, 因为:
- ATR SL 4× / TP 1× → 自然 R/R 0.25 但 trail 后实测 0.55
- WR 自然到 70%+ (短 TP 高命中率)
- PF 自然到 1.5+ (trail 锁惯性)

→ **PF/WR/Sharpe 不是真 alpha 标尺, IC + 白噪声基线才是**.

## 与 XAU/XAG ratio 的对比 ([[XAU_XAG_RATIO_v1]])

同样跨市场因子, 完全不同结果:

| 维度 | DXY (失败) | XAU/XAG (✅) | 差异原因 |
|---|---|---|---|
| 思路 | 滞后预测 (corr -0.85) | 均值回归 (ratio 70-100) | 思路本质不同 |
| Lookahead | 100% | 100% | 都通过 |
| **IC h=24** | **+0.0004** | **+0.1948** | **480× 倍差距** |
| 白噪声击败率 | 84% | 0% | 质变 |
| 2026 OOS | PF 0.94 (崩) | PF 1.76 (盈) | 完全相反 |

**关键差异**:
- DXY: 试图 *预测下一个 H1 的方向* (失败 — 信息已过期)
- XAU/XAG: 利用 *已发生的偏离* (成功 — ratio 偏离是事实, 修复是统计规律)

## 4 大教训

### 1. 跨市场不等于真 IC

不是所有跨市场因子都好. 跨市场因子失败/成功的关键:
- ❌ **滞后预测**: 信息已被算法套利吃光 → 失败
- ✅ **均值回归 / 同期偏离捕捉**: 利用结构性 inefficiency → 成功
- ✅ **极端值后修复**: 偏离 N std 是已发生事实 → 成功

### 2. 白噪声基线必跑

5 维 audit 的灵魂步骤. 击败率 > 5% 立刻拒绝, 无论 PF 多漂亮.

DXY 教训: PF 1.54 / WR 74% / Sharpe 1.96 都是统计幻觉. 不跑白噪声不会发现.

### 3. trail 系统会让随机信号也漂亮

任何 ATR-based SL/TP + trail 系统下, 随机 ±1 信号都会得到 PF 1.4-1.6 / WR 70%+. 这是 **trail 自带的统计偏差**.

→ 看到 PF 1.5 + WR 75% + Sharpe 2 不要兴奋, 跑白噪声看是不是因子真值.

### 4. OOS 必须独立

2024-2025 训练期看似漂亮, 2026 OOS 直接崩 (PF 0.94, Sharpe -0.29).

→ 不能用训练期参数说话. walk-forward 必须严格.

## 可能的复活路径 (供未来参考)

DXY 因子代码已归档 `code/factor_dxy_REJECTED.py`, 改 thesis 后或许可用:

| 方向 | 思路 | 可行性 |
|---|---|---|
| DXY 极端值 (>3 std) + XAU 同向背离 | 共振过滤器, 仅极端期触发 | 中 |
| DXY 跨日变化 (D1 chg) | D1 时间尺度可能有信号 | 中 |
| DXY + DXY iV (隐含波动率) 交互 | 二阶因子, 可能有 alpha | 低 |
| DXY 前夜 NFP/CPI 后 1-3 H1 反应窗口 | 事件驱动, 局部窗口 | 中 |

均需重新跑完整 5 维 audit 验证.

## 数据备份

- 因子代码: `/Users/joker/factor_factory_archive/v20260509_portfolio_7factor_XAUXAG/code/factor_dxy_REJECTED.py`
- audit 脚本: `/Users/joker/factor_factory_archive/v20260509_portfolio_7factor_XAUXAG/code/audit_xau_xag.py` (改 mod_dxy 路径)
- 数据: `C:/Tools/factor_factory/data/Dollar_H1.csv` (KK)

## 参考

- 整体性分析: [[INTEGRATED_ANALYSIS_v20260509]]
- 成功对照: [[XAU_XAG_RATIO_v1]]
- 审计框架: [[REVIEW_FRAMEWORK_v20260509]]
- 5 维 audit 工具: `/tmp/lookahead_lint.py`, `/tmp/lookahead_decorator.py`
