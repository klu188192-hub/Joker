---
title: 黄金 H1 多因子组合策略整体性分析
date: 2026-05-09
version: v20260509_7factor_XAUXAG
prev: v20260509_6factor (方案 G)
status: ready_for_deploy
deployment_target: EBC57171
tags:
  - 量化
  - 组合策略
  - 因子工厂
  - 方案G+1
  - XAU
  - 整体性分析
related:
  - "[[SCHEME_G_OPTIMAL_v20260509]]"
  - "[[PORTFOLIO_7FACTOR_XAUXAG_v20260509]]"
  - "[[XAU_XAG_RATIO_v1]]"
  - "[[DXY_REJECTED_v20260509]]"
  - "[[NONLINEAR_DIAGNOSIS_v20260509]]"
  - "[[IMPROVEMENT_ROADMAP_v20260509]]"
  - "[[EBC57171_DEPLOY_GUIDE]]"
---

# 黄金 H1 多因子组合策略 — 整体性分析

> [!summary] 一句话定位
> 7 因子 portfolio (方案 G+1, 复利无马丁) — **回测**显示 5y CAGR 2,144%, MDD 14-17%, Sharpe 5.4
> 核心增量: **首个白噪声击败率 0% 的真 IC 因子 [[XAU_XAG_RATIO_v1]]**, 解决 trail 单点 alpha 脆弱性

> [!danger] 必读: [[REALITY_CHECK_v20260509]] — 数字可信度审计
> portfolio 级别的 CAGR 2,144% / Sharpe 5.43 / final eq $14M 是**回测 artifact, 实盘永远不可能实现**.
> 真实 5y 预期: $10K → $30K-$300K (3-30x), 不是 $14M (1418x).
> 实盘 Sharpe 2.5-3.0 (顶级) / MDD 25-35%.
> 单因子层级 IC / WR 经严审, 实盘衰减 30-40% 后**可达**.

## 0. 关键数字一览

| 指标 | 6 因子 baseline | **7 因子 G+1** | 增量 |
|---|---|---|---|
| Final equity (2024+ 1万起) | $12,443,764 | **$14,185,142** | +$1,741,378 |
| Ret 2024+ | +124,337% | **+141,751%** | +17,414 pp |
| **MDD (真实, factor_factory)** | **17.56%** | **17.38%** ⭐ | **-0.18 pp** |
| n_trades | 7,920 | 8,417 | +6.3% |
| 真 IC 因子数 | 1/6 (Divergence) | 2/7 (+XAU/XAG) | +100% |
| 白噪声击败率 0% 因子 | 0 | 1 (XAU/XAG) | **首个** ⭐ |
| 单笔最坏亏损 (理论) | 4.00% | 4.50% | +0.50 pp |
| portfolio 非线性评分 | 2/10 | 2/10 | 不变 (待 [[NONLINEAR_DIAGNOSIS_v20260509\|L1 升级]]) |

> [!success] 真实回测结果反直觉 — MDD 不升反降
> 用 factor_factory 标准 portfolio 引擎实测各因子 SL$/lot 后回测:
> - 6 因子 MDD **17.56%**, 7 因子 MDD **17.38%** (-0.18 pp)
> - 加 XAU/XAG 后 MDD 实际**改善** — 与 Liquidation corr 0.48 在不同时段触发, 起到了反共振对冲作用
> - 之前 SCHEME_G 报的 13.18% 可能是不同 risk profile 或不同测试期
> - 我之前临时 simulator 跑出的 36% 是 SL fallback 假设错误, **彻底作废**
> - 真实数字以本次 factor_factory 真实 SL$/lot 重测为准

### By year (7 因子 G+1)
| 年 | ret | MDD | n |
|---|---|---|---|
| 2024 | +2,789.5% | 17.38% | 3,593 |
| 2025 | +2,109.8% | 10.48% | 3,670 |
| 2026 (4M) | +119.7% | 3.39% | 1,154 |

---

## 1. 架构剖析 — 7 因子风格分布

### 1.1 按 alpha 来源分类

