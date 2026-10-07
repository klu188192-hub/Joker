# VWAP-FVG Retest 趋势延续因子 — 暂存（IC 验证为假阳性）

**生成日期**: 2026-05-08
**状态**: 5 版扫荡 + IC 二次确认证伪 (IC 0.02 ≈ 随机)

---

## 5 版扫荡总结

| 版本 | TF | 关键过滤 | n | PF | net_pnl | IC 12h |
|---|---|---|---|---|---|---|
| v1 | M15 | 无 | 7,591 | 0.75 | -$34k | (未测) |
| v2 | M15 | +H1 trend+失效 | 4,720 | 0.79 | -$19k | (未测) |
| v3 | M15 | +VWAP retest | 2,291 | 0.72 | -$15k | (未测) |
| **v4** | **H1** | +H1 trend (TF 升级) | 1,114 | **1.09** | **+$5k** | **+0.021** ❌ |
| v5 | H1 | v4+Virgin VWAP | 64 | 0.65 | -$2k | (Virgin 反 hurt) |

## IC 二次确认（决定性证伪）

**v4 IC 跨 horizon 测试：**
- 5h IC: +0.035 (边缘)
- 12h IC: **+0.021** (接近 0)
- 24h IC: +0.001 (随机)

**对比真 alpha 因子（IC 12h）：**
- Gap Reject v1: **+0.598** ⭐⭐⭐
- Gap Reject v2: **+0.344** ⭐⭐
- POC Magnet: **+0.135** ⭐⭐
- **VWAP-FVG v4: +0.021** ❌ 弱 6-28 倍

**结论：v4 PF 1.09 是 1114 大样本下的统计学边缘假阳性，不是真 alpha。**

## 为什么入场择时失败

跟之前 EMA5 Pullback / RSI 反转 / Open Reversal 一致的**"教科书形态翻车"**：

| 真 alpha 因子 | 入场点性质 | 信号 IC |
|---|---|---|
| Gap Reject | "gap → fill → reject" 三阶段机构剧本 | IC 0.42-0.60 |
| POC Magnet | 5 根 K 共识区 + 大实体突破（含价格记忆）| IC 0.13 |
| **VWAP-FVG** | "VWAP 触及 + 反弹 K"（教科书指标）| **IC 0.02** |

**核心：单一指标触发 (VWAP touch + 反弹 K) 是 retail 共识 → 收割对象。机构不会在"VWAP 触及"时刻入场——这是对手盘做的事。**

## v4 trades reason 分布证据

```
TP 239 (21%)  ← 命中率仅 21%（vs Gap Reject 50-80%）
SL 486 (44%)  ← SL 主导
signal 388 (35%)  ← 早平占大头
session_close 1
```

TP 21% 远低于 RR=1:2 平衡线（33%），证明入场后价格不会延续。

## 用户原规格 vs 验证结果

用户原规格里的关键概念：

| 规格点 | 实现 | 验证 |
|---|---|---|
| FVG 检测 | ✅ 正确 | — |
| Session VWAP | ✅ 正确（UTC 日内重置）| — |
| VWAP-FVG 共振 | ✅ ±0.2 ATR 容差 | — |
| Virgin VWAP | ✅ v5 实现 | ❌ 反 hurt 95% 砍样本但 alpha 反降 |
| 失效条件 | ✅ close 穿 FVG / 收盘穿 VWAP 2K | — |
| **入场 alpha** | — | **❌ IC 0.02 = 没有 alpha** |

**实现完全忠实规格，但规格本身在 XAU 上不成立。**

## 重启条件

未来如果改造可重测：

1. **配合 Gap Reject 做 confluence 加权**（不独立触发）
   - Gap Reject 信号 + VWAP-FVG 共振 → 加大仓位
   - 但 Gap Reject 仅 10 笔/5y, confluence 命中可能 0-3 笔
2. **EA 内部 Quality_Score 加成模块**（用户原意）
   - 在 Scalper20_Pro v3 P3 基础上加 ComputeQualityScore() 第 7 维
   - 等 EA 工作流重启时执行
3. **改 stocks/期货品种**（FVG/VWAP 在股票 day trading 上更常见）

## 文件位置

- 代码 v1-v5: `/tmp/vwap_fvg_*.py`
- 因子库: `factor_library/VWAP*Confluence*.json` (KK, 5 版本)
- IC 验证脚本: `/tmp/ic_analysis_all.py`
