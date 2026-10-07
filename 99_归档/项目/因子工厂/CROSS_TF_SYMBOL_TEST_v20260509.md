---
title: 跨 TF / 跨品种实测 — XAU H4 是真扩展, XAG/BTC 需重设计
date: 2026-05-09
test_period: "2024-01 - 2026-05"
status: completed
tags:
  - 量化
  - 跨TF
  - 跨品种
  - 测试报告
related:
  - "[[INTEGRATED_ANALYSIS_v20260509]]"
  - "[[PORTFOLIO_7FACTOR_XAUXAG_v20260509]]"
  - "[[NONLINEAR_DIAGNOSIS_v20260509]]"
---

# 跨 TF / 跨品种实测报告

> [!warning] 重要发现
> ✅ **XAU H4 多 TF 真有价值** (PureBO H4 PF 2.009 / Sharpe 3.42 比 H1 还好), 应加入 portfolio
> ❌ **XAG/BTC 直接照搬完全失败** (XAG H1 CAGR -71%, BTC 100% 爆仓), 不能直接复制
> ⚠️ 跨品种**必须重新调参**, 不是简单换数据就行

## Portfolio Summary 全表

| symbol/TF | CAGR | MDD | Sharpe | final eq | 决定 |
|---|---|---|---|---|---|
| **XAU H1** (基准) | 1,378% | 17.56% | 5.23 | $5.35M | ✅ 主力 |
| **XAU H4** ⭐ | **697%** | **24.52%** | **3.15** | $1.25M | ✅ **加入 portfolio** |
| XAG H1 | -71% | 99.36% | -0.19 | $553 | ❌ 拒绝 |
| XAG H4 | 127% | 70.60% | 0.89 | $66,048 | ❌ MDD 太高 |
| BTC H1 | -100% | 100% | -18.76 | $0 | ❌ 完全爆仓 |
| BTC H4 | -100% | 100% | -12.05 | $0 | ❌ 完全爆仓 |

## XAU H4 — 多 TF 子集详细

| 因子 | n | WR | PF | MDD | Sharpe | net |
|---|---|---|---|---|---|---|
| **PureBO H4** | 801 | **78.0%** | **2.009** | 12.76% | **3.42** ⭐ | $84,529 |
| VP_POC H4 | 777 | 71.9% | 1.599 | 27.69% | 2.30 | $54,932 |
| Liquidation H4 | 353 | 66.6% | 1.545 | 28.51% | 2.38 | $19,577 |
| Divergence H4 | 10 | 70.0% | 1.386 | 3.05% | 2.14 | $123 |

> [!success] PureBO H4 比 H1 还好
> H1: PF 1.914, WR 75.4%, Sharpe 3.22
> **H4: PF 2.009, WR 78.0%, Sharpe 3.42** ⭐
> 频率比 H1 低 4x (n=801 vs 2955), 但单笔质量更高.
> 适合作为 H1 的**共振过滤器**或**独立子 portfolio**.

### XAU H4 推荐加入策略

**方案 A: H4 共振 filter** (与 H1 PureBO 同向时入场)
- 不增加额外 trade 数量
- 砍掉 H4 反向时的 H1 PureBO 入场 (估计 -30% 频率)
- 预期 PF 1.914 → 2.2+, Sharpe +20-30%

**方案 B: H4 独立子 portfolio** (Magic 57181-57184)
- 增加 4 个独立 EA (PureBO H4, VP_POC H4, Liquidation H4, Divergence H4)
- 总单笔风险 +0.5-1.0% (各 0.25%)
- 频率独立, 与 H1 corr 待测

**方案 C: 不加** (维持现 7 因子)
- 简化部署, 避免引入新 H4 corr 风险

**推荐**: **方案 A** 先做, 实测 1 月后再决定是否做 B.

## XAG 失败原因分析

### 数字
| 因子 | XAG H1 PF | XAU H1 PF | 差异 |
|---|---|---|---|
| PureBO | 0.956 | 1.914 | -50% |
| VP_POC | 0.684 | 1.432 | -52% |
| Session_Fib | 0.747 | 1.615 | -54% |
| Liquidation | 1.060 | 1.824 | -42% |
| Gap_Reject | 0.228 | 9.174 | -97% |
| Divergence | 0.118 | 2.207 | -95% |

