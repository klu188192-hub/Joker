# MACD_div × Structure Breakout Confluence 方案 v1

**生成日期**: 2026-05-08
**状态**: 已通过 32 个月历史回测验证，待实盘灰度部署

---

## 核心结论

把 Structure Breakout 因子作为 MACD_div 主信号的 **confluence 过滤层**（不开独立仓位），可以把 XAU H1+M15 MACD_div_SSL 的 Sharpe 从 **2.83** 提升到 **3.78**（保守配置）至 **4.04**（最优配置）。

**单笔级别证据（共同窗口 2023-09 ~ 2026-04，1579 笔 MACD trades）**：

| 状态 | n | WR | PF | avg/笔 | total |
|---|---|---|---|---|---|
| amplify (SB 共振) | 382 | **53.9%** ⭐ | **2.28** | +$41.77 | +$15,957 |
| dampen (SB 矛盾) | 389 | 35.2% | 1.20 | +$10.36 | +$4,029 |
| neutral (SB 无活动) | 808 | 43.9% | 1.41 | +$22.67 | +$18,315 |

**结构性增强**：SB 共振时 MACD 胜率从 44% → 54%，PF 从 1.41 → 2.28。不是偶然偏差。

---

## 实战逻辑

### 主信号
**MACD_div_SSL_H1_M5_LongShort_RR1to1**（已入因子库，5y Sharpe 7.80, A 级）
- H1 双向 MACD 直方图背离
- M5 SSL/SSH 扫荡 + 确认 K
- 入场: 下根 M5 开盘市价
- SL: 扫荡极值 ± 0.5×ATR(M5)
- TP: 入场 + RR=1:1 × SL 距离

### 过滤层信号
**Structure Breakout Pullback H1**（独立 PF 1.06, Sharpe 0.32, 不入主仓但作 confluence）
- Swing High = K.high > 左 2 根 high & 右 2 根 high
- 突破: H1 close > swing high
- 等回踩 (≤20 H1): low ∈ [breakout - 1×ATR, breakout + 1×ATR]
- 确认 K (≤5 H1): close > open AND close > 前 K.high AND vol < 突破 K.vol
- 入场仅多

### Confluence 规则

每笔 MACD trade 入场时刻 t，检查 SB 在 [t-12h, t+12h] 内是否有活跃 trade：

| MACD 方向 | SB 多头活跃？ | 状态 | 推荐仓位倍数 |
|---|---|---|---|
| long | 是 | **amplify (共振)** | **1.5x** (保守) / **2.0x** (激进) |
| long | 否 | neutral | 1.0x |
| short | 是 | **dampen (矛盾)** | **0.5x** (保守) / **0.25x** (激进) |
| short | 否 | neutral | 1.0x |

---

## 配置档位

### 保守 (推荐起步) — amp=1.5 / damp=0.5

| 指标 | Baseline (纯 MACD) | Confluence 1.5/0.5 | Delta |
|---|---|---|---|
| 月均 PnL | $1,197 | $1,383 | +15.5% |
| 月度 std | $1,465 | $1,267 | -13.5% |
| Sharpe (年化) | 2.83 | **3.78** | **+0.95** |
| 32 月总盈利 | $38,301 | $44,266 | +15.6% |

### 最优 (验证后切换) — amp=2.0 / damp=0.25

| 指标 | Baseline | Confluence 2.0/0.25 | Delta |
|---|---|---|---|
| 月均 PnL | $1,197 | $1,601 | +33.8% |
| 月度 std | $1,465 | $1,373 | -6.3% |
| Sharpe | 2.83 | **4.04** | **+1.21** |
| 总盈利 | $38,301 | $51,237 | +33.8% |

**注意**：amp=2.0 仓位翻倍要求账户**风险预算 ×1.5**（amplify 时仓位放大可能让单笔最大回撤 +50%）。

---

## Caveats（部署前必读）

1. **测试窗口仅 32 个月**（2023-09 ~ 2026-04），因为 SB 因子在 2023 年才开始稳定触发（前期 swing high + 突破 + 回踩 + 量能 4 条件少同时成立）。**5y 全窗口验证不足**。
2. **样本规模**：1579 笔 MACD trades 在 32 个月窗口已有统计显著性，但跨市场环境（牛市 / 熊市 / 震荡）覆盖不全。
3. **执行延迟敏感**：SB 状态需要在 MACD 触发瞬间查询，要求两个因子的实时活动状态都能监测到。
4. **MACD 短头部分（dampen）反而仍是正期望**（PF 1.20）：建议保守起步用 0.5x 而不是 0.25x，避免因 SB 误判压制掉真信号。

---

## 部署计划

### Phase 1 — 模拟跟踪（建议先 4-8 周）
- 在 KK 上跑双因子 live monitoring（不开实仓）
- 记录每个 MACD 信号触发瞬间的 SB 状态
- 逐笔记录 confluence 决策对应的实际 PnL
- 验证 32 月窗口的 amplify/dampen 比例（37%/37%/37% × 26%/26%/52%）是否复现

### Phase 2 — 灰度实盘 (Joker 头号 EBC-3 子仓位)
- 配置 1.5/0.5 保守档
- 主仓位 0.10 lot (与 EBC-3 现有 MACD 一致)
- 共振时加到 0.15 lot, 矛盾时减到 0.05 lot
- 跟踪 4 周 Sharpe 是否复现 3.5+

### Phase 3 — 切换最优档
- Sharpe 复现后切换 amp=2.0/damp=0.25
- 主仓位提升到 0.20 lot 配合 amplify 0.40 lot
- 风险预算总计每笔 ≤ 2% 账户资本

---

## 文件位置

- **MACD_div 因子库**: `factor_library/MACD_div_SSL_H1_M5_LongShort_RR1to1.json` (KK + mac)
- **Structure Breakout 因子库**: `factor_library/Structure_Breakout_Pullback_H1.json` (KK)
- **MACD trades CSV (5y)**: `/tmp/macd_long_short.csv` (mac)
- **SB trades CSV (32m)**: `/tmp/sb_trades.csv` (mac) / `_struct_breakout_trades.csv` (KK)
- **Confluence 模拟脚本**: `/tmp/confluence_sim.py` (mac)

---

## 33 版扫荡总结表（备查）

| 流派 | 真实 PF | corr vs MACD | 备注 |
|---|---|---|---|
| **MACD_div** (8 版) | **2.09 ⭐** | 1.00 | XAU 唯一稳定 alpha |
| EMA Divergence Pullback | 0.99-1.02 | 0.186 | 接近平衡, 加入拖累 MACD |
| **Structure Breakout** | **1.06** ⭐ | **0.081** ⭐ | corr 最低, 但独立 alpha 弱; 适合做 confluence |
| 亚盘突破伦敦延续 (4 版) | 0.72-0.77 | — | 接近平衡负 alpha |
| RSI 极端反转 (8 版) | 0.61-0.73 | — | 负 alpha (脉冲修复后) |
| EMA50 趋势延续 + INVERSE | 0.18-0.25 | — | 显著负 alpha |
| **DXY 跨品种宏观** | **1.17** | **0.529** (高) | 独立有 alpha 但 corr 高拖累组合 |

**关键学习**：跟 MACD 低相关 + Sharpe ≥ 1.0 的因子在 XAU 内不存在。Multi-asset MACD_div (XAU/USDJPY/EUR/GBP) 是唯一确定性的 Sharpe 提升路径，但**confluence 加权**是 single-asset 内最有效的提升手段。
