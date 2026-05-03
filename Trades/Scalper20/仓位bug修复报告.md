---
date: 2026-05-03
author: TT (Claude)
severity: CRITICAL
ea: Scalper20
file: D:\EBC-2\MQL5\Experts\Scalper20.mq5
tags: [bug-report, position-sizing, risk-management]
---

# Scalper20 仓位计算 Bug 完整溯源

## TL;DR

**v0.24 的 +$13,350 盈利建立在仓位计算 bug 上。** 配置写的 1% 风险/笔，实际承受 **4.35%/笔**（4.35× 杠杆）。修复 bug 后**盈利会归零**——必须同时调高 R/R 才能保持盈利。

---

## 一、Bug 现场（代码定位）

### 异常触发链

文件：`D:\EBC-2\MQL5\Experts\Scalper20.mq5` v0.24

**步骤 1 — `ArbitrateAndExecute()` 计算手数**：

```mql5
// Line ~1042 (v0.24)
double sl_pts_raw = NPoints(MathAbs(price - pick.sl_price));   // 信号自带 SL 距离
double atr_cap_pts = (InpSLATRMultiplier * s.atr) / g_point;   // 1.5 × ATR cap
double sl_pts = MathMin(sl_pts_raw, atr_cap_pts);              // 取小者
double lots = CalcLotSize(risk_pct, sl_pts);                   // ← 用这个算 lot
```

**步骤 2 — `OpenTrade()` 实际下单时覆盖了 SL**：

```mql5
// Line ~466 (v0.24)
if(InpUseFixedSL) {
   sl_pts = InpFixedSL_USD / g_point;   // ← 实际 SL 是固定 $10
   tp_pts = InpFixedTP_USD / g_point;
}
// ...
double sl = price - sl_pts*g_point;    // 实际放置在 $10 远的位置
g_trade.Buy(lots, _Symbol, price, sl, tp, tag);
```

### 数学剖析

假设 XAUUSD M5：
- 信号 A1 自带 SL 距离 ≈ 0.5-3 USD（bar low - 1 pip）
- 1.5 × ATR cap ≈ 1.5-4.5 USD
- `sl_pts` (用于算 lot) ≈ **2.3 USD** 平均
- `InpFixedSL_USD` (实际 SL) = **10 USD**

CalcLotSize 内：
```
lots = (balance × risk%) / (sl_pts × point_value)
     = ($10,000 × 1%) / ($2.3 × $1)
     = $100 / $2.3
     ≈ 0.43 lot
```

但实际 SL 在 $10 处。如果 SL 触发：
```
loss = lots × $10 × 100 = 0.43 × $1000 = $430
```

**实际亏损 = $430，配置预期 $100，膨胀 4.3×**

回测数据验证：v0.24 平均亏损 = **$435.24** ✓ 完全吻合

---

## 二、为什么 v0.24 仍然盈利？

虽然每笔风险膨胀到 4.35%，但 PF 仍 1.20：

| | nominal | 实际 |
|---|---|---|
| TP 距离 | $5 | $5 |
| SL 距离 | $10 | $10 |
| nominal R/R | 0.5 | 0.5 |
| **实际 R/R** | — | **0.69** |

实际 R/R > nominal R/R 的原因：
- 不同信号 SL 自带距离不同 → lot 不同 → 单笔金额不同
- 部分赢单可能略超 TP（slippage）
- 部分亏损单未到满 SL（很罕见，因为没有 trailing/time exit）

**关键数学**：
- nominal R/R = 0.5 → 平衡 WR = 1/(1+0.5) = **66.7%**
- 实际 R/R = 0.69 → 平衡 WR = 1/(1+0.69) = **59.2%**
- 当前 WR = **63.44%** → 在 0.69 R/R 下盈利，在 0.5 R/R 下亏损

---

## 三、修复后会发生什么

### 修复方案

```mql5
// 修复后 (v0.25)
double sl_pts;
if(InpUseFixedSL) {
   sl_pts = InpFixedSL_USD / g_point;   // ← 用实际 SL 距离算 lot
} else {
   sl_pts = MathMin(sl_pts_raw, atr_cap_pts);
}
double lots = CalcLotSize(risk_pct, sl_pts);
```

### 修复后的预测（保持 SL=$10 / TP=$5 不变）

- lots 缩到 **0.10**（真实 1% 风险）
- 平均亏损 = $100（精确 1%）
- 平均盈利 = ~$50（TP $5 × 0.10 lot × 100 = $50）
- 实际 R/R 回到 **0.5**（nominal）
- WR 仍 63.44% → 期望 = 0.6344×$50 - 0.3656×$100 = **-$4.84/笔**
- **盈利归零，反而亏损！**

### v0.25 选定方案：修 bug + 调 R/R 到 1.5

- SL = $10 / TP = $15 (1:1.5)
- 平衡 WR = 1/(1+1.5) = **40%**
- 当前 WR 63.44% → 大幅超过门槛
- 但 TP 变远 → 实际 hit rate 可能下降，WR 会降
- 最终 PF 取决于真实 WR 在 R/R=1.5 配置下的表现

---

## 四、迭代回测全记录

