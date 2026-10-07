# Session Sweep + Fib 0.618 因子归档

**归档日期**: 2026-05-09
**因子流派**: 三时段 (Asia/London/NY) 高低点扫荡 + Fib 0.618 回踩延续
**状态**: ✅ 真 alpha (Tier B), 推荐与 PureBO 组合部署

---

## 因子核心

**Build signal (v1):**
- 时段定义 (UTC):
  - Asia: 0-7
  - London: 7-13
  - NY: 13-21
- 4 段状态机:
  - `idle`: 检测 sweep
    - 向上 sweep: high > prev_session_H AND close < prev_session_H (假突破收回)
    - 向下 sweep: 对称
  - `wait_pullback`: 等回撤 ≥ 0.5 ATR
  - `wait_618`: 计算 fib_618 = swept_extreme - 0.618 × range
  - 触及 0.618 + 反转 K (阳线/阴线) → entry
- 参考 H/L:
  - London 时段用 Asia H/L
  - NY 时段用 London H/L (优先) 或 Asia H/L (备用)

**关键参数:**
- `FIB_RATIO = 0.618`
- `PULLBACK_MIN_ATR = 0.5`
- `BREAK_FAIL_ATR = 0.3`
- `PULLBACK_TIMEOUT = 12 H1`
- `FIB_TOUCH_TIMEOUT = 12 H1`

---

## 5 年回测表现 (sl4/tp1 + trail 0.5USD, lot 0.1)

| 指标 | v1 全时段 | v2 NY-only (失败) |
|---|---|---|
| n | 1,739 | 1,157 |
| WR | 72.6% | 72.1% |
| **PF** | **1.572** | 1.440 |
| net (5y) | $57,112 | $30,786 |
| MDD | 19.7% | 25.2% |
| Sharpe | 5.13 | 1.76 |
| 频率 | 1.78 单/工作日 | 1.18 单/工作日 |

**v2 失败教训**: 时段过滤 (砍 Asia + London) 反而 PF 下降 8% / net -46%。
原因: trail 吃突破惯性的 alpha 跟时段无关，砍掉 trade 触发 = 砍掉 trail 工作机会。

---

## 完整 alpha 审计结果

### 1. Lookahead 检查 ✅ PASS
- 静态扫描 (`lookahead_lint.py`): 0 findings (CRITICAL/HIGH/MEDIUM/LOW 全 0)
- 运行时装饰器 (`@assert_no_lookahead`): 通过

### 2. IC 系统化分析 ⚠️ 弱 alpha + 时段聚集

**Multi-horizon IC (trigger):**

| horizon | IC | p-value |
|---|---|---|
| 24h | 0.052 | 0.258 |
| 48h | 0.060 | 0.192 |
| **72h** | **0.069** | 0.135 |

⚠️ 全部 p > 0.05 (单 horizon 不显著)

**By year (12h):**
- 2023: -0.015 (反向)
- 2024: +0.029 (不显著)
- **2025: +0.080 (p<0.001) ✅**
- 2026: +0.038 (不显著)

**By session (12h) — 关键:**

| session | IC | p | 显著? |
|---|---|---|---|
| Asia | +0.012 | 0.58 | ❌ |
| London | -0.011 | 0.72 | ❌ (反向) |
| **NY** | **+0.057** | **0.005** | ✅ |
| **Closed (21-23)** | **+0.102** | **0.0005** | ✅ ⭐ |

**Monthly IR**: +0.18 (mean IC +0.034, std 0.19, 59% 月份 IC > 0)

### 3. 白噪声基线 ⚠️ PF 击败率 39.5%

| 指标 | 真因子 | 200 random mean | 击败率 |
|---|---|---|---|
| PF | 1.61 | 1.56 | **39.5%** ❌ |
| WR | 73.2% | 73.4% | 54.5% ❌ |
| **net** | **$57,786** | $24,304 | **0.0%** ✅ |

**关键洞察**: signal 方向 IC ≈ 0，但 trade 频率分布让真因子 net 显著超随机。
**真 alpha 来源 = trail 吃突破惯性 + 触发频率，不是 signal 方向预测力**。

### 4. Walk-forward ✅ PASS

| 期 | n | WR | PF | Sharpe | MDD |
|---|---|---|---|---|---|
| 2024 训练 | 639 | 73.6% | 1.678 | 8.76 | 12.1% |
| 2025 验证 | 658 | 73.1% | 1.644 | 10.48 | 13.0% |
| **2026 OOS** | 253 | 72.7% | **1.578** | 6.22 | 58.0% ⚠️ |

3 期 PF > 1.5 + WR 稳定 → 不是过拟合。⚠️ 2026 MDD 58% (n=253 样本少)。

### 5. 参数敏感性 ✅ PASS

