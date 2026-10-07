# 组合策略因子完整复核方案 + 短板分析 + 发展路线图

**生成日期**: 2026-05-09
**适用对象**: 方案 G+ 7 因子组合 (PureBO/VP POC/Session+Fib/Liquidation v6/Gap Reject/Divergence/Stop Hunt)

---

# Part 1: 完整复核方案 (8 维严格审计 checklist)

## 1.1 7 因子审计现状

| 因子 | Lookahead | IC | 白噪声 | Walk-fwd | 参数敏感 | 跨年稳定 | 实盘验证 | **完整度** |
|---|---|---|---|---|---|---|---|---|
| PureBO | ✅ | ⚠️ 0.05 弱 | ❌ 缺 | ❌ 缺 | ✅ | ✅ | 🟡 EBC57171 部署中 | **3/7** |
| VP POC | ✅ | ✅ 0.06+0.142 trigger | ⚠️ 击败率 74.5% | ⚠️ OOS MDD 53% | ✅ | ✅ | ❌ | **5/7** |
| Session+Fib | ✅ | ✅ NY/Closed 显著 | ⚠️ 击败率 39.5% | ✅ OOS PF 1.58 | ✅ | ✅ | ❌ | **6/7** |
| Liquidation v6 (扩频) | (baseline ✅) | (baseline 0.27 ⭐) | (baseline 28%) | (baseline ✅) | ✅ | ✅ | ❌ | **5/7** (扩频版未单独) |
| Gap Reject v3 | (历史 ✅) | (10 trades 太小) | ❌ N=10 | ⚠️ train 集中 | ❌ | ⚠️ short 仅 2 笔 | ❌ | **2/7** |
| Divergence (archive) | ✅ | ✅ p<0.0001 | ✅ 94% pass | ⚠️ N=53 sample 不足 | ✅ | ✅ | ❌ | **6/7** |
| Stop Hunt | ✅ lookahead PASS | ❌ 缺 | ❌ 缺 | ❌ 缺 | ❌ | ❌ | ❌ | **1/7** |

**整体平均完整度: 4/7**

## 1.2 复核维度详细 checklist

### 维度 1: Lookahead 审计 (强制项)
- [ ] 静态 lint (`/tmp/lookahead_lint.py`): 0 CRITICAL/HIGH
- [ ] 运行时装饰器 `@assert_no_lookahead`: PASS
- [ ] 手工审计每根 K 数据可见时序

### 维度 2: IC 系统化分析
- [ ] Multi-horizon IC: 1h/4h/12h/24h/48h/72h
- [ ] IC by year: 跨 4 年 (2023/2024/2025/2026) PF > 0
- [ ] IC by session: Asia/London/NY/Closed
- [ ] Monthly IC + IR (12+ 月份)
- [ ] 触发点 (trigger only) IC vs 全 signal IC

### 维度 3: 白噪声基线 (200 random factors)
- [ ] 同触发频率随机 signal 跑 200 次
- [ ] PF 击败率 ≤ 5% (严格) 或 ≤ 30% (放宽)
- [ ] net 击败率 ≤ 10%

### 维度 4: Walk-forward 过拟合检验
- [ ] 2024 训练 / 2025 验证 / 2026 OOS
- [ ] OOS PF > 1.3
- [ ] WR 跨期稳定 (变化 < 5pt)
- [ ] MDD OOS < 30%

### 维度 5: 参数敏感性 (≥3 参数 grid)
- [ ] 关键参数各 ±20% 变动测试
- [ ] PF 变化 < 10%
- [ ] 不是单点过拟合

### 维度 6: 跨年/跨 regime 稳定性
- [ ] 牛市 (2024 上半年 XAU 突破) PF
- [ ] 熊市 / 震荡市 PF
- [ ] 黑天鹅事件期 (CPI 超预期 / FOMC 转鹰) MDD
- [ ] 月度 IC win rate > 50%