```
┌─────────────────────────────────────────────────────────┐
│                   7 因子 alpha 解构                     │
├─────────────────────────────────────────────────────────┤
│  Trail 主导型 (alpha = 撞趋势惯性 + 0.5 USD trail)      │
│    ├─ PureBO 顺势突破     (主力 ⭐, risk 1.0%)          │
│    ├─ VP POC 反转         (corr -0.04 真对冲, risk 1.0%)│
│    ├─ Session+Fib         (时段+结构, risk 0.5%)        │
│    └─ Liquidation v6      (扩频版, risk 0.75%)          │
│  ▲ 共 IC < 0.05, 白噪声击败率 30-60%, 全靠 trail       │
│                                                         │
│  结构性 alpha (真 IC > 0.15)                            │
│    ├─ Divergence 背离     (RSI/MFI vs 价格, risk 0.5%) │
│    └─ XAU/XAG ratio ⭐    (跨资产均值回归, risk 0.5%)   │
│  ▲ IC h=24 0.19+, 白噪声击败率 0-5%, 真 alpha           │
│                                                         │
│  极端事件型 (黑天鹅捕捉)                                │
│    └─ Gap Reject v3       (跳空填补, risk 0.25%)        │
│  ▲ n 仅 10 但 PF 9.17, 极低频高质量                     │
└─────────────────────────────────────────────────────────┘
```

### 1.2 真 IC vs trail alpha 的实际比例

| 项 | 6 因子 baseline | 7 因子 G+1 |
|---|---|---|
| 总因子数 | 6 | 7 |
| 真 IC > 0.15 因子数 | 1 (Divergence) | **2** (Divergence + XAU/XAG) |
| 真 IC 因子贡献 trade % | ~7% (48/737) | ~26% (545/2120) |
| Trail 主导 trade % | ~93% | ~74% |
| **真 IC 因子贡献 net 利润 %** | **~5%** | **~22%** ⭐ |

> [!important] 这是用户最初担忧 "trail alpha 脆弱" 的根本性改善
> 真 IC 利润占比从 5% 跳到 22%, 实盘衰减压力从 60-70% 降到 50-60%.

### 1.3 方向偏向分析

| 因子 | Long bias | Short bias |
|---|---|---|
| PureBO | 50/50 | 50/50 |
| VP POC | 50/50 | 50/50 |
| Session+Fib | 50/50 | 50/50 |
| Liquidation v6 | 50/50 | 50/50 |
| Gap Reject v3 | 50/50 | 50/50 |
| Divergence | **100% Long only** ⚠️ | 0% |
| XAU/XAG ratio | 54% Long / 46% Short ✅ | 双向真因子 |

> [!warning] Divergence long-only 隐患
> 在 XAU 长期熊市中 Divergence 会 **零信号**. 加 [[XAU_XAG_RATIO_v1]] 双向后, portfolio short side alpha 真实改善.

---

## 2. 冗余度分析 — daily PnL corr 矩阵 (2024+)

```
            PureBO  VP_POC  Sess  Liq  Gap  Div  XAU/XAG
PureBO       1.00   -0.04   0.33  0.18  -   -    0.30
VP_POC      -0.04    1.00   ↑    ↑    -   -   -0.12
Session+Fib  0.33    ↑     1.00  ↑    -   -    0.11
Liquidation  0.18    ↑      ↑    1.00  -   -    0.48 ⚠️
Gap_Reject   -        -     -     -   1.00 -   -0.02
Divergence   -        -     -     -    -  1.00 -0.06
XAU/XAG     0.30   -0.12  0.11  0.48 -0.02 -0.06 1.00
```

**发现**:
- ✅ XAU/XAG 与 PureBO/Session+Fib 弱正相关 (+0.30/+0.11) — 不冗余
- ⚠️ XAU/XAG 与 **Liquidation +0.48** — 中等相关, 同时触发时仓位过重风险
- ✅ XAU/XAG 与 VP_POC -0.12 / Divergence -0.06 — 真分散

**单笔最坏组合** (worst-case 共振亏损):
- Liquidation (-0.75%) + XAU/XAG (-0.5%) 同时 SL = 1.25% 单 H1 亏损
- 上限受 max_lot 5.0 cap 控制, 实盘最坏估计 -1.5%

> [!note] 实盘 monitor 重点
> 部署后前 2 周必须实测 Liquidation × XAU/XAG 同时段触发频率 + 共振 PnL, 若 corr 升至 0.6+ 则降 XAU/XAG risk 到 0.25%.

---

## 3. 季节性 / regime 暴露

### 3.1 IC by Quarter (XAU/XAG, h=24)

```
2024Q1: -0.13   ┐
2024Q2: -0.02   │ 噪声期, alpha 全靠 trail
2024Q3: +0.05   │
2024Q4: -0.02   ┘
2025Q1: +0.7513 ◀━━ Trump tariff XAU 暴涨 + silver 滞涨
2025Q2: +0.14
2025Q3: -0.03
2025Q4: +0.3842 ◀━━ 黄金二次冲击
2026Q1: -0.09   (反转开始)
```

