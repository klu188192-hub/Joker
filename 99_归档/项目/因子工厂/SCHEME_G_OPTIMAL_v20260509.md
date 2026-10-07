# 方案 G — 6 因子最优组合配置 (Calmar 最大化, 无马丁仅复利)

**归档日期**: 2026-05-09 (Stop Hunt 严格审计失败 / 撤回 G+)
**状态**: 推荐部署版 (待实盘复核)
**核心原则**: 不过度优化, 找最舒服阈值 — Calmar 107.7 / MDD 14.92%

**⚠️ 升级历史 (Stop Hunt 三次拒绝)**:
- G (6 因子): Calmar 107.7 / MDD 14.92% (2024+) ✅ 维持
- ❌ G+ (+ SH 当因子 0.75%): 严格审计失败 (IC 跨年翻转, 白噪声击败 60%, walk-fwd 亏损)
- ❌ G★ (SH 当过滤器 Mode E): 看似 Calmar +12%, 但**误伤 70% 盈利 trade** (PureBO 被过滤 WR 71% / Liquidation 被过滤 WR 74%, 总损失 -$711k)
  - Mode F (精准方向匹配) Calmar 几乎不变 (107.88 vs 107.71) → SH 方向跟 trade 方向无相关
  - "MDD 减少"是 trade 数量减少的统计幻觉, 不是过滤亏损 trade

**SH/SE 三次否决理由**:
1. 不能当因子 (audit 失败)
2. 不能当全过滤器 (误伤盈利 trade)
3. 不能当方向过滤器 (跟 trade 方向无相关)
→ **彻底 SHELVED**, 维持方案 G (6 因子) 不变

---

## 配置规格 (G+ 版: 7 因子差异化 risk + 复利, 无马丁)

| 因子 | RiskPerTrade | UseMartingale | UseCompound | 理由 |
|---|---|---|---|---|
| **PureBO 顺势突破** | **1.0%** | ❌ false | ✅ true | 主力 PF 1.88, 高 risk |
| **VP POC 反转** | **1.0%** | ❌ false | ✅ true | 跟 PureBO corr **-0.04** 真对冲, 高 risk |
| Session+Fib 扫荡 | 0.5% | ❌ false | ✅ true | 跟 PureBO corr +0.33 同向, 低 risk |
| Liquidation v6 (扩频) | 0.75% | ❌ false | ✅ true | 跟 PureBO corr +0.18, 中 risk |
| Gap Reject v3 | 0.25% | ❌ false | ✅ true | 极低频 PF 9.17, 小 risk |
| Divergence (archive) | 0.5% | ❌ false | ✅ true | mean reversion 流派, 中 risk |
| **Stop Hunt** ⭐ NEW | **0.75%** | ❌ false | ✅ true | **流动性陷阱反向, MDD 减少 -1.15pt** |
| **总单笔账户风险** | **4.75%** | — | — | — |

---

## 5y 表现 ($10k 起)

| 指标 | 值 |
|---|---|
| Final equity | **$10,018,095** |
| 总倍数 | **1,002×** |
| **CAGR** | **266.27%** |
| **MDD** | **13.18%** ⭐ |
| **Calmar** | **20.21** ⭐⭐⭐ |
| **单笔最坏亏损** | **4.38%** |
| Max lot 触及 | 5.0 (cap) |

## 1y 表现 (2024 全年)

| 指标 | 值 |
|---|---|
| Final equity (1y) | $112,307 |
| 总倍数 | 11.2× |
| CAGR | 1,048% |
| MDD | 13.62% |

---

## 跟其他方案对比 (按 Calmar 排序)

| 方案 | CAGR | MDD | Calmar | 单笔最坏 | 评级 |
|---|---|---|---|---|---|
| **G. 加权无马丁** ⭐ | 266% | **13.2%** | **20.21** | **4.38%** | 🥇 最舒服 |
| B. 均匀 0.75% + 马丁 | 276% | 16.4% | 16.86 | 4.91% | 🥈 次选 |
| F. 差异 cap | 277% | 17.0% | 16.31 | 4.82% | 🥉 |
| D. Corr 加权 + 马丁 | 279% | 17.4% | 16.04 | 5.44% | |
| C. 均匀 1.0% | 285% | 21.4% | 13.34 | 5.44% | |
| H. PureBO 主力激进 | 286% | **29.8%** | 9.59 | **10.87%** | ❌ MDD 过大 |

**方案 G 用 -10pt CAGR 换 -3pt MDD + 更低单笔风险, 心理最舒服。**

---

## 🚫 V4 网格金字塔: 必要性测试 = 不必要

