# 价量背离反转因子 — 暂存

**生成日期**: 2026-05-08
**状态**: 2 版扫荡 (H1, H4) 全部 PF < 1, 归档

---

## 用户原规格

**行为金融学内核**: 价格创新高但成交量萎缩 = 资金撤退 → 反转

**入场（做空）：**
1. 价格创新高 (5 根 K)
2. 当前 vol < 前一个 swing high (左3右3) 的 vol × 70%
3. 阴线 close < prev K.low (确认)

**TP**: RR 1:2  | **SL**: 最高点 + 0.2 ATR

**TF**: H4 + H1

---

## 2 版扫荡

| 版本 | TF | n | WR | PF | net_pnl |
|---|---|---|---|---|---|
| **v1** | **H1** | **2,003** | 34.4% | **0.95** | -$5,661 |
| v2 | H4 | 487 | 27.9% | 0.58 | -$26,441 |

v1 PF 0.95 是**最接近 1.0 的边缘负 alpha**, 但成本侵蚀让它翻不正。
H4 升级反而 PF 跌到 0.58, 说明这个 TF 升级不救。

---

## 三因子对比 (同流派 - 反转/势头衰竭)

| 因子 | Trigger | 真实 PF | 评判 |
|---|---|---|---|
| **MACD_div** ⭐ | **MACD 直方图衰竭 (连续向量算子)** | **2.09** | 真 alpha (IC 12h 高) |
| Price-Vol Divergence (本因子) | 新高 vs 前 swing vol 70% 阈值 (离散) | 0.58-0.95 | 边缘负 alpha |
| Volume Dry Reversal | 成交量阶梯 + 止跌阳线 (离散教科书) | 0.29-0.47 | 显著负 alpha |

**等级递减规律：**
- MACD 直方图 = 连续数学算子 → 真 alpha
- 价量背离阈值 = 离散数值比较 + 阴线确认 → 边缘 (近 1.0)
- 成交量阶梯 + K 形态 = 完全教科书 → 显著负

**核心结论：trigger 越离散 + 越像 retail 教科书形态, 越接近 0/负**。MACD_div 的 alpha 本质是"对连续向量做差分检测"，而不是"看 K 线发生什么"。

---

## 调参资格 (无)

按"调参资格 4 条铁律"：

| 铁律 | 状态 |
|---|---|
| 核心 alpha PF > 1.5 | ❌ 最高 0.95 |

**没有调参资格 → 归档**。

---

## 未来重启条件

满足任一可重测：

1. **改 trigger 为 MACD-style 连续算子**:
   - 用 OBV (On-Balance Volume) 计算价量发散度
   - OBV 序列 vs 价格序列做 MACD-like 差分检测
2. **配合 MACD_div 共振**:
   - Price-Vol Divergence 触发瞬间, 检查 MACD 是否同期顶背离
   - 双 confluence 可能筛真信号
3. **改连续品种** (期货/股指):
   - tick_volume 在期货/股指上更接近真实成交量
   - XAU OTC tick 是 broker 报价次数, 跟实际资金流不强相关

---

## 文件位置

- 代码: `/tmp/price_volume_div_short_h1.py`
- 因子库 v1 H1: `Price_Volume_Divergence_Short_H1.json`
- 因子库 v2 H4: `Price_Volume_Divergence_Short_H4_v2.json`