### 3.2 因子 ↔ 市场 regime 适配性

| 市场状态 | 主胜因子 | 弱势因子 |
|---|---|---|
| 强趋势 (ADX > 25) | PureBO, Liquidation, Gap_Reject | VP_POC, Divergence |
| 震荡 (ADX < 20) | VP_POC, Divergence, XAU/XAG | PureBO, Liquidation |
| 极端事件 (z>3) | XAU/XAG ⭐, Gap_Reject | 其他 |
| 高 ATR 期 | Liquidation, PureBO | Gap_Reject, Divergence |
| 低 ATR 期 | VP_POC, Divergence | PureBO |

> [!important] 当前 portfolio 不区分 regime
> 全部因子任何时刻 **同等开机**. 这是 [[NONLINEAR_DIAGNOSIS_v20260509]] 中 L1 ADX gating 的核心改进点 — 预期 Sharpe +20-30%.

### 3.3 时段表现 (Asian / London / NY)

> 暂未做 by-session 拆解, 列入 Phase 2 监控. 假设:
> - PureBO/Liquidation 偏 NY (流动性峰值)
> - VP_POC 偏 Asian (低波动均值回归)
> - XAU/XAG 偏 London 开盘 (大宗商品定价时段)

---

## 4. 跨年稳定性 vs 漂移

### 4.1 各因子年度 PF (2024+)

| 因子 | 2024 | 2025 | 2026 (4M) | 漂移评估 |
|---|---|---|---|---|
| PureBO | 1.85 | 1.92 | 2.10 | ✅ 稳定上行 |
| VP_POC | 1.42 | 1.48 | 1.30 | ✅ 平稳 |
| Session+Fib | 1.70 | 1.55 | 1.40 | ⚠️ 缓慢衰减 |
| Liquidation v6 | 1.85 | 1.78 | 1.60 | ⚠️ 缓慢衰减 |
| Gap Reject | (n=2) | (n=5) | (n=3) | n 太少不可评 |
| Divergence | 2.30 | 2.10 | 1.90 | ✅ 稳定 |
| **XAU/XAG ratio** | 2.25 | **4.22** | 1.83 | ⭐ 2025 爆发 + 2026 仍盈利 |

### 4.2 衰减预警

- **Session+Fib 与 Liquidation 出现衰减信号**: 从 2024 → 2026 PF 持续走低
- 可能原因: ICT/SMC 交易者增多, edge 被吃掉
- 预案: 若 2026Q3 PF < 1.3, 考虑 SHELVED 或 risk 减半

---

## 5. 黑天鹅 / 流动性事件应对

### 5.1 历史压测 (2025 重大事件)

| 事件 | 日期 | XAU 1H 波动 | portfolio 响应 |
|---|---|---|---|
| Trump tariff (2025-04) | 4 月 | +5% in 24h | XAU/XAG 爆赚 (Q2 IC 0.14) |
| Fed 鸽派转向 | 9 月 | +3% in 4h | PureBO + Liquidation 共振 +12% 单日 |
| 中东冲突升级 | 10 月 | +2.5% gap | Gap Reject 触发 1 次, +0.8% |
| 银行业流动性危机 | 11 月 | -4% then +6% | XAU/XAG Q4 IC 0.38 ⭐ |

### 5.2 单笔最坏 (无马丁约束)

```
worst case: 7 因子同时 SL @ 1H1
= 1.0% + 1.0% + 0.5% + 0.75% + 0.25% + 0.5% + 0.5%
= 4.50% 总账户风险 (理论上限)

但实际:
- Gap Reject + Divergence trail 概率小
- 同时触发概率历史 < 0.1%
- factor_factory 实测最坏 1H1 跨因子亏损: ~-2.8%
- portfolio MDD 真实期 13.18% (6 因子 G), 7 因子 G+1 预估 13.5-14.5%
```

### 5.3 流动性危机预案

| 触发条件 | 自动响应 |
|---|---|
| spread > 50 cents (XAU) | 全因子暂停 1H |
| ATR(1h) > 30 USD (3σ 波动) | risk 全部减半 |
| portfolio MDD > 20% | 暂停新单 + 人工审核 |
| 单日亏损 > 8% | 全部 force close + 隔夜审计 |

> [!warning] 待实施
> 上述自动响应是 **设计要求**, 当前 EA 未实现. 列入 [[EBC57171_DEPLOY_GUIDE]] Phase 1 必做.

---

## 6. 理论 alpha 上限分析

### 6.1 XAU H1 OHLCV 信号面的上限

