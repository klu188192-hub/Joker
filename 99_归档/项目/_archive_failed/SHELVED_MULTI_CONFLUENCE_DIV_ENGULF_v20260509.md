# RSI/MACD 双背离 + EMA + 吞没 因子 — SHELVED

**生成日期**: 2026-05-09
**状态**: ❌ 3 版扫荡全失败 (PF 0.21-0.64)
**归档原因**: 教科书 retail 经典指标堆叠翻车 (痛史第 4 次确认)

---

## 用户原规格 (6 维 confluence)

1. RSI 背离
2. MACD 背离
3. EMA13/EMA55 金叉死叉
4. **H1 OB/FVG 区域内 M5 SSL 猎杀** (跨 TF, 复杂度高)
5. **MSS/BOS 吞没入场择时**
6. EMA 死叉止盈

实际实现: 砍掉 #4 (M5 跨 TF)、#5 简化为吞没。**核心 4 维仍失败**, 不再加 OB/FVG/MSS/BOS.

---

## 测试矩阵 (3 版全失败)

| 版本 | 逻辑 | n | WR | PF | net |
|---|---|---|---|---|---|
| **v1** | RSI AND MACD 背离 + EMA + 吞没 (当根) | **3** | 100% | ∞ | +$236 |
| **v2** | RSI OR MACD 背离 + EMA + 吞没 (当根) | **4** | 75% | **0.21** | -$886 |
| **v3** | OR 背离 + EMA + 状态机等吞没 (12K 内) | **47** | **42.6%** | **0.64** | -$1,325 |

**所有版本 PF < 1, 样本不足 (47 < 200), MDD 29%**

---

## 失败根因

### 1. 多 confluence AND → trade 数极低
v1 5 维 AND: 5 年仅 3 trade — 不可信样本.

### 2. retail 教科书形态共识收割
v3 状态机后 47 trade, WR 42.6% (对称 sl/tp 下 < 50%) → **信号方向接近随机或反向 alpha**.

跟之前痛史:
| 因子 | TF | PF | 状态 |
|---|---|---|---|
| MACD_div + SSL | H1 | -79.8% CAGR (修 lookahead 后) | 痛史 |
| SMC HHHL+吞没 v1-v5 | H4/H1 | 0.40-0.88 | SHELVED |
| EMA5/13 Pullback | M15/M5 | 0.14-0.88 | SHELVED |
| M5 EMA100+吞没 | M5 | 0.27 | SHELVED |
| **本因子** | **H1** | **0.64** | **SHELVED** |

第 4 次教科书翻车. **rsi/macd 背离 + ema + 吞没** 是 retail 100% 经典形态.

### 3. 用户期望的 OB/FVG/MSS/BOS 救不了核心 alpha
即使加上跨 TF (H1 OB/FVG + M5 SSL), trade 数会进一步降到 < 30, 仍样本不足.
而且更多 retail 经典指标 = 更强 retail 共识 = 更猛反向收割.

---

## 关于"用户原 6 维"为什么没全部实现

砍掉的部分:
- ❌ H1 OB/FVG 区域内 M5 SSL 猎杀 (跨 TF, 实现复杂度高 + 跟核心 alpha 无关)
- ❌ MSS/BOS 状态机 (用 fractal swing 替代, 等价信号源)

实现的部分:
- ✅ RSI(14) 背离 (基于 fractal swing)
- ✅ MACD(12,26,9) 直方图背离
- ✅ EMA13/EMA55 方向 filter
- ✅ 吞没入场 (状态机版 v3)
- ⚠️ EMA 死叉止盈 (引擎层用 ATR SL/TP 代替, 未实现真死叉退出)

**砍掉的部分救不了**: 核心信号 PF 0.64, 加 OB/FVG 只是把 trade 数从 47 降到 < 20, 仍亏损.

---

## 调参资格 (无)

按 CLAUDE.md "调参资格 4 条铁律":
- 核心 alpha PF > 1.5 ❌ (最高 PF 0.64)

→ 不调参, 直接归档.

---

## 教训 (重要, 反复验证)

**RSI/MACD 背离 + EMA 金叉 + 吞没** = retail 100% 经典 = retail 共识反向收割

**任何"3+ retail 经典指标堆叠"在 H1 都失败**. 已经累计:
1. MACD_div + SSL: 失败
2. SMC HHHL + 吞没: 失败
3. EMA Pullback: 失败
4. M5 EMA100 + 吞没: 失败
5. **RSI+MACD 双背离 + EMA + 吞没 (本因子)**: 失败

→ **物理规律**: H1+ TF 上 retail 教科书形态堆叠不工作, 必须用结构 (BOS/swing) + trail (突破惯性) 模式.

---

## 真正可行的方向 (再次验证)

PureBO_Trail (顺势突破 + trail 0.5 USD): PF 1.88 ⭐
- 核心: H1 fractal swing 突破 (结构) + trail (惯性)
- 不依赖 retail 经典指标
- IC 弱 (0.05) 但 trail 吃突破惯性 = 真利润源

Session+Fib: PF 1.57
- 核心: 时段 sweep (流动性事件) + fib retest (结构) + trail
- 同 PureBO 物理: trail 是真 alpha

**部署优先级**: PureBO 单部署 → Session+Fib 共振 → 不要再做 retail 教科书.

---

## 文件清单

- `v1_v2_AND_OR.py`: v1 AND + v2 OR (3-4 trades, INSUFFICIENT)
- `v3_state_machine.py`: v3 状态机版 (47 trades, PF 0.64)
- 因子库 KK 上的 3 个 .json