### 根因

1. **价格量级不同**: XAU $2,500 vs XAG $25 (100x)
2. **波动率结构不同**: XAG 波动率比 XAU 高 2-3x, 但绝对 USD 移动小
3. **R/R 比错位**: 我们的 SL 4 ATR / TP 1 ATR 在 XAG 上无效
4. **流动性结构**: XAG 没有 Asian session 黄金时段
5. **跨资产因子无意义**: XAU/XAG ratio 在 XAG 上等于反向自己, 不是真信号

### 复活路径 (需重新设计)

| 调整 | 备注 |
|---|---|
| SL_ATR: 4.0 → 6.0 (XAG 波动大) | 减少假 SL |
| TP_ATR: 1.0 → 1.5 (扩大 TP 窗口) | 抗噪声 |
| Lookback: H1 24 → 48 (XAG 需更长趋势确认) | |
| 取消 Gap_Reject 因子 (XAG 无周末 gap) | |
| 重设计 XAU/XAG 反向 (变成 XAG/XAU = silver/gold ratio) | 同思路 |

## BTC 完全失败 — 不要尝试

### 数字
```
PureBO BTC H1: WR 2.4%, PF 0.003, MDD 17,784% (爆仓)
VP_POC BTC H1: WR 2.0%, PF 0.002 (爆仓)
Session_Fib BTC: WR 1.7% (Asian 在 BTC 无意义)
```

### 根因

1. **BTC 24/7 交易**: 没有传统 session 概念
2. **极端波动**: 单 H1 ATR 可能 $1,000+, 4 ATR SL = $4,000/lot
3. **价格量级**: BTC $80K, 0.1 lot = $8K 名义敞口, 单笔 SL $400 (4% 损失)
4. **结构完全不同**: 没有 ETF/期权对冲, 流动性来源单一
5. **传统因子完全不适用**: PureBO/VP_POC 是基于 mean reversion + breakout 假设, BTC 是趋势失效市场

### 不应该尝试的理由

- 现有 6 个因子全部 WR < 6%, 完全无效
- 不是调参能解决, 是**思路本质不同**
- BTC 量化需要专门做 (如机器学习 / on-chain 数据 / 杠杆周期)

## 最终决策

| 扩展方向 | 决策 | 理由 |
|---|---|---|
| **XAU H1 (现状)** | ✅ 主力 | 已部署 |
| **XAU H4 共振 filter** | ⭐ 推荐方案 A 实施 | PureBO H4 PF 2.009 真有价值 |
| **XAU H4 独立子 portfolio** | ⏸ 实测 1 月后决定 | 避免过早扩张 |
| **XAG portfolio** | ❌ 暂停 | 需要重新调参, 优先级低 |
| **BTC portfolio** | ❌ 永久放弃 | 现有因子根本不适用 |
| US500 portfolio | ⏸ 数据未下载 | Phase 2 考虑 |

## 实施 checklist

### Phase 1 (1 周内)
- [ ] 写 EA 加 H4 PureBO 共振 filter 模块
- [ ] 实测 H1 PureBO 与 H4 PureBO 同向重叠率
- [ ] 验证砍掉反向时段的 PnL 影响

### Phase 2 (2-4 周, 可选)
- [ ] 重新调参 XAG (SL/TP/lookback)
- [ ] 下 US500 数据测试
- [ ] 评估 H4 独立子 portfolio 价值

### Phase 3 (永久放弃)
- ❌ BTC

## 参考

- 主方案: [[PORTFOLIO_7FACTOR_XAUXAG_v20260509]]
- 整体性分析: [[INTEGRATED_ANALYSIS_v20260509]]
- 非线性诊断: [[NONLINEAR_DIAGNOSIS_v20260509]]
- 测试代码: KK 上 `C:/Tools/factor_factory/scripts/cross_tf_symbol_test.py`