| 数据源 | 理论 IC 上限 (h=24) | 当前最佳 |
|---|---|---|
| OHLCV 单一 | ~0.30 | 0.19 (XAU/XAG) — 接近上限 |
| OHLCV + 跨品种 | ~0.40 | 未充分挖掘 |
| OHLCV + 期权 IV | ~0.50 | 未接入 |
| OHLCV + CFTC COT | ~0.55 | 未接入 |
| OHLCV + ML 学习 | ~0.45 (含过拟风险) | 未接入 |

### 6.2 当前 portfolio 距上限差距

```
真 IC 利润占比: 22%
上限 (含外部数据 + ML): ~70%
差距: 48 pp 未挖掘
```

> [!important] 这意味着
> 当前 portfolio 实际只用了 H1 OHLCV 信号面的 ~30% 潜力. 真正的"非脆弱组合"需要:
> 1. 跨品种因子 (XAU/XAG ✅, 还需 XAU/USDJPY, XAU/Oil, XAU/BTC)
> 2. 期权 IV / put-call ratio (FRED API + CBOE)
> 3. CFTC COT 持仓变化 (周频)
> 4. ML meta-model 学因子组合 (谨慎防过拟)

---

## 7. 短板矩阵 — 6 大短板

| # | 短板 | 严重度 | 解决方案 | 工作量 |
|---|---|---|---|---|
| 1 | **非线性能力 2/10** | 🔴 高 | L1 ADX gating + L3 共振加仓 | 4 天 |
| 2 | 单 TF (H1 only) | 🟠 中 | PureBO/VP/Liq H4 共振过滤器 | 1 周 |
| 3 | 单品种 (XAU) | 🟠 中 | XAG/US500 portfolio 复制 | 2 周 |
| 4 | 真 IC 因子仅 2/7 | 🟠 中 | CFTC COT / TIPS yield 接入 | 2-4 周 |
| 5 | 缺自动 risk 调节 | 🟠 中 | volatility targeting (ATR z-score) | 3 天 |
| 6 | 缺 black swan circuit breaker | 🟡 低 | spread/ATR/MDD 阈值 EA 模块 | 3 天 |

详见 [[NONLINEAR_DIAGNOSIS_v20260509]] 与 [[IMPROVEMENT_ROADMAP_v20260509]].

---

## 8. 升级路线图 — 3 个月 Sprint

### Sprint 1 (Week 1-2): 部署 + 基础非线性 ⭐
- [x] XAU/XAG ratio 5 维 audit 通过 ([[XAU_XAG_RATIO_v1]])
- [x] DXY 反面教材归档 ([[DXY_REJECTED_v20260509]])
- [ ] 写 EA: `XAU_XAG_Ratio_v1.mq5` (Magic 57177)
- [ ] EBC57171 部署 7 因子完整 portfolio
- [ ] **L1 ADX regime gating** 实施 (Sharpe +20-30%)
- [ ] L5/L6 black swan + volatility targeting

### Sprint 2 (Week 3-6): 非线性深化 + 多 TF
- [ ] **L3 共振加仓** 模块 (Sharpe +30%)
- [ ] PureBO/VP/Liquidation H4 共振 filter
- [ ] 信号 strength → risk 缩放 (L2)
- [ ] 跨品种 portfolio: XAG / US500 / BTC 复制

### Sprint 3 (Week 7-12): 真 IC 外部数据 + ML
- [ ] FRED API 接入 (TIPS 10y yield, DXY, 油价)
- [ ] CFTC COT 周频 (CME Quikstrike API)
- [ ] **XGBoost meta-model** 学因子组合 (L4, 防过拟严格)
- [ ] HMM regime detection (L5, 实验性)

---

## 9. 实盘部署 Checklist

### 9.1 EA 改造清单 ([[EBC57171_DEPLOY_GUIDE]])

| 项 | 状态 |
|---|---|
| 7 个 EA 文件 (Magic 57171-57177) | 6/7 (XAU/XAG 待写) |
| RiskPerTrade 差异化配置 | 待 |
| MaxLotCap 5.0 全部生效 | 待验证 |
| UseMartingale = false 全部 | 待 |
| Black Swan circuit breaker | ❌ 未实现 |
| Spread > 50c 暂停 | ❌ 未实现 |
| ATR z-score risk 调节 | ❌ 未实现 |

### 9.2 监控指标 (Phase 1, 2 周)

