# 方案 G 提升路线图: Sharpe ↑ / MDD ↓ / 盈利 ↑

**当前 baseline (方案 G 6 因子, 真实 2024+)**:
- CAGR 1607%, MDD 14.92%, Calmar 107.71, n_trades 7920
- 5y baseline: CAGR 266%, MDD 13.18%, Calmar 20.21

---

# Part 1: 当前 8 大短板诊断

## 短板 1: Alpha 分散度不足 ⚠️⚠️

**症状:**
- 6 因子全 H1 (单一 TF)
- 全 XAU (单一品种)
- 全"trade management + trail 锁惯性"流派
- 真正负相关仅 VP POC (corr -0.04), 其他 5 个 corr +0.05~+0.33

**风险:** 流派同源 → 共同失效 (broker spread 扩张 50% → 5 个 trail 因子同时崩)

## 短板 2: MDD 集中在大波动事件 ⚠️⚠️

**症状:**
- 2025-12 月度 MDD 14.92% 单一事件 (FOMC / 地缘?)
- 月度 MDD P95 10.16% (5% 概率发生)
- 缺事件感知 → 黑天鹅日全敞口

**风险:** NFP/CPI 大爆 → 6 因子同时大亏

## 短板 3: Trail 单点失败 ⚠️⚠️

**症状:**
- 5/6 因子依赖 trail 0.5 USD
- 实盘 spread 扩张 → trail 全失效
- 没替代退场机制

**风险:** Broker 切换 / spread 季节性扩张 → 全 portfolio 失效

## 短板 4: 复利天花板 ⚠️

**症状:**
- maxLot 5 是 $10k 账户的实盘约束
- $1M 账户后增长停滞
- 单 broker 单账户

**风险:** Broker 风控 / margin call / 单点流动性不足

## 短板 5: 缺少 hedge / 真负相关 ⚠️⚠️

**症状:**
- 7 因子 corr 矩阵中, 真负相关只有 VP POC vs PureBO (-0.04)
- 黑天鹅同步亏损概率高

**风险:** 大事件日 6 因子同向亏 → MDD 翻倍

## 短板 6: 数据样本不足 ⚠️

**症状:**
- 真实数据仅 2.4 年 (2024-2026, 2021-2023 死数据)
- 没经历 2008/2020 类危机
- 跨 regime 验证不足

**风险:** 历史回测乐观, 实盘黑天鹅期失效

## 短板 7: 时间尺度单一 ⚠️

**症状:**
- 全 H1, 持仓 < 36 H1 (< 1.5 天)
- 没长线 (周/月持仓)
- 没短线 (M15)

**风险:** 错失多时间尺度 alpha + 短期波动放大

## 短板 8: 风险管理简化 ⚠️

**症状:**
- 仅"复利 + maxLot 5"
- 没 vol targeting
- 没 regime detection
- 没 daily/weekly MDD 熔断

**风险:** 高 vol 期被持续打击, 没自动减仓

---

# Part 2: 解决方案 (按 ROI 优先级排序)

## 🥇 优先级 1: 高 ROI (低成本立竿见影)

### 1.1 Volatility Targeting (波动率目标定位)

**逻辑:** 按当前 30 日 ATR 动态调整 lot
- 高 vol 期: ATR > 历史 70 分位 → lot ×0.7
- 低 vol 期: ATR < 历史 30 分位 → lot ×1.3
- 中等 vol: lot ×1.0

**预期效果:**
| 维度 | 改善 |
|---|---|
| MDD | **-20% ~ -30%** ⭐ |
| Sharpe | +10-15% |
| Net pnl | -3% ~ +5% (持平) |

**实施:**
- 在每个 EA 里加 `vol_scale = clip(ATR_pct_30d / 0.5, 0.5, 1.5)` 调整 lot
- 复杂度: 低 (1-2 天)

### 1.2 Black Swan Circuit Breaker (黑天鹅熔断)

**逻辑:**
- 单日 MDD > 5% → 暂停所有 EA 12 小时
- 单周 MDD > 10% → 暂停 3 天
- 单月 MDD > 15% → 暂停 1 周, 强制复盘

**预期效果:**
| 维度 | 改善 |
|---|---|
| MDD | **-15%** (避免连环亏损) |
| Sharpe | +5% |
| Net pnl | -3% (偶尔会错过反弹) |

