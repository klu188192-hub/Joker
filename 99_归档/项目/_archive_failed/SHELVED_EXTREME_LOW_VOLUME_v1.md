# 极限地量启动因子 — 暂存

**生成日期**: 2026-05-08
**状态**: 1 版扫荡 PF 0.69, 比 Silent Breakout v3 (同流派) 更差, 归档

---

## 用户原规格

**行为金融学内核**: 成交量萎缩到极致 → 所有想交易者已下场 → 一点点新资金即引爆

**地量确认**: vol 50 根 10% 分位 + 前 3K vol<SMA20×60% + BB宽度50根20%分位
**突破触发**: vol>SMA20×1.5 + body>10根均×2 + close突破BB轨

**TP**: RR 1:2  | **SL**: 突破K实体50%  | **TF**: M15+H1

---

## 1 版扫荡

| 版本 | TF | n | WR | PF | net_pnl |
|---|---|---|---|---|---|
| v1 | H1 | 193 | 34.7% | 0.69 | -$1,826 |

跟 Silent Breakout v3 (55 笔, PF 1.03) 同流派但更差。

---

## XAU 上"成交量"作为信号源的根本缺陷

XAU 是 OTC 撮合市场, **broker 提供的 tick_volume 是"报价次数"，不是"实际资金流量"**：
- 周末/节假日 vol = 0
- 流动性低时段 vol 偏低
- 跟真实买卖资金量不强相关

**所有依赖 tick_volume 阈值的因子在 XAU 上表现都差：**

| Vol-based 因子 | TF | PF | 状态 |
|---|---|---|---|
| Silent Breakout v3 | H1 | 1.03 | 边缘正 (ADX+振幅 +) |
| **Extreme Low Volume (本因子)** | **H1** | **0.69** | **边缘负** |
| Volume Dry Reversal | H1 | 0.29-0.47 | 显著负 |
| Volume Pullback Trend | M15 | 0.25 | 显著负 |
| Price-Vol Divergence | H1 | 0.95 | 边缘负 |

**对比: ADX/振幅/价格行为 维度的因子表现明显更好** (Silent Breakout 中 ADX<20+振幅条件起决定作用)。

---

## 真 alpha 因子的共同特征 (再次验证)

| 部署候选因子 | 主信号源 | 不依赖成交量阈值? |
|---|---|---|
| MACD_div | MACD 直方图 (价格-EMA 算子) | ✅ 仅价格 |
| Gap Reject v3 | gap → fill → reject 状态机 | ✅ 仅价格 |
| POC Magnet | VWAP + 大实体 (价格主导) | ⚠️ 部分 (tick_volume 中性) |

**核心: XAU 上不要依赖 tick_volume 作为主 trigger, 仅作辅助验证**。

---

## 调参资格 (无)

PF 0.69 << 1.5 → 直接归档。

跟之前 sweep 调参铁律一致: 核心 alpha 不存在则任何 SL/TP/阈值调整都救不了。

---

## 文件位置

- 代码: `/tmp/extreme_low_volume_breakout_h1.py`
- 因子库: `Extreme_Low_Volume_Breakout_H1.json` (KK)