### 维度 7: 小样本检验 (Gap/Divergence)
- [ ] N < 100 因子: 用 bootstrap 重抽样
- [ ] 单笔最大盈亏占总收益占比 < 30%
- [ ] 排除"黑天鹅幸运"因素

### 维度 8: 实盘 vs 回测衰减率 (实盘部署后)
- [ ] 跑 4 周记录: PF / WR / MDD vs 回测预期
- [ ] 衰减率 < 50%: 维持部署
- [ ] 衰减率 > 70%: 暂停 + 调查 (broker / 滑点 / regime shift)

---

## 1.3 优先复核顺序 (按完整度反序)

### 🚨 高优先级 (完整度 ≤ 3/7)

1. **Stop Hunt** (1/7) - 仅 lookahead PASS, 其他全缺
   - 完整 IC + 白噪声 + walk-fwd + 参数敏感 + 跨年
2. **Gap Reject v3** (2/7) - 10 trades 极小样本
   - Bootstrap 重抽样验证 + 跨年 walk-fwd
3. **PureBO** (3/7) - 已部署但 audit 不全
   - 白噪声 + walk-fwd + IC by year/session

### 🟡 中优先级 (4-5/7)

4. **VP POC** (5/7) - 击败率 74.5% 警告
5. **Liquidation v6 扩频** (5/7) - 扩频版本独立审计

### ✅ 低优先级 (≥6/7)

6. **Session+Fib** (6/7) - 已较完整
7. **Divergence (archive)** (6/7) - 已 5/5 PASS

---

# Part 2: 当前组合策略短板分析

## 2.1 流派单一 (致命短板 ⚠️)

7 因子全部围绕 **"价格突破/回归 + trail 锁惯性"** 一个核心机制:
- PureBO/Liquidation/Stop Hunt: 突破触发
- VP POC/Session+Fib/Divergence: 回归触发
- Gap Reject: 跳空回归

**缺失流派:**

| 缺失 | 描述 |
|---|---|
| ❌ TSMOM (时间序列动量) | 月度趋势跟随, 跨品种 |
| ❌ Carry trade | 期货升贴水套利 |
| ❌ Cross-asset arb | XAU vs XAG / XAU vs DXY 套利 |
| ❌ 季节性 | 月初/月末/quarterly 效应 |
| ❌ 事件驱动 | NFP/CPI/FOMC 规则化 |
| ❌ Vol surface | XAU options 隐含波动率套利 |
| ❌ Statistical arbitrage | pairs trading |

**风险**: 当 trail 机制失效（broker spread 扩张 50%+），整个 portfolio 同时崩。

## 2.2 单 TF 集中 (H1)

7 因子全部在 H1。

**缺失 TF:**
- D1 中长线趋势 (1-3 周持仓)
- H4 中线 (1-3 天)
- M15 短线 (1-4 小时, 跟 H1 互补)

**跨 TF 共振未利用** - H1 + H4 + D1 同向时加大仓位的逻辑。

## 2.3 单品种 XAU 集中 (高度集中风险)

之前测试 EUR/GBP/JPY 在 PureBO 上 PF < 1 失败, 但:
- 不同因子 (mean reversion / 反转) 在不同品种可能工作
- 没系统性测过 forex 反转 / metals (XAG/copper) / 股指 (US500)

**集中风险**: 单 broker 单品种, XAU 流动性事件直接打穿账户。

## 2.4 Trail 机制重度依赖 (单点失败)

5 个因子用 trail 0.5 USD:
- PureBO, VP POC, Session+Fib, Liquidation, Stop Hunt

**风险**:
- 实盘 spread 扩张 50% → trail 0.5 USD 直接失效 (被 spread 吞)
- 黑天鹅时 broker 滑点 0.5-1 USD → trail 全部触发亏损

**需要**: trail 机制多样化 (ATR-based / 时间-based / 多目标 TP)

## 2.5 缺乏 hedge / market-neutral 维度

7 因子全 directional (long 或 short):
- 没 delta-hedged options
- 没 pairs trading
- 黑天鹅时全部敞口同向