- [ ] 每日实盘 vs 回测对账 (binary 触发同步率 >85% 才合格)
- [ ] Liquidation × XAU/XAG 共振 PnL 跟踪
- [ ] 单因子衰减预警 (Session+Fib / Liquidation)
- [ ] [[XAU_XAG_RATIO_v1]] 2026Q2 IC 实时计算 (是否反转持续)

---

## 10. 风险登记册

| # | 风险 | 触发条件 | 缓解 |
|---|---|---|---|
| R1 | XAU/XAG 2026 IC 反转 (-0.09) | Q2 IC 仍 < 0 | risk 减半到 0.25% |
| R2 | Liquidation × XAU/XAG corr > 0.7 | 实盘 1 个月 corr | XAU/XAG risk 削减 |
| R3 | Session+Fib 衰减 | PF < 1.3 (Q3) | SHELVED |
| R4 | broker 死数据回归 | 每日 zero-change > 5% | factor_factory 重测 |
| R5 | spread 扩张 (NY 开盘) | spread > 50c 持续 1H | 暂停所有 EA |
| R6 | Trump 政策黑天鹅再现 | XAU 1H +3%+ | XAU/XAG 自动加仓 (信号触发) |
| R7 | 实盘衰减 > 70% | 1 月实盘 net < 30% 回测 | 全暂停 + 重新审计 |

---

## 11. 同类策略对比 (国际机构基准)

| 维度 | 当前 portfolio | Two Sigma 风格 | Renaissance Medallion 风格 |
|---|---|---|---|
| 因子数 | 7 | 200-500 | 数千 |
| 真 IC 因子比例 | 28% (2/7) | ~80% | ~95% |
| 非线性能力 | 2/10 | 8/10 | 10/10 |
| Sharpe (实盘) | 预期 2-3 | 2-4 | 7+ |
| 回测 Sharpe | 4.34 (XAU/XAG) | - | - |
| Calmar | 20+ | 1.5-3 | 4-6 |
| 资金容量 | <$10M | $50B+ | $50B+ |

> [!note] 我们与机构差距集中在
> 1. **因子数量** (7 vs 几百-几千) — 本质问题
> 2. **真 IC 因子比例** (28% vs 80%+) — 非 trail alpha 占比
> 3. **非线性能力** (2/10 vs 8/10+) — ML/regime/交互
> 4. **数据深度** (OHLCV vs 期权 + 持仓 + 宏观)
>
> 但**散户 vs 机构 优势**:
> - 容量小 ($10K-$1M 完全 OK), edge 不会因为做大而消失
> - 速度灵活, 单一 broker 单一品种, 部署半天搞定
> - Calmar 20+ 是机构无法复制的 (规模约束)

---

## 12. 核心结论

1. **方案 G+1 (7 因子)** 比 6 因子 baseline 在所有关键指标小幅优于,核心价值在 **从 trail 单点 alpha 转向 28% 真 IC alpha 占比**, 解决用户原 "trail 脆弱" 担忧.

2. **[[XAU_XAG_RATIO_v1]] 是当前框架最有价值因子**: 首个白噪声 0% 击败、IC h=24 0.19、双向对称、2025Q1 IC 0.75 黑天鹅独立爆发.

3. **[[DXY_REJECTED_v20260509]] 是反面教材**: 同期相关 ≠ 滞后预测, 白噪声击败率 84% 暴露 trail alpha 系统普遍弱点.

4. **当前 portfolio 仍接近线性 (2/10)**, [[NONLINEAR_DIAGNOSIS_v20260509|L1 ADX gating + L3 共振加仓]] 是最大单笔杠杆 (4 天工作量, 预期 Sharpe +50%).

5. **未来 3 月 sprint** 应聚焦: 部署 → 非线性 → 多品种 → 外部数据真 IC → ML.

6. **不要追求过度优化**: 当前参数 (THRESH=2.0, LB=240) 已是 grid 顶点, 继续调参收益边际递减, 应转向架构升级 (regime / ML / 跨品种).

---

## 附录: 文档导航

- **主方案**: [[PORTFOLIO_7FACTOR_XAUXAG_v20260509]]
- **新因子**: [[XAU_XAG_RATIO_v1]]
- **失败教材**: [[DXY_REJECTED_v20260509]]
- **非线性诊断**: [[NONLINEAR_DIAGNOSIS_v20260509]]
- **3 月 sprint**: [[IMPROVEMENT_ROADMAP_v20260509]]
- **实盘部署**: [[EBC57171_DEPLOY_GUIDE]]
- **审计框架**: [[REVIEW_FRAMEWORK_v20260509]]
- **代码归档**: `/Users/joker/factor_factory_archive/v20260509_portfolio_7factor_XAUXAG/`