**测试 (2024+ 真实数据):**
- V4 跟 6 因子 corr 全部 < 0.20 (高独立性 ✅)
- Jaccard 持仓重叠 (vs Liquidation v6) 仅 **1.2%** (预期高度重叠却没有, 因网格机制不同)
- 加进 portfolio: 净利 +$18k / 5y (+0.25%), MDD +0.00, Calmar +0.12

**判定**: 独立性优秀但贡献过小 (43 trades / 2.4y / +0.25% net), 实施复杂度 (multi-position pyramid EA) 远超收益. **保留 archive 不部署**.

## 关键设计原则 (不过度优化)

### 1. **优先 MDD < 15%**, 而非追 CAGR

H 激进 vs G 平衡:
- H: CAGR 286% / MDD 29.8% → Calmar 9.59
- G: CAGR 266% / MDD 13.2% → Calmar 20.21
- **MDD 减半的价值远超 CAGR -7pt 损失**

### 2. **马丁是双刃剑** — 加 +10pt CAGR 但 +3pt MDD

| 配置 | CAGR | MDD |
|---|---|---|
| 加权无马丁 (G) | 266% | 13.2% |
| 加权 + 马丁 (D) | 279% | 17.4% |
| 均匀 + 马丁 (B) | 276% | 16.4% |

实盘黑天鹅时马丁会让单笔最坏 6.75%+，**G 无马丁单笔最坏 4.38%** 更可控。

### 3. **复利仍然 enabled** (账户增长 lot 跟随)

UseCompound=true 让账户从 $10k 增长到 $100k 时 lot 自然扩大 10x。这是非线性增长来源, 不放弃。

### 4. **差异化 risk 按 corr 互补**

- PureBO + VP POC (corr -0.04) → 各 1.0%（真对冲)
- Session+Fib (corr +0.33 跟 PureBO) → 0.5%（同向减仓)
- Gap Reject (PF 9.17 但 5y 仅 10 trades) → 0.25%（防过度依赖小样本)

### 5. **Cap 差异化无效**

方案 F (cap 差异 2.25/3.38/1.5) vs B (cap 全 2.25) → CAGR/MDD 几乎相同, 不引入复杂度。

---

## 📊 MDD 跨时段完整分析

### 不同时段 MDD ($1 万起, 无马丁仅复利)

| 期间 | n_trades | CAGR | MDD |
|---|---|---|---|
| **5 年完整 (2021-2026)** | 9,332 | 266% | **13.18%** |
| 真实数据 (2024-2026) | 7,920 | 1,607% | 14.92% |
| 2024 全年 | 3,363 | 1,048% | 13.62% |
| **2025 全年** | 3,403 | 1,477% | **15.06%** (历史最大) |
| 2026 OOS (4 月) | 1,066 | 16,872% | 6.82% |

### 平均 MDD 统计

| 指标 | 值 |
|---|---|
| **平均最大 MDD** | **12.72%** |
| 中位 MDD | 13.62% |
| 历史最大 MDD | 15.06% (2025 全年) |
| 历史最小 MDD | 6.82% (2026 OOS) |

### 滚动 MDD 分布 (2024+)

**月度 MDD (29 个月):**
| 指标 | 值 |
|---|---|
| 平均月 MDD | 5.21% |
| 中位月 MDD | 4.41% |
| P75 月 MDD | 6.47% |
| P95 月 MDD | 10.16% |
| 最大月 MDD | 14.92% (2025-12) |

**季度 MDD:**
- 平均: 7.35%
- 最大: 14.92% (2025Q4)

### 实盘衰减后预期 (broker 成本 + 滑点放大 1.3-1.5×)

| 指标 | 数学模型 | **实盘预期** |
|---|---|---|
| 平均年 MDD | 13% | **17-20%** |
| 最大年 MDD | 15% | **20-23%** |
| 月度 P95 MDD | 10% | **13-15%** |
| 月度平均 MDD | 5% | **7-8%** |

### ⚠️ 心理预警线

| 触发 | 行为 |
|---|---|
| 月度回撤 > 10% | 检查 broker 成本/滑点 |
| 月度回撤 > 15% | 暂停 1 周 + 复盘 |
| **年度回撤 > 25%** | **强制停 EA + 全部平仓** |
| 单笔回撤 > 5% | 检查 lot cap |
| 连亏 ≥ 7 笔 | 暂停 + regime shift 检查 |

**心理可承受度评估:**
- $10k 账户实盘 18% MDD = $1,800 浮亏（可承受）
- 月度 P95 10% MDD ≈ $1,000 浮亏（每月 5% 概率发生）
- ✅ 方案 G MDD 在心理舒适区内