**结果**: 黑天鹅日 (NFP 大爆 / 地缘事件) 7 因子可能同时亏损。

## 2.6 实盘成本极敏感 (broker 选择决定生死)

| 实盘成本 | PF 衰减 |
|---|---|
| 标准 ECN (commission $7 + spread 30pt) | -22% |
| spread+50% | -37% |
| spread+100% + slippage 50pt | -75% |
| 极端 STP/MM | 全部翻车 |

**broker 切换** = 策略生死。

## 2.7 风险管理过度简单

当前: 复利 + 固定 lot scaling + cap 5

**缺失:**
- ❌ 波动率 targeting (按 vol 调整 lot)
- ❌ Regime detection (HMM 趋势/震荡切换策略)
- ❌ 黑天鹅 circuit breaker (单日 MDD > X% 停)
- ❌ 跨账户/跨 broker 分散
- ❌ Time stop adaptive (高 vol 期缩短)

## 2.8 数据质量限制 (历史)

- 2021-2023 broker 死数据 (96% zero-change)
- 有效真实数据仅 2.4 年 (2024+)
- 跨 regime 验证不足 (没有 2008 / 2020 类危机数据)
- 实盘 IC drift 监控未建

---

# Part 3: 可继续发展的因子策略方向

## 3.1 流派扩展 (优先级 ⭐⭐⭐)

### A. **TSMOM (时间序列动量)** ⭐⭐⭐
- D1 上 1/3/6/12 月动量综合排名
- 跨 forex/metals/股指
- 经典 Asness 流派, 长期稳定
- 跟当前所有因子 corr 应低 (D1 vs H1)

### B. **Cross-asset arbitrage** ⭐⭐⭐
- **XAU vs XAG ratio**: 历史 60-90 区间, 极端时 mean reversion
- **XAU vs DXY**: -0.7 到 -0.9 corr, divergence 时套利
- **XAU vs Copper**: 通胀代理, 比率 trading

### C. **Event-driven (规则化)** ⭐⭐
- NFP 发布前 30 min: 收紧 lot / 暂停部分因子
- CPI 公布后 5 min: 顺势开仓 (突破方向)
- FOMC 决议日: 全停 + 第二天恢复

### D. **季节性** ⭐
- 月底/月初效应 (institutional rebalancing)
- 季度末 (quarterly window dressing)
- 周一 vs 周五效应

## 3.2 TF 扩展 ⭐⭐

### A. **H4 因子库**
- PureBO/VP POC 在 H4 重测
- H4 趋势 + H1 入场 multi-TF 共振

### B. **D1 中长线**
- 月度趋势
- 持仓 1-3 周
- 跟 H1 因子时间维度互补

## 3.3 多品种扩展 ⭐⭐⭐

### A. **XAU + XAG portfolio**
- 现有 7 因子在 XAG 重测
- 金银 corr 0.7-0.9 但 alpha 可能不同

### B. **跨 forex 主要货币对**
- EUR/GBP/JPY 在 mean reversion 流派 (VP POC) 重测
- 之前 PureBO 失败但 mean reversion 可能工作

### C. **股指 (US500/NDX)**
- XAU 是趋势品种, 股指可能反转更工作
- 添加 portfolio 维度

## 3.4 Trail 机制多样化 ⭐⭐

### A. **ATR-based 动态 trail**
- 当前 fixed 0.5 USD → 改为 0.3 ATR 动态
- 高 vol 期自动放宽, 低 vol 期紧

### B. **Time-based trail**
- 持仓 0-12 H1: trail 1 USD
- 12-36 H1: trail 0.5 USD (锁紧)
- > 36 H1: 全平

### C. **Multi-target TP (分批出场)**
- 50% 仓位 1 ATR 出
- 30% 仓位 2 ATR 出
- 20% 仓位 trail 持有

## 3.5 风险层升级 ⭐⭐⭐

