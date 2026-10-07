# Breakout SSL Hunt — Final Snapshot
**归档日期**: 2026-05-09
**版本**: v2 build_signal + v8 sl4/tp1 risk + 马丁+复利 final
**状态**: 部署候选 (Tier C 边缘 alpha + 马丁红利 +56% 修正后)

---

## 因子核心

**Build signal (v2):**
- H1 上 fractal(L=3,R=3) swing high/low 监控
- pin bar SSL hunt: low 刺破 swing low + close 收回 + lower_wick > body × 1.5
- 突破: close > swing_high + body > 0.5 ATR + 阳线
- 双向（做多+做空对称）
- ffill 12 H1

**真实数据范围**: 2023-09 → 2026-05 (~2.58 年, 因 2021-2023 broker 数据 96% 死)

---

## 单品种基线表现

| symbol | n | WR | PF | net | MDD% | IC (4h) | IC (24h) |
|---|---|---|---|---|---|---|---|
| XAUUSD.s (sl4/tp10/trail1USD) | 327 | 73.1% | **1.929** | $15,046 | 12.3% | 0.06/0.11 | 0.024/**0.142** |
| USDJPY.s (sl4/tp1, 无 trail) | 271 | 77.9% | 1.343 | $6,379 | 19.0% | **0.114/-0.05** | 0.075/**0.141** |

⚠️ JPY contract_size 用 667 (= 100,000/150) 因 USDJPY pip_value 不能直接用 100,000。

---

## Portfolio (XAU + JPY)

- 598 trades / 2.58 年 = **0.63 单/日**
- WR **75.3%**
- PF **1.616** ⭐ 突破 1.5 调参资格线
- 基线 net (lot 0.1/1.0): **$21,425 (+214.2%)** vs 单 XAU $4,772
- 最大连亏 **6 笔**
- 单笔最坏 9.3% 账户 (无马丁)

---

## 马丁红利 (fixed lot baseline)

| 配置 | net | uplift | MDD% | 单笔最坏 | 实盘可行 |
|---|---|---|---|---|---|
| baseline | $21,425 | — | 16.9% | 9.3% | ⭐⭐⭐ |
| **mul1.5 cap2.25** | $33,395 | **+56%** | 30.9% | 11.5% | ⭐⭐⭐ 推荐 |
| mul1.5 cap4 | $41,528 | +94% | 45.3% | 22.1% | ⭐⭐ 平衡 |
| mul1.5 cap8 | $46,530 | +117% | 65.4% | 33.2% | ⚠️ |
| mul2.0 cap8 | $61,473 | +187% | 83.1% | 55.0% | ❌ |
| **mul2.5 cap∞** | $226,530 | +957% | **429%** | **539%** | ☠️ 必爆仓 |

---

## 复利 + 马丁 grid (推荐部署级别)

| risk | 配置 | net | CAGR | MDD | 单笔最坏 |
|---|---|---|---|---|---|
| 0.5% | mul1.5 cap2.25 | $6,980 | 22.7% | 6.4% | 2.6% |
| **1.0% ⭐** | **mul1.5 cap2.25** | **$18,216** | **49.4%** | 12.5% | 5.1% |
| 1.5% | mul1.5 cap2.25 | $36,362 | 81.0% | 18.3% | 7.7% |
| 2.0% | mul1.5 cap2.25 | $64,075 | 117% | 23.8% | 10.2% |

**首选配置 (平衡档)**:
```
risk_per_trade_pct = 1.0%
multiplier         = 1.5
cap                = 2.25
recover            = pending_loss 清零后 multiplier 复位 1.0
compound           = enabled (按 current_equity 重算 base_lot)
```

---

## 关键诊断

### 1. R:R 平衡问题（XAU 已修复）

原 v8 sl4/tp1 配置 reason 分布:
- TP (拿 1 ATR): 217 单 / 100% WR / +$21,680 总盈
- SL (扛 4 ATR): 14 单 / 0% WR / -$5,810 总损
- **signal 反向出: 90 单 / 13% WR / -$11,098 总损 ← 真凶**

修复: 改用 sl4/tp10/trail1USD → PF 1.275 → 1.929 (+51%)
JPY 不能复用此 trail (1 USD trail 对 JPY 太宽), 保留原 sl4/tp1.

### 2. 马丁红利瓶颈 = RR 不是频率

实测对比 (相同 PF ~1.3):
| 风格 | WR | RR | mul1.5 cap2.25 红利 | mul1.5 cap∞ 红利 |
|---|---|---|---|---|
| 高WR低RR (v8) | 71% | 0.51 | +96% | +256% (实盘安全) |
| 低WR高RR (v2 trail) | 57% | 1.05 | +52% | **+11,640%** (但 MDD 19,062% 必爆) |

**结论**: 71% WR + RR 0.51 让"1.5x lot win 只能 cover 0.77 个 base loss" → 单 win 不能翻盘 → 马丁红利上限有限.
真正"指数级"需要 RR ≥ 1.0 + cap ≥ 4 + 接受 MDD 50%+ (跟"安全"冲突).

### 3. 数据质量警告

XAU.s_H1.csv 2021-2023 段 broker 数据 96% 是 zero-change (死填充).
**所有 5 年回测实际只有 2024+ 的 ~2.5 年真数据**.
build_signal 第一笔 entry 在 2023-09-25, 此前数据无效.

### 4. IC 跨年衰减

XAU 4h IC: 2023 +0.10 / 2024 +0.06 / **2025 -0.03** / 2026 +0.17
JPY 4h IC: 2024 +0.12 / 2025 +0.11 / **2026 -0.06**

部分时段 alpha 翻转 → 实盘需 monitor 月度 IC, 转负持续 ≥ 2 月 暂停.

---

## 文件清单

### 代码 (build_signal 演化)
- `code/breakout_ssl_hunt_h1_v2.py` ← 当前部署版 (核心)
- `code/breakout_ssl_hunt_h1_v4.py` (v2 + EMA200 trend filter, 无优势已弃)
- `code/breakout_ssl_hunt_h1_v6.py` (4-段 retest, 失败)
- `code/breakout_ssl_hunt_h1_v7.py` (2-K hold, 失败)

### 回测脚本
- `scripts/portfolio_martingale_grid.py` (4 品种 portfolio 初筛, 发现 EUR/GBP PF<1)
- `scripts/martingale_pure_uplift.py` (剥离复利, 看马丁纯红利)
- `scripts/check_rr_balance.py` (诊断 R:R 与 trailing 平衡, 发现 signal close 真凶)
- `scripts/final_portfolio_marti.py` (最终部署版 + risk 矩阵)
- `scripts/ic_and_marti_extreme.py` (IC 测试 + 极端 mul/cap grid)
- `scripts/marti_diagnosis_freq_vs_rr.py` (诊断 RR 是瓶颈)

### Engine 修改 (KK 上)
- `C:/Tools/factor_factory/backtest/engine.py` 加了 `trailing_fixed_usd` 参数
- `C:/Tools/factor_factory/scripts/add_factor.py` 加了 `--trailing-fixed-usd` CLI
- 备份在 `C:/Users/Administrator/factor_factory_archive/v20260509_pre_trailing_fixed_usd/`

---

## 实盘部署清单

- [ ] MQL5 EA 实现 build_signal 状态机 (fractal+pin bar+突破)
- [ ] EA 风控参数 = 上述"首选配置"
- [ ] 多品种部署 (XAU + USDJPY) on IC Markets VPS
- [ ] 月度 IC 监控 (4h horizon, 转负 ≥ 2 月暂停)
- [ ] MDD 触发熔断 (单账户 MDD > 25% 暂停回顾)
- [ ] Hermes Agent 推 OPEN/CLOSE 到 monitor_ebc3

---

## 不要做的事

- ❌ 加 EMA200 trend filter (v4 实测降表现)
- ❌ 加 retest 段 (v6 失败)
- ❌ 加 2-K hold 段 (v7 失败)
- ❌ 把 EUR/GBP 加进 portfolio (PF < 1, 拖累整体)
- ❌ cap > 4 (单笔风险 > 22%, 黑天鹅风险)
- ❌ mul > 2 + cap > 8 (实盘必爆)
- ❌ cap = ∞ (任何 mul, 数学上 100% 终将归零)