**实施:**
- 主控 EA 监控 MDD, 触发后写 GlobalVariable 暂停所有子 EA
- 复杂度: 低 (1 天)

### 1.3 事件日规则 (NFP/CPI/FOMC)

**逻辑:**
- 经济日历自动获取
- 高影响事件前 30 min: 暂停开新仓
- 事件后 1 H1: 等明朗后恢复
- 关键事件日 (FOMC) 全天减仓 50%

**预期效果:**
| 维度 | 改善 |
|---|---|
| MDD | **-10%** |
| Sharpe | +5% |
| Net pnl | -5% (错过部分事件机会) |

**实施:**
- 用 ForexFactory/Investing 经济日历 API
- 主控 EA 提前 1 天加载事件
- 复杂度: 中 (3-5 天)

---

## 🥈 优先级 2: 中 ROI (中等成本实质提升)

### 2.1 多 TF 扩展 (H4 + D1)

**思路:**
- PureBO 在 H4 重测 (持仓 1-3 天) → 跟 H1 时间尺度互补
- VP POC 在 H4 (POC 计算更稳定)
- D1 趋势 (持仓 1-3 周) → 长线 alpha

**预期效果:**
| 维度 | 改善 |
|---|---|
| Sharpe | **+15-25%** ⭐ |
| MDD | -5-10% |
| Net pnl | **+20-40%** ⭐ |
| 复杂度 | 中 (代码已有, 数据已下载) |

**数据状态:** ✅ XAU H4 已存在, D1 已下载 (1379 rows)

**实施:**
- 跑 PureBO/VP POC/Liquidation 在 H4 上的回测
- IC + walk-fwd + 白噪声严格审计
- 加进 portfolio 看 corr 和边际增量

### 2.2 多品种扩展

**优先级:**
1. **XAG (银)** ✅ 数据已下 - 跟 XAU corr 0.7-0.9, alpha 可能不同
2. **US500** ✅ 数据已下 - 跟 XAU corr 弱, 真正分散
3. **BTC** ✅ 数据已下 - 高波动, 反转流派可能工作
4. AUDUSD/USDCAD - 商品货币 (跟金属相关)

**预期效果:**
| 维度 | 改善 |
|---|---|
| Sharpe | **+20-30%** ⭐⭐ |
| MDD | -10-15% (跨品种分散) |
| Net pnl | **+30-50%** ⭐⭐ |
| 复杂度 | 中 (需改 SymbolSpec, 单品种独立验证) |

**实施:**
- 阶段 1: PureBO/VP POC 在 XAG 验证 (跟 XAU 同流派, 应工作)
- 阶段 2: VP POC 在 US500 (反转流派可能更工作)
- 阶段 3: 各因子最佳品种组合 portfolio

### 2.3 TSMOM 时间序列动量 (D1, 跨品种)

**逻辑:**
- 每月初按 1/3/6/12 月动量打分
- top 1/3 做多, bottom 1/3 做空
- 持仓 1 个月

**预期效果:**
| 维度 | 改善 |
|---|---|
| Sharpe | +10% |
| MDD | -5% |
| Net pnl | +15-25% |
| 复杂度 | 中-高 (需多品种数据 + 月度调仓) |

---

## 🥉 优先级 3: 低 ROI (复杂或边际)

### 3.1 Regime Detection (HMM)
- 检测 trending vs ranging regime
- 预期 Sharpe +5%, MDD -5%
- 复杂度: 高 (HMM 模型 + 实盘信号生成)

### 3.2 期权 Hedge (XAU options)
- broker 限制 (大部分零售 broker 不支持 XAU options)
- 复杂度: 极高
- ROI: 待验证

### 3.3 跨 broker 分散
- 主账户 IC Markets + 备用 EBC + 备用 Pepperstone
- 单 broker 风险减半
- 复杂度: 高 (实施 + 监控成本)

### 3.4 ML 集成
- LightGBM ensemble 把 6 因子作 features
- 预期 Sharpe +5-10%
- 复杂度: 极高 (需大量训练数据 + 持续迭代)

---

# Part 3: 实施路线表 (3 个月)

## Month 1: 低成本立刻见效 (Sharpe +30% / MDD -40%)

### Week 1
- [ ] **实施 Volatility Targeting** (1-2 天)
  - 在 PureBO EA 里先加, 跑 1 周验证
  - 然后推广到其他 EA