---

## ⚠️ 待复核事项 (用户原话: "之后还是要复核")

### 1. 各因子完整 alpha audit
| 因子 | 已通过 | 待补 |
|---|---|---|
| PureBO | ✅ Lookahead | ❌ 白噪声 / walk-fwd / IC 系统化 |
| VP POC | ✅ 全套 (击败率 74.5% ⚠️) | — |
| Session+Fib | ✅ 全套 (击败率 39.5% ⚠️) | — |
| **Liquidation v6 (扩频)** | ⚠️ baseline 通过 | ❌ **扩频版 vol1.5/body1/lb10 未单独审计** |
| Gap Reject v3 | ⚠️ 历史小样本 | ❌ 跨年 walk-fwd / 白噪声 |
| **Divergence (archive)** | ✅ 5/5 通过 | — |

**首要复核: Liquidation v6 扩频版 + PureBO 完整 audit**

### 2. 实盘 vs 回测衰减率 (PureBO EBC57171 已上)

等 EBC57171 实盘跑 1-4 周, 算实际 PF / WR / MDD vs 回测预期, 估算衰减率。
然后按 (1 - 衰减率) 调整 risk %。

### 3. corr 在实盘是否维持

回测 corr 在实盘可能因 broker 滑点 / 时间错位变化:
- PureBO vs VP POC -0.04 → 实盘可能变 +0.1
- 等 4 周实盘数据后重新算 corr, 调整方案 G 中 risk 加权

### 4. Phase 部署路径

```
Phase 1 (现在 - 2 天): PureBO 单 EA 在 EBC57171 已部署 (3% risk)
Phase 2 (PureBO 验证后, 1-2 周): 改 PureBO 到 1% + 加 VP POC 1% + Liquidation 0.75%
Phase 3 (Phase 2 稳定 1 月): 加 Session+Fib 0.5% + Divergence 0.5%
Phase 4 (Phase 3 稳定 1 月): 加 Gap Reject 0.25%
最终: 6 EA 完整方案 G 部署
```

---

## EA 实施改动 (vs 现部署)

当前 PureBO EBC57171 EA:
```
RiskPerTrade=3.0
UseMartingale=true
MartiMultiplier=1.5
MartiCap=2.25
```

**改为方案 G:**
```
RiskPerTrade=1.0   (从 3% 降到 1%)
UseMartingale=false (关闭马丁)
UseCompound=true    (保持复利)
MaxLotCap=5.0       (实盘安全约束)
```

新加的 5 个 EA:
```
VP_POC_Reversion (Magic 57172, RiskPerTrade=1.0%)
Session_Fib_v1   (Magic 57173, RiskPerTrade=0.5%)
Liquidation_v6   (Magic 57174, RiskPerTrade=0.75%)
Gap_Reject_v3    (Magic 57175, RiskPerTrade=0.25%)
Divergence_long  (Magic 57176, RiskPerTrade=0.5%)
```
**全部 UseMartingale=false, UseCompound=true**

---

## 复核 checklist (按 Phase 跑)

- [ ] Phase 1 完成: PureBO 实盘 24-48h 数据, vs 回测对比 PF/WR
- [ ] Phase 2 准备: 编 VP POC + Liquidation v6 EA, 部署 EBC-mt5
- [ ] PureBO 实盘 1 周后: 调整 risk 1.0% (从 3.0%) + 关马丁
- [ ] Liquidation v6 扩频版完整 audit (lookahead/IC/walk-fwd/白噪声/参数敏感)
- [ ] Gap Reject 跨年 walk-forward 验证 (10 trades 是否真 alpha)
- [ ] PureBO 完整 audit 补完 (白噪声 / IC by year/session)
- [ ] 实盘 4 周后: 重算 6 因子 corr 矩阵, 调整 risk 加权
- [ ] 月度: 计算实盘 vs 回测衰减率, 动态调整 risk

---

## 文件位置

- 主 MANIFEST: `/Users/joker/factor_factory_archive/v20260509_portfolio_6factor_FINAL/MANIFEST.md`
- 6 因子代码: `code/factor_*.py`
- Optim grid 脚本: `scripts/portfolio_optim_grid.py`
- Archive Divergence sim: `code/factor_6_divergence_ARCHIVE_SIMULATOR.py`
- 本文档: `SCHEME_G_OPTIMAL.md`
- Obsidian 同步: `项目/因子工厂/PORTFOLIO_6FACTOR_FINAL_v20260509.md` + `SCHEME_G_OPTIMAL_v20260509.md`