### A. **Volatility targeting**
- 按 30 日 ATR 调整 lot (低 vol 加 lot, 高 vol 减 lot)
- 目标年化 vol 15-20%

### B. **Regime detection (HMM)**
- 用 ATR + ADX 检测 trending vs ranging
- Trending regime: PureBO/Liquidation 加重
- Ranging regime: VP POC/Stop Hunt 加重

### C. **Black swan circuit breaker**
- 单日 MDD > 5% → 暂停 1 天
- 单周 MDD > 10% → 暂停 1 周, 复盘
- 单月 MDD > 20% → 暂停 1 月, 全量审计

### D. **Cross-broker hedge**
- 主账户 IC Markets + 备用 EBC + 备用 Pepperstone
- 同 magic 同 lot 跨 broker 跑 → broker 风险分散

## 3.6 ML / 量化升级 ⭐⭐

### A. **LightGBM ensemble** (基础已有 P2_lgbm)
- 把 7 个因子作 features
- 预测 H1 收益方向
- 跟现有 portfolio 共振过滤

### B. **特征工程**
- POC 距离 / RSI / vol surge / BB 位置 等基础特征
- 时段 / 星期 / 月份 dummy

### C. **风险预测**
- 预测黑天鹅日 (vol surge prediction)
- 提前 lot 减半

## 3.7 Hedge 维度 ⭐

### A. **Pairs trading XAU/XAG**
- ratio 60/90 极端时 mean reversion
- delta-neutral

### B. **Options strategies** (高级, broker 限制)
- XAU options covered call
- vol arbitrage

---

# Part 4: 推荐发展路径 (3 个月时间表)

## 月 1: 实盘验证 + 完整审计补完

**Week 1-2:**
- [ ] PureBO EBC57171 实盘 2 周, 算实盘 vs 回测衰减率
- [ ] 补完 PureBO 完整 audit (白噪声 + walk-fwd + IC)

**Week 3-4:**
- [ ] Stop Hunt 完整 audit (1/7 → 7/7)
- [ ] Gap Reject v3 bootstrap 小样本验证
- [ ] Liquidation v6 扩频版独立 audit

## 月 2: 流派扩展 (优先级 ⭐⭐⭐)

**Week 5-6:**
- [ ] TSMOM 因子开发 (D1 多品种动量)
- [ ] XAU vs XAG ratio 套利

**Week 7-8:**
- [ ] Volatility targeting 风险层添加
- [ ] Regime detection (HMM) 实施

## 月 3: 多品种 + 多 TF 扩展

**Week 9-10:**
- [ ] H4 因子库 (PureBO/VP POC 重测)
- [ ] XAUUSD + XAGUSD portfolio

**Week 11-12:**
- [ ] 实盘月度复核
- [ ] 因子库总评估 + 下季度方向

---

# Part 5: 关键决策原则 (避免之前痛史)

1. **不要再做 retail 教科书形态** (RSI/MACD/EMA + K形态 已 5 次失败)
2. **必做 lookahead 静态 + 运行时双验证** (MACD/SSL 痛史)
3. **真 alpha 来源是 trade management 不是 signal direction** (IC 0.05 也能 PF 1.88)
4. **MDD 优先于 CAGR** (用 -10% CAGR 换 -3% MDD 是值得的)
5. **过拟合排除: 参数敏感性 + walk-forward + 白噪声三件套**
6. **小样本警戒: N < 100 必须 bootstrap**
7. **实盘衰减预期 30-50%, 设计 risk 时打折**
8. **broker 选择决定生死** - 优先 ECN (IC Markets / Pepperstone)

---

## 文件位置

- 主文档: `/Users/joker/factor_factory_archive/v20260509_portfolio_6factor_FINAL/REVIEW_FRAMEWORK_AND_ROADMAP.md`
- Obsidian 同步: `项目/因子工厂/REVIEW_FRAMEWORK_v20260509.md`
- 关联: `SCHEME_G_OPTIMAL.md` / `MANIFEST.md`