- [ ] **实施 Black Swan Circuit Breaker** (1 天)
  - 主控 EA 监控总账户 MDD

### Week 2
- [ ] 验证 Vol Target + Circuit Breaker 在 5y 数据上的表现
- [ ] 跟方案 G baseline 对比 Sharpe / MDD / net

### Week 3-4
- [ ] **多 TF 扩展 (H4)**
  - PureBO 在 H4 重测 + 完整 audit
  - VP POC 在 H4 重测 + 完整 audit
- [ ] H1 + H4 双 TF portfolio combo 测试

## Month 2: 多品种扩展 (Sharpe +25% / Net +40%)

### Week 5-6
- [ ] **XAG (银) portfolio**
  - 6 因子在 XAG 各跑一遍
  - 选 PF > 1.5 的入 portfolio
  - 跟 XAU portfolio combo

### Week 7-8
- [ ] **US500 portfolio**
  - VP POC + Divergence (反转流派, 应工作)
  - PureBO (突破流派, 验证)
- [ ] 多品种 portfolio = XAU + XAG + US500

## Month 3: 高级风控 + 持续优化

### Week 9-10
- [ ] **事件日规则**
  - 经济日历 API 集成
  - NFP/CPI/FOMC 前后规则
- [ ] 实盘 1 月数据复盘

### Week 11-12
- [ ] **TSMOM D1 跨品种** (如果时间允许)
- [ ] 因子库总评估
- [ ] 下季度方向

---

# Part 4: 预期最终效果

## Month 1 完成后

| 指标 | 当前 | Month 1 | 改善 |
|---|---|---|---|
| Sharpe (估算) | ~3.0 | **~4.0** | +33% |
| MDD | 14.92% | **9-10%** | -35% |
| Calmar | 107.71 | **~150** | +40% |
| net (5y) | $7.4M | $7.0M | -5% (Vol target 略减仓) |

## Month 2 完成后

| 指标 | 当前 | Month 2 | 改善 |
|---|---|---|---|
| Sharpe | ~3.0 | **~5.0** | +67% |
| MDD | 14.92% | **8-9%** | -45% |
| Calmar | 107.71 | **~200** | +85% |
| net (5y) | $7.4M | **$11M** | +50% |

## Month 3 完成后

| 指标 | 当前 | Month 3 (终极) | 改善 |
|---|---|---|---|
| Sharpe | ~3.0 | **~5.5** | +80% |
| MDD | 14.92% | **7-8%** | -50% |
| Calmar | 107.71 | **~250** | +130% |
| net (5y) | $7.4M | **$13-15M** | +80% |

---

# Part 5: 关键警告

## 1. 不要再做以下方向 (痛史已证明失败)

- ❌ retail 教科书指标堆叠 (RSI/MACD/EMA + K形态)
- ❌ M5/M1 上 EMA + K 形态因子
- ❌ Stop Hunt / Sentiment Exhaustion (audit 失败 + 过滤误伤)
- ❌ MACD/SSL (lookahead 痛史)
- ❌ V4 网格金字塔 (CAGR 0.6% 太低)

## 2. 严格审计每一个新因子

任何新因子必须:
- [ ] Lookahead 静态 + 运行时 PASS
- [ ] IC 跨年稳定 (每年 PF > 1)
- [ ] 白噪声击败率 ≤ 30%
- [ ] Walk-forward 3 期 PF > 1.3
- [ ] 参数敏感性鲁棒
- [ ] 加进 portfolio 后 MDD 不增加 (corr 验证)

## 3. 实盘 vs 回测衰减率监控

- 每月对比实盘 PF/WR/MDD vs 回测预期
- 衰减率 > 50% → 暂停 + 调查
- 不盲目相信回测

## 4. 多元化 ≠ 简单加因子

- 加因子前必须确认 corr < 0.3
- "看似独立但同源" (如 SH/SE corr 0.717) 是陷阱
- 用持仓时段 Jaccard + daily pnl corr 双重验证

---

## 文件位置

- 主文档: `/Users/joker/factor_factory_archive/v20260509_portfolio_6factor_FINAL/IMPROVEMENT_ROADMAP.md`
- Obsidian 同步: `项目/因子工厂/IMPROVEMENT_ROADMAP_v20260509.md`
- 关联: `SCHEME_G_OPTIMAL.md` / `REVIEW_FRAMEWORK_AND_ROADMAP.md`
