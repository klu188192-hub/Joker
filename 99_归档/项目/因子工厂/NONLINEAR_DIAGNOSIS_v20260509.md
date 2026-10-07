---
title: Portfolio 非线性能力诊断 + 5 等级提升路径
date: 2026-05-09
current_score: "2/10"
target_score: "5+/10 (3 月内)"
status: roadmap
tags:
  - 量化
  - 非线性
  - 升级路线
  - 短板分析
related:
  - "[[INTEGRATED_ANALYSIS_v20260509]]"
  - "[[PORTFOLIO_7FACTOR_XAUXAG_v20260509]]"
  - "[[IMPROVEMENT_ROADMAP_v20260509]]"
  - "[[MDD_REDUCTION_v20260509]]"
---

# Portfolio 非线性能力诊断 + 5 等级提升路径

> [!warning] 当前 portfolio 非线性能力 2/10 — 接近全线性
> 这是 IC 全部卡 ±0.20 上限、所有因子白噪声击败率 30-60% 的根本原因.
> 单笔最大杠杆: **L1 ADX gating + L3 共振加仓** (4 天工作量, Sharpe 预期 +50%).

## 当前 7 因子非线性能力评估

| 因子 | 非线性等级 | 实际形态 | IC 上限 | 白噪声击败率 |
|---|---|---|---|---|
| PureBO 突破 | ⚠️ L0 线性 | `if breakout: ±1` 二元阈值 | ~0.05 | ~50% |
| VP POC 反转 | ⚠️ L0 线性 | POC 距离单阈值, 二元 | ~0.05 | ~50% |
| Session+Fib | ⚠️ L0 线性 | session 过滤 + fib 价位 | ~0.05 | ~40% |
| Liquidation v6 | ⚠️ L1 准线性 | vol×body×breakout 三因子 AND | ~0.10 | ~30% |
| Gap Reject | ⚠️ L0 线性 | gap up/down 二元 | ~0.05 | ~30% |
| Divergence | ✅ L2 弱非线性 | RSI/MFI 与价格高低点比对 (结构性) | ~0.20 | ~10% |
| **XAU/XAG ratio** | ⚠️ L0 线性 | z-score 单阈值 | ~0.20 | **0%** ⭐ |

**整体诊断**: **2/10 接近全线性**

> [!note] XAU/XAG 是 L0 但白噪声 0% 的特例
> 跨资产分散 + 真均值回归 thesis 让简单 z-score 也有真 IC.
> 但若加非线性 (regime gating / 共振 / strength 缩放), 白噪声击败率不会变, IC 可能从 0.19 推到 0.30+.

## 为什么 IC 都卡 ±0.20

线性阈值天然只能捕捉一阶关系. 真高 IC (0.4+) 来源:
- 多变量交互 (如 ATR × volume × session)
- 非线性映射 (如 sigmoid / threshold function)
- regime-conditional alpha (如 trend regime 才用 momentum)
- 时序 sequence learning (LSTM / Transformer)

XAU H1 OHLCV 信号面 IC 上限 ~0.30. 真 IC 0.40+ 必须外部数据 (CFTC COT / TIPS yield / 期权 IV) 或非线性 ML.

## 当前 portfolio 主要短板

1. **全部信号 ±1 binary**: 强弱信号同等仓位, 信息浪费
2. **零 regime gating**: ADX/ATR/session/月效应 对因子开关无影响
3. **零特征交叉**: 多因子共振时不加仓, 矛盾时不减仓
4. **零自适应**: LB 永远固定, 不随波动率分位调整
5. **零 ML 学习**: 没有树模型/神经网学因子组合 alpha
6. **零跨周期共振**: H1 信号不参考 H4/D1 趋势确认

## 5 等级提升路径

### L1: ADX trend/range regime gating (1 周, ⭐⭐⭐ 优先)

```
ADX > 25 → 趋势期 → 启用 PureBO/Liquidation, 关闭 VP_POC/XAU_XAG
ADX < 20 → 震荡期 → 关闭 PureBO, 启用 VP_POC/XAU_XAG/Divergence
ADX 20-25 → 不确定 → 全部 risk × 0.5
```

| 项 | 预期 |
|---|---|
| Sharpe | +20-30% (从 4.34 → 5.2-5.6) |
| MDD | 几乎无副作用 (可能 -1 到 -2 pp) |
| 工作量 | 1 天写代码 + 1 周回测验证 |
| 实施复杂度 | 低 (ADX(14) 计算简单) |

### L2: 信号 strength → risk 缩放 (3 天)

把 binary signal 改成连续 strength:

```python
PureBO: strength = (close - level) / ATR  # 突破强度
VP_POC: strength = abs(close - poc) / ATR  # 偏离强度
XAU/XAG: strength = abs(z_score)  # 已经连续, 直接用

risk_per_trade = base_risk × min(strength / mid_threshold, 1.5)
```

| 项 | 预期 |
|---|---|
| MDD | -10 to -15% (弱信号小仓位) |
| Sharpe | +5-10% |
| 工作量 | 3 天 |
| 风险 | strength 计算需 walk-forward 验证 |

### L3: 多因子共振加仓 (3 天, ⭐⭐⭐ 优先)