| 版本                    | 关键改动                       | 净盈亏          | WR         | 实际 R/R   | DD         | 期望/笔        | 备注                 |
| --------------------- | -------------------------- | ------------ | ---------- | -------- | ---------- | ----------- | ------------------ |
| v0.11 baseline        | 用户 spec 全套                 | -$6,720      | 54.13%     | 0.69     | 67.99%     | -$3.02      | 起点                 |
| v0.12                 | nominal R/R 0.5→1.5        | -$7,148      | 44.14%     | 1.04     | 71.67%     | -$3.35      | 失败                 |
| v0.13                 | + 关时间止损                    | -$7,890      | 37.33%     | 1.50     | 82.81%     | -$3.88      | 灾难                 |
| v0.14                 | 智能时间止损 + trailing + BE     | -$6,578      | 60.98%     | 0.52     | 66.82%     | -$2.95      | 改善                 |
| v0.16                 | SL ATR cap 1.5→1.2         | -$6,747      | 60.05%     | 0.55     | 69.85%     | -$3.05      | 退步                 |
| v0.17                 | 删 4 劣信号                    | -$5,520      | 61.77%     | 0.52     | 55.89%     | -$2.78      | 改善                 |
| v0.18                 | 阈值中和                       | -$5,458      | 62.24%     | 0.51     | 55.51%     | -$2.73      | 微改善                |
| v0.19                 | trailing pullback 0.5→0.35 | -$5,425      | 62.27%     | 0.51     | 55.71%     | -$2.72      | 顶                  |
| v0.20                 | nominal R/R 0.7            | -$5,710      | 62.67%     | 0.49     | 58.10%     | -$2.85      | 退                  |
| v0.21                 | 关 trailing/BE, TP 10×SL    | -$5,710      | 62.67%     | 0.49     | 58.10%     | -$2.85      | 同 v0.20            |
| **v0.24 (A1+A3 真组合)** | **仅 A1+A3, 固定 SL/TP**      | **+$13,350** | **63.44%** | **0.69** | **47.48%** | **+$32.32** | **首次盈利 ⚠️ 但带 bug** |
| **v0.25 (新 baseline)** ⭐ | **修仓位 bug + R/R 调 1.5**  | **+$1,920**  | **48.66%** | **1.19** | **11.61%** | **+$4.67**  | **首个真实 1% 风险盈利** |

### 五.五、v0.25 实测验证

修复后的预测全部命中：

| 指标 | 修复前预测 | 实测 | 验证 |
|---|---|---|---|
| 实际 R/R | ~0.5 (nominal) → 1.5 | **1.19** | ✓ TP 变远 hit rate 下降, R/R 介于 0.5-1.5 |
| 胜率 | 不变 63% 或下降 | **48.66%** | ⚠️ 比预测降更多, 因 TP $15 触发率显著低 |
| DD | 大幅降 | **11.61%** | ✓ 真实 1% 风险下 DD 自动减 4× |
| 期望/笔 | 微正 | **+$4.67** | ✓ 平衡门槛 45.6% < 实际 48.66% |
| 净盈利 | 微正 | **+$1,920** | ✓ 411 笔 × $4.67 |

**关键发现**：v0.24 的 +$13,350 假盈利里，**有 ~$11,400 来自 bug 杠杆**，真实策略盈利能力只有 **$1,920**（贡献 14.4%）。

**v0.25 是新的合法起点**——后续所有迭代以此为 baseline，PF 1.13 不可退步。

---

## 五、Bug 历史溯源

**bug 引入版本**：v0.22（2026-05-03）

引入原因：在做 20 信号 sweep 时为了快速测试，在 OpenTrade 加了 `if(InpUseFixedSL) { sl_pts = ... }` 覆盖逻辑，**忘记同步 ArbitrateAndExecute 的 lot 计算**。

```diff
// v0.22 OpenTrade
+ if(InpUseFixedSL) {
+    sl_pts = InpFixedSL_USD / g_point;  // ← 新增
+    tp_pts = InpFixedTP_USD / g_point;
+ } else { ... }

// v0.22 ArbitrateAndExecute
  double sl_pts = MathMin(sl_pts_raw, atr_cap_pts);  // ← 没改, 仍用信号 SL
  double lots = CalcLotSize(risk_pct, sl_pts);
```

**未及时发现的原因**：
1. sweep 测试时每个信号单独跑，PF 各异看似正常（A1 PF 1.19 / A3 PF 2.05）
2. avg_loss 异常大（$423 vs 预期 $100）当时被解读为"高 R/R 信号"，未质疑根因
3. 直到 v0.23 组合测试 + v0.24 残留 .set 文件混淆，才暴露 bug

---

## 六、修复决策

| 选项 | 描述 | 风险 | 推荐？ |
|---|---|---|---|
| A | 不修 bug，加保本止损降 DD | 实盘超杠杆爆仓 | ❌ |
| **B** | **修 bug + 调 R/R 1.5 (v0.25 本次)** | **真实风险, TP hit rate 待验证** | ✅ TT 推荐 |
| C | 修 bug + 用 trailing 取代固定 TP | 复杂度高, 见 v0.14 经验 | ⏸️ 备用 |

---

## 七、教训（写入项目记忆）

1. **lot 计算和 SL 放置必须用同一个距离**——任何"覆盖路径"都要同步两侧
2. **参数测试用 `.set` 文件**容易遗留——每次 sweep 后必须主动删除
3. **avg_loss 异常大 ≠ 高 R/R 信号**——必须验证 lot 大小是否合理
4. 表面盈利不等于真实盈利——**先看实际风险，再看 PF**