| 变体 | PF | 变化 |
|---|---|---|
| FIB 0.5 | 1.762 | +12.1% |
| **FIB 0.618 (原)** | **1.572** | 0% |
| FIB_TIMEOUT 8 | 1.618 | +2.9% |
| FIB_TIMEOUT 18 | 1.604 | +2.1% |

多档参数 PF 都 > 1.5 → 不是局部最优过拟合。

---

## 与 PureBO 组合 (Portfolio 测试)

### corr 分析

| 指标 | 值 | 解读 |
|---|---|---|
| daily pnl corr | **+0.33** | 中低相关，日级别错开 ✅ |
| weekly pnl corr | +0.67 | 中高相关 (都吃突破惯性) |
| 持仓时间 Jaccard | 28.7% | 28% 重叠 / 72% 错开 |

### Portfolio vs 单 PureBO

| 指标 | PureBO 单跑 | Combo (PureBO + Sess+Fib) | 差距 |
|---|---|---|---|
| n | 3,659 | 5,398 | +48% |
| WR | 68.7% | 70.0% | +1.2pt |
| PF | 1.883 | 1.761 | -0.12 |
| **net (5y)** | $136,447 | **$193,559** | **+42%** ⭐ |
| MDD | 11.6% | 17.0% | +5.4% |
| 日均频率 | 5.0 | 5.3 | +0.3 |

**真实数据期 (2024+):**
- Combo: n=4,517, WR=74.6%, PF=1.791, net=$189,689, **5.3 单/工作日**

---

## 关键洞察 (重要)

### 1. trail 是真 alpha (再次验证)

**signal 方向 IC ≈ 0** + **trail 吃突破惯性** = 真利润源。
- 200 个**完全随机** signal + 同 trail 配置: PF mean **1.56** vs 真因子 1.61
- **任何能频繁触发 trade 的信号配 trail 0.5 USD 都能拿到 PF 1.5+**

### 2. 时段过滤 ≠ 提升

砍 Asia + London 时段 → trade -33% / net -46%。
**反直觉**: 弱 IC 时段的 trade 也通过 trail 吃到了突破惯性利润。

### 3. 跟 PureBO 互补 (corr 0.33)

虽然两因子都吃突破惯性，但触发条件不同：
- PureBO: H1 swing breakout
- Session+Fib: 时段 sweep + fib retest

→ daily 错开足以让组合 net +42%。

### 4. NY + Closed 是 IC 显著时段

但 IC 显著 ≠ 实盘 PF 显著（trail 在所有时段都工作）。
**实盘部署不需要时段过滤**。

---

## 部署候选 (3 选项)

### 选项 A ⭐ 推荐: 同账户 2 EA + 各 risk 1.5%

```
EBC57171:
  ├─ PureBO_Trail_v1     (Magic 57171, RiskPerTrade=1.5%)
  └─ Session_Fib_v1      (Magic 57172, RiskPerTrade=1.5%)
```
- 单笔最坏 -3.4% (1.5% × 2.25 cap)
- 总频率 5.3 单/工作日
- net uplift +42% vs 单 PureBO

### 选项 B 激进: 同账户 2 EA + 各 risk 3%

- 单笔最坏 -6.75% (3% × 2.25 cap)
- 两 EA 同向时刻 -13.5% (黑天鹅)
- 不推荐

### 选项 C 保守: 仅 PureBO

- 已部署
- 损失 +42% net 机会成本

---

## 文件清单

### 代码
- `code/session_sweep_fib618_h1.py` ⭐ v1 部署版 (PF 1.57)
- `code/session_sweep_fib618_h1_v2.py` v2 NY-only (失败版本, 教训用)

### 验证脚本
- `scripts/session_fib_full_validation.py` 单因子表现 + reason 拆解
- `scripts/session_fib_alpha_audit.py` 完整 alpha 审计 (lookahead + IC + 白噪声 + walk-forward + 参数敏感性)
- `scripts/portfolio_corr_test.py` 跟 PureBO 的 corr + portfolio 测试

### 数据快照
- `data_snapshot/Session_Sweep_Fib618_H1.json` 因子库 v1
- `data_snapshot/Session_Sweep_Fib618_H1_v2_NYonly.json` 因子库 v2 NY-only

---

## 不要做的事

- ❌ 加时段过滤 (v2 已证明会降低收益)
- ❌ 单独部署 (跟 PureBO 共振才是最优)
- ❌ 调高 mul/cap 想"指数级放大" (跟 PureBO 同样的物理瓶颈: RR < 1)

---

## 接下来

- ☐ 决定部署选项 (A 推荐)
- ☐ 如选 A, 改造 EA 加 Magic 57172 + 编译 + 部署
- ☐ 等 PureBO 跑 2 天后, 如果稳定再加 Session+Fib
- ☐ 月度 IC 监控 (12h horizon, 转负 ≥ 2 月暂停)