```
共振检测 (1 H1 内多因子同向):
  - 3+ 因子同向: risk × 1.5, 信心强
  - 2 因子同向: risk × 1.2
  - 1 因子: risk × 1.0
  - 反向冲突: risk × 0.5 或暂停

特例: PureBO + Liquidation 同向时尤其强 (历史 WR 88%)
```

| 项 | 预期 |
|---|---|
| Sharpe | +30% |
| MDD | +5% (双刃剑, 共振错判时损失放大) |
| 工作量 | 3 天 |
| 风险 | 过拟合, 必须 strict 共振条件 |

### L4: XGBoost / LightGBM meta-model (2 周, 含防过拟)

学因子组合 alpha:

```python
features = [
    sig_pure, sig_vp, sig_ssf, sig_liq, sig_gap, sig_div, sig_xx,
    adx, atr_zscore, session_id, hour_of_day,
    vol_zscore, body_zscore, gap_size,
]
target = forward_return_24h

model = LightGBM(max_depth=4, n_estimators=200, ...)
predict_proba → meta-signal
```

| 项 | 预期 |
|---|---|
| Sharpe | +40-60% (历史 quant fund 实证) |
| MDD | 可能 -5 to -10% |
| 工作量 | 2 周 |
| **过拟合风险** | 极高, 必须严格 walk-forward CV + 特征数 < 20 |

### L5: HMM regime detection (1 月, 实验)

```
HMM 学市场状态 (4 状态: 强趋势上/弱趋势上/震荡/强趋势下)
每个状态下不同因子集开关 + 不同 risk 缩放
状态切换 detected → 立刻调整 portfolio
```

| 项 | 预期 |
|---|---|
| MDD | -30% |
| Sharpe | +50% |
| 工作量 | 1 月 (含状态调参) |
| 风险 | HMM 训练慢, 状态数选择难, 实盘切换延迟 |

## 短期建议 (1-2 周内可上)

### 优先方案 (4 天工作量, 风险可控)

**L1 ADX gating + L3 共振加仓** 组合:
- 1 周内完整开发 + 回测 + 部署
- 预期 Sharpe +50% (4.34 → 6.5)
- 预期 MDD 不变 或 -1 pp
- **配合 [[MDD_REDUCTION_v20260509|Circuit Breaker]] 部署可同步 MDD < 13%**

### 不推荐 (短期内)

❌ L4 XGBoost — 过拟合风险太高, 1 月内 OOS 不靠谱
❌ L5 HMM — 状态切换延迟问题严重, 实盘部署难
❌ 改造 PureBO/VP/Sess 因子内部 (L0 → L2) — 单因子收益边际小, 共振+gating 收益大

## 长期方向 (1-3 月)

### 引入外部数据真 IC 因子

| 数据源 | 真 IC 预期 | 频率 | 实现难度 |
|---|---|---|---|
| **CFTC COT** (持仓周变化) | 0.30-0.40 | 周频 | 中 (CME Quikstrike API) |
| **TIPS 10y yield** (实际利率) | 0.35-0.50 | 日频 | 低 (FRED API) |
| **期权 IV / put-call ratio** | 0.30-0.40 | 实时 | 中 (CBOE API) |
| **GLD ETF 净持仓** | 0.20-0.30 | 日频 | 低 |
| **DXY 极端值 (>3 std)** | 0.15-0.25 | H1 | 已有数据, 重新设计 |

### 跨品种 portfolio (XAG/US500/BTC)

7 因子框架复制到其他品种:
- XAG: 与 XAU corr 0.7-0.9, 可能跨品种 portfolio
- US500: 反转流派为主 (vs XAU 趋势主导)
- BTC: 极高波动, 仅 XAU/XAG 类反转因子可能适用

## 配合 MDD 控制

非线性升级与 MDD 控制可独立部署, 推荐顺序:

```
Week 1-2: [[MDD_REDUCTION_v20260509|Circuit Breaker + DD Throttle]] (MDD 17 → 14, ret -0.6%)
Week 3-4: L1 ADX gating (Sharpe +20-30%, MDD 几乎不变)
Week 5-6: L3 共振加仓 (Sharpe +30%, MDD +5%)
Week 7-8: 综合验证 + 实盘小资金部署 (5K-10K)
Month 3+: L4 / 外部数据 / 多品种
```

## 风险与限制

| # | 限制 | 缓解 |
|---|---|---|
| 1 | 非线性引入过拟合风险 | 严格 walk-forward CV, 特征数限制 |
| 2 | regime detection 切换延迟 | 用 ADX confirmation period (5 H1) |
| 3 | 共振加仓增加单笔风险 | 配合 max_lot cap + DD throttle |
| 4 | 外部数据 API 稳定性 | FRED 免费 + CFTC 周更, 备 fallback |

## 参考

- 整体性分析: [[INTEGRATED_ANALYSIS_v20260509]]
- 主方案: [[PORTFOLIO_7FACTOR_XAUXAG_v20260509]]
- MDD 控制: [[MDD_REDUCTION_v20260509]]
- 3 月 sprint: [[IMPROVEMENT_ROADMAP_v20260509]]
- 审计框架: [[REVIEW_FRAMEWORK_v20260509]]
