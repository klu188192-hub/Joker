# 量化开发工作流 SOP — 完整可执行版

> **此文档是量化开发的"圣经", 任何步骤跳过 = 自找过拟合 / 自找未来函数。**
> **5 道防线 + 11 步 SOP, 一道都不能少。**

---

## 0. 工作流总览 (5 道防线)

```
┌─────────────────────────────────────────────────────────────┐
│                  量化策略上线 5 道防线                       │
├─────────────────────────────────────────────────────────────┤
│ 防线 1: 防未来函数 (Lookahead-free 验证)                    │
│         → 静态扫描 + @assert_no_lookahead audit             │
│                                                              │
│ 防线 2: 防参数过拟合 (Walk-forward + 白噪声 baseline)       │
│         → 必须 OOS Sharpe > 白噪声 95 分位                  │
│                                                              │
│ 防线 3: 防 backtest 引擎失真 (MT5-only)                     │
│         → Python 模拟一律不可信, 必须 MT5 Strategy Tester  │
│                                                              │
│ 防线 4: 防 lock 决策黑箱 (DeepSeek/Gemini 评价归档)         │
│         → lock 前必须第三方 AI 评价 + 归档                  │
│                                                              │
│ 防线 5: 防实盘黑天鹅 (外层 kill switch + DD 限)             │
│         → EA 内 CB + 外层 monitor 双层保护                  │
└─────────────────────────────────────────────────────────────┘
```

**任一防线 fail = 不能上实盘**.

---

## 1. 因子开发 11 步 SOP (从 idea 到上线)

### Step 1: 因子 idea 来源
- 优先级: **用户主观交易经验** > 教材方法 > AI 推测
- 必须由用户口述具体条件 (不要 AI 推断)
- 写到 `~/factor_dev/<NAME>/IDEA.md` 记录原始 idea

### Step 2: 写 generator (Python)
- 位置: `~/factor_dev/<NAME>/<name>_signal.py`
- 必须**自带 `lookahead_self_check(df)` 函数**
- 必须**自带 `_audit()` 调用入口** 或外部 wrap `@assert_no_lookahead`
- 入口函数返回 DataFrame 或 Series, 含 `signal_time`, `entry_time`, `direction` 字段

### Step 3: lookahead 静态扫描 (防线 1.1)
跑 `python3 /tmp/lookahead_lint.py <signal.py>` 检查 9 种 pattern:
- `shift(-N)` (取未来)
- `center=True` (rolling 用未来一半)
- `bfill()` 在信号上
- `pd.qcut` 全样本分位
- `iloc[i+k]` 数组前向引用
- `fractal confirm` 时机错误 (`i_b` 而非 `i_b+R`)
- `iloc[i]` 在 SL 计算 (entry 时未知 H/L)
- `StandardScaler.fit(full).transform(full)` (全样本归一)
- `.fillna(method='backward')` 等同 bfill

**0 CRITICAL / HIGH = 通过, 进 Step 4. 否则修.**

### Step 4: lookahead 运行时 audit (防线 1.2)
跑作者 `lookahead_self_check(df)` + framework `assert_no_lookahead._audit(df)` 双重验证.

**必须返回 `[OK] n_full=N n_half=M` 且 M ≈ N/2**.

### Step 5: 信号 sanity 检查
- 信号触发数: 22m 内 N > 100 (足够样本)
- 信号方向分布: long/short 平衡 (不能 90%+ 单向)
- 信号时间分布: 不集中某段
- per-month signal count 不超过 ±50% 偏差

### Step 6: MT5 backtest 准备
- 写 EA `SignalDriven_<NAME>.mq5`, 读 CSV 信号 + 标准 SL/TP/lot
- 编译 0 errors
- 部署到 `D:\IC-tester\MQL5\Experts\`
- INI 配置: Model=2 Open prices, Deposit=$10K, Leverage=1:500, ShutdownTerminal=1

### Step 7: 在 IS 段跑 22m IS backtest (防线 3.1)
- INI FromDate=2024.07.01 ToDate=2026.05.10 (当前 22m 段)
- 跑完检查 EA log:
  - `[RULEREGIME TESTER]` 行有 trades > 0
  - 至少 10 条 `order performed`
- **遵守 [[08-犯错经验档案#痛史 #3]] 10 步检查清单**

### Step 8: 白噪声 baseline 对比 (防线 2.1)
- 用同 pipeline 生成 200 个**纯随机因子** (random signal 同样 entry/exit 规则)
- 跑同 22m IS backtest
- 真因子 PF / Sharpe 必须 > 白噪声 95 分位
- 白噪声 baseline median 一般 PF ~0.94-0.99

**白噪声击败率必须 ≤ 5%** (理论假阳性). 真因子若 pass rate > 15% = 仍是噪声.

### Step 9: 同 regime walk-forward (防线 2.2)
- **关键**: OOS 段必须**同 regime**, 不能跨 regime (痛史 #5)
- 当前 regime 判断: XAU > $3000 (2025.03.17+) = 新 regime
- 同 regime 14 个月 → 切 7m + 7m walk-forward
- A 段 Sharpe + B 段 Sharpe 不一致 (差 > 2×) = cherry-pick 过拟合 → reject

### Step 10: DeepSeek-R1 评价 (防线 4)
- 跑 `~/.claude/scripts/ds_ask.py --model deepseek-reasoner "评价..."`
- 输出归档到该版本 archive: `<advisor>_review_<date>.md`
- DeepSeek 评分 ≥ 7/10 过拟合风险 = **否决 lock**
- 任何 challenge 必须 explicit 在 MANIFEST 回应

### Step 11: 部署前最终 checklist (防线 5)
- Archive 完整: MANIFEST + EA + INI + DeepSeek review
- 外层 monitor 启 (账户单日 -5% / rolling -15% kill EA)
- EA 内 CircuitBreaker 启 (DailyLoss 10% / Rolling -25%, 不要更激进)
- Paper test 30 天 first
- 通过条件: Sharpe ≥ A 段水平 (e.g. 1.0+ 不是 1.5+)

---

## 2. 防未来函数 SOP — 详细版

### A. 静态扫描 (Step 3 详细)

`/tmp/lookahead_lint.py` 检查的 9 种 pattern (CLAUDE.md 来源):

```python
HIGH_RISK_PATTERNS = [
    r'\.shift\(\s*-\d+',                    # shift(-N)
    r'rolling\([^)]*center\s*=\s*True',     # rolling center
    r'\.bfill\(',                            # bfill
    r'fillna\([^)]*method\s*=\s*[\'\"]bfill',# fillna bfill
    r'pd\.qcut\(',                           # qcut 全样本分位
    r'\.fit\(.+\)\.transform\(',             # 全样本 scaler
]

MEDIUM_RISK_PATTERNS = [
    r'\.iloc\[\s*i\s*\+\s*\d+',             # iloc[i+k] 前向
    r'find_swing\([^)]*right\s*=\s*[1-9]',  # right >= 1 但未补偿
    r'h\.iloc\[\s*i\s*\]|l\.iloc\[\s*i\s*\]', # entry 时刻用 H/L
]
```

CLAUDE.md 提到工具丢了, 需重建. 见 [[05-下一步行动#3. 重建 lookahead_lint.py]].

### B. 运行时 audit (Step 4 详细)

```python
from lookahead_decorator import assert_no_lookahead, LookaheadError

@assert_no_lookahead(margin=10, mask_ratio=0.5, atol=1e-6)
def my_signal(df):
    return df['close'].rolling(20).mean()

# audit:
my_signal._audit(sample_df)  # 不抛 LookaheadError 即通过
```

**原理**:
1. 完整数据算 `signal_full`
2. 把 t > N/2 之后数据 mask 为 NaN, 重算 `signal_masked`
3. 前 `[warmup, N/2)` 段 `signal_full[t]` 必须 == `signal_masked[t]`
4. 不等 = 后段数据影响了前段计算 = lookahead

### C. fractal/swing 时机表 (强制遵守)

| 函数 | t 时刻可知 | 注意 |
|---|---|---|
| `EMA(N)` | t 收盘后 | `.iloc[t-1]` 安全 |
| `Rolling.max(N)` | t 收盘后 | `.iloc[t-1]` |
| `find_swing(left, right=R)` 在 i_b | **i_b + R** 收盘后 | confirm_time += R |
| `MACD divergence` | B swing 之 i_b + 3 之后 | |
| `ATR(N)` 在 t 用于 entry@open[t] SL | ❌ 用 ATR[t-1] | entry 时 t 的 H/L 未知 |
| `find_swing(right=0)` | i_b 当根 | 唯一无 lookahead 但漏点 |

### D. 合法 vs 非法

| 场景 | 合法性 |
|---|---|
| `fwd_ret = close.shift(-N)` 当 IC label | ✅ |
| 数据清洗补全 (不进信号) | ⚠️ 仅完整性 |
| 历史归因描述 | ✅ |
| **信号生成 / 入场决策 / SL/TP 计算** | ❌ 禁 |
| `rolling(center=True)` | ❌ 禁 |
| `bfill()` 在信号上 | ❌ 禁 |
| `pd.qcut` 全样本分位 | ❌ 禁 (用 `rolling.rank()` 替代) |

---

## 3. 防过拟合 SOP — 详细版

### A. 过拟合的 6 个根源 (来自 v8 案例)

| 根源 | 防护 |
|---|---|
| 参数 sweep 在 IS 段做 | sweep 段 + OOS 段时间不交叉 |
| 修饰参数无独立验证 | 任何乘数 / 系数都要 grid sweep + walk-forward |
| 回测后视镜决策 | 砍因子前看跨段表现 (不只看当前段) |
| 因子组合自由度过大 | 6 因子 × 3 modulator 数学上必然过拟合 |
| CSV / 段命名误导 | 命名规范: 写明哪个层级的 OOS |
| lock 时只看 1 个 OOS 数字 | 必须多段一致性测 (前/中/后 + 跨 regime) |

### B. 红线指标 (任一触发立刻 challenge)

| 红线 | 含义 | 应对 |
|---|---|---|
| 胜率 > 60% | XAU 上极不正常 | 立刻找 lookahead |
| Sharpe > 3 | 真 alpha 极少这么高 | challenge 数据 / 段 / 过拟合 |
| CAGR > 50% | XAU 月化 4%+ 不可持续 | challenge |
| MDD < 5% (跨多年) | 几乎不可能 | challenge 数据 / 算法 |
| 任 1 年 > 80% 月正向 | 月度过于一致 | challenge IS 拟合 |
| IS Sharpe / OOS Sharpe > 2.5 | 严重 cherry-pick | reject |

修 lookahead / 过拟合后通常回到: **胜率 45-55%, CAGR -10~+30%, MDD 15-40%**. 这才是真实信号.

### C. OOS 段选择 SOP (新增, from 痛史 #5)

**步骤**:
1. 确认训练段 (lock 时所有参数 sweep 涉及的时间范围)
2. 列出候选 OOS 段:
   - 候选 A: 训练段之前
   - 候选 B: 训练段之后未训练段 (若有)
3. **市场指标对比**: 各候选段 vs 训练段
   - 价格区间 (median, range)
   - 波动率 (日均振幅, ATR/close ratio)
   - 趋势性 (周线 ADX, 月线 Hurst)
4. 计算 regime similarity score = (vol_ratio + price_ratio + trend_ratio) / 3
5. **若 score < 0.7** = 跨 regime, **不验证, 标 N/A**
6. **若 score ≥ 0.7** = 同 regime, 跑 OOS backtest
7. 在 archive MANIFEST 记录: 训练段 / OOS 段 / similarity score

### D. Walk-forward 切割 SOP

**同 regime 内 walk-forward**:
- 假设同 regime 段长度 L (e.g. 14 月)
- 切 K-fold (K=2 或 3)
- 各 fold 段 Sharpe 必须**一致** (差 < 50%)
- 任一 fold Sharpe 远高于其他 = cherry-pick, reject

**示例 (v8 当前)**:
- 同 regime 段: 2025.03.17 - 2026.05.10 (14m)
- K=2 切割: A段 7m (Sharpe 1.46) + B段 7m (Sharpe 4.17)
- **差 2.86×** = cherry-pick 倾向 → 标 ⚠️, forward 预期按 A 段 1.46 估算

### E. 白噪声 baseline SOP

```python
# 生成 200 个白噪声因子
for i in range(200):
    rnd_signal = pd.Series(
        np.random.choice([-1, 0, 1], size=len(df), p=[0.05, 0.9, 0.05]),
        index=df.index
    )
    save(f'rnd_factor_{i}.csv')

# 跑同 pipeline backtest, 收集 PF / Sharpe 分布
# 计算: 真因子 PF 在分布的多少分位?

# 真 alpha 阈值:
- 必须比白噪声 PF 95 分位高
- baseline median PF ~0.94-0.99 → 阈值 ≥ 1.50 通过
- baseline median Sharpe ~0.1 → 阈值 ≥ 1.5 通过
```

### F. Permutation test SOP (来自旧 SOP v20260514, 之前漏了)

**目的**: 验证 EA 在**信号方向被随机翻转**后表现一定差 — 如果不差 = EA 跟信号无关 = 信号是噪声.

```python
# 跑 N=20 次 permutation
for i in range(20):
    # 随机翻转 50% 信号方向
    sig_perm = signal.copy()
    flip_idx = np.random.choice(sig_perm.index, len(sig_perm)//2, replace=False)
    sig_perm.loc[flip_idx] *= -1
    save_csv_to_kk_common(sig_perm, f'perm_{i}.csv')
    run_mt5_backtest(f'perm_{i}.ini')
    collect_pf_profit()

# 判定:
# 真信号 PF 必须 > p99 (max of 20 permutations)
# v20260514_master_aplusplus 案例: 真信号 +295%, max perm +104% → 通过
```

**通过条件**: 真信号 profit / Sharpe 必须 > permutation 分布的 99 分位.
**反之**: 任一 permutation 跑出 ≥ 真信号 = EA 不依赖真信号方向 = 噪声.

### G. Parameter sweep 稳定性测试 (旧 SOP P6.b, 之前漏了)

**目的**: 验证最优参数在 grid 邻域内表现也稳 (不是单点过拟合).

```python
# 对 RR / SL_mult / Hold_time / Risk% 各开 ±20% / ±50% sweep
sweep_params = {
    'RR':       [0.8, 1.0, 1.2, 1.5, 2.0],
    'SL_mult':  [1.0, 1.2, 1.5, 1.8, 2.0],
    'risk_pct': [0.5, 1.0, 1.5, 2.0, 2.5],
}
# 跑 grid 所有组合, 看最优 vs 平均
```

**判定**:
- 最优配置 PF / Sharpe 不能比 grid 平均高 > 30%
- ridge top (最优周围的邻域) 表现接近最优 → 真稳
- 单点最优 (邻域急剧恶化) → **必拟合**, reject

v20260514 案例: 11 配置 sweep 149-504%, 全正, base 在 ridge top → 通过.

### H. Cross-asset 验证 (旧 SOP P6.d, 之前漏了)

**目的**: 在其他相关 asset (e.g. XAGUSD / EURUSD) 重生成 signal CSV + 跑同 EA, 看是否有 alpha.

- 严格版: 必须**重生成 signal CSV** (不是把 XAU 信号搬到 XAG)
- 通过条件: 至少 1 个相关 asset Sharpe > 1, 证明 EA 逻辑不是 XAU-specific 过拟合
- 失败: 仅 XAU work, 其他全死 = XAU-only 过拟合

---

## 4-bis. 完整 P0-P8 工作流 (旧 SOP v20260514 框架, 与本 SOP 11 步互补)

```
[P0] Audit 数据准备     — XAU H1 OHLC, Dukascopy 5y M1+M5 补齐
[P1] 因子开发 5 步       — sanity / OOS WF / MCS-2 / MC bootstrap / 相关性
[P2] 白噪声基线          — 200 random 击败率 ≤ 5%
[P3] State 离线过滤      — HMM 7-state gated CSV (注: 已被 rule-based 替代, 见痛史 #14)
[P4] Master EA 集成      — 多因子 + 共享 equity + portfolio cap
[P5] MT5 真实 backtest  — Python 数字 285× 失真, 不可信
[P6] 4 大过拟合 / 稳定性测试:
     ├── (a) Walk-forward (分段, 同 regime 内)
     ├── (b) Parameter sweep (扰动 RR/SL/Hold/Risk grid)
     ├── (c) Permutation test (信号方向随机翻转 N 次)
     └── (d) Cross-asset (XAG/EUR 重生成 CSV 验证)
[P7] 归档 + 部署         — archive + MANIFEST + 双层熔断 + Python HMM 实时服务 + KK MT5 attach
[P8] 活系统监控 (月度):
     ├── alpha decay 30 天滚动收益跟踪
     ├── HMM + 因子月度重训
     └── 触发熔断时停 EA
```

---

## 4-tris. Alpha decay 监控 SOP (来自 v20260514 案例)

**实测**: v20260514_master_aplusplus 4 段 walk-forward 收益 **85% → 56% → 20% → 15%** — alpha 半衰期 **~6 月**.

**含义**: 任何 lock 后的 EA 都会衰减, **不可"一劳永逸 lock"**.

**监控 SOP**:
```
每月 1 号 (cron):
1. 拉过去 30 天实盘 PnL
2. 算 30 天 Sharpe
3. 跟过去 6 月平均 Sharpe 对比
   - 30 天 Sharpe / 6 月平均 < 0.5  → ⚠️ 衰减, 启 review
   - < 0.3  → 🔴 严重衰减, 停 EA, 重训因子 + 重 lock
4. 同时跑 walk-forward (最近 30 天 OOS) vs lock 时 IS
```

**EA 内置 soft halt**:
- 30 天滚动 PnL < 0 → 暂停新开仓 (soft, 不平已有仓)
- 单日 PnL ≤ -10% → 立即停 + 平所有 (hard)

---

## 4-quart. EA 0-trade 检查清单 (合并版, 完整 15 步)

**任何 0-trade backtest 都是 silent failure**. 部署前必须排除全部 15 项:

### Part A: CSV / Data 层 (旧 SOP 10 项)
1. **CSV 路径** — `FILE_COMMON` flag 时文件必须在 `Common\Files\`, 不在 `MQL5\Files\`
2. **CSV entry_time 时区** — broker server tz (一般 GMT+2/+3 EET), 不是 UTC
3. **FromDate < CSV first entry_time** — 否则 EA 加载但找不到 signal
4. **FindSignalForBar 容差** — `MathAbs(diff) <= 60` (秒), 不能用 == 0
5. **Symbol 不存在** — `SymbolSelect()` 检查
6. **CalcLot 返回 0** — `sl_dist=0` / `tick_value=0` / 算出 lot < broker min lot
7. **AtrZWindow=200 warm-up** — FromDate 必须留 200+ bar buffer
8. **MaxTotalExposurePct < BaseRiskPct** — cap 不够单笔进
9. **CSV direction 字段** — 严格 1/-1, 不能 BUY/SELL string
10. **ExecutionMode/Visual 配置** — Visual=1 + ShutdownTerminal=0 会卡

### Part B: EA 逻辑层 (新增 5 项, 痛史 #12/#14 教训)
11. **lot 计算 SL vs 实际放置 SL 一致** — Scalper20 痛史 #12, 必须 grep 全文同步
12. **RegimeFilter 是否误关所有信号** — `DisableRegimeFilter=true` 才能看真表现
13. **CircuitBreaker 提前触发** — 看 `[CB-HARD]` log, 是否 daily limit 太低过早 halt
14. **RiskPct 全 0** — 检查 lock INI 是否所有 RiskPct 都 > 0 (除明确 cut 的)
15. **EA log 末尾 `[RULEREGIME TESTER]` 行 trades > 0** — 没这行 = EA 没进 OnTester

### 部署前完整验证
- 跑 1 周回测 (Model=2)
- log 必须看到 `[FACTOR_DIST] <factor> allowed=N` 中 N > 0 (至少 1 个 factor)
- log 必须看到至少 10 条 `order performed buy/sell`
- profit 非 0 (即使亏)
- 无 `array out of range` / `division by zero` / `invalid handle`
- backtest 结束 `automatical testing finished` (正常退出)
- **手动验算单笔实际 loss vs 配置 risk%** 是否一致 (验 lot 计算)

任一条 fail = 不能 deploy.

---

## 4. 防 backtest 引擎失真 SOP (防线 3)

**铁律**: Python 模拟不可信, 必须 MT5.

| 工具 | 用途 | 信任度 |
|---|---|---|
| Python (pandas backtest) | 信号生成, 数据预处理 | ❌ 不能用于决策 |
| `clean_backtest.py` (干净 Python 引擎) | 学习参考 | ⚠️ 仅参考 |
| MT5 Strategy Tester Model=2 | 快速 sweep | ✅ PF 可能虚高 10-20% |
| MT5 Strategy Tester Model=1 | 真实 tick | ✅✅ 真实信任 |
| MT5 Forward Test (paper) | 实盘 demo | ✅✅✅ 唯一真理 |

### MT5 backtest 配置标准

```ini
[Tester]
Symbol=XAUUSD
Period=H1
Model=2                          # 快速 sweep 用, 终验用 Model=1
Deposit=10000                    # $10K 标准
Leverage=100                     # 1:100 (实盘水平)
ShutdownTerminal=1               # 必须用 D:\IC-tester\ 不能用主 demo
```

### Spread / commission 影响

实盘:
- IC Markets XAU spread 当前 ~15-30 pt (变动)
- commission $7/lot/side
- swap ~-$3/lot/day (long)

backtest 默认用 broker server "current spread" — 22m IS 段假设跟现在 spread 一致. 跨段 OOS 时 spread 可能不同, 必须用 fixed spread + commission 重测.

---

## 5. 防 lock 决策黑箱 SOP (防线 4)

### 第三方 AI 评价 (强制 lock 前)

工具:
- `~/.claude/scripts/ds_ask.py` (DeepSeek)
- `~/.claude/scripts/gemini_ask.py` (Gemini)

模板 prompt:
```
你是量化策略风险审计员. 下面是 [策略名] 的 lock manifest:
[关键配置 + 22m IS 数据 + 已通过 SOP + 已知缺口]

请输出:
1. 过拟合 / 数据 dredge 风险评分 (1-10) + 具体 challenge
2. MDD 真实风险 + 实盘验证必做项
3. 缺口分类 (上线前必须 / 上线后可做 / 可推迟)
4. 比 lock 更稳的路径 (1-3 step)

简洁犀利, 直接给数字 / 动作.
```

输出归档:
- `~/factor_factory_archive/<version>/deepseek_review_<date>.md`
- `~/factor_factory_archive/<version>/gemini_review_<date>.md` (可选)

### Lock 决策树

```
DeepSeek 评分:
  ≤ 5/10 过拟合风险 → 通过, 可 lock
  6-7/10 → 需补 walk-forward + MC bootstrap, 通过才 lock
  ≥ 8/10 → 否决 lock, 必须修改策略再评
```

---

## 6. 防实盘黑天鹅 SOP (防线 5)

### 三层风控

```
┌──────────────────────────────────────┐
│ [Layer 1] EA 内 DD scaling            │
│   回撤升时缩 lot (Loose: 25-40%)      │
│                                      │
│ [Layer 2] EA 内 CircuitBreaker        │
│   DailyLoss > 10% halt + close all   │
│   Rolling > 25% halt 7d              │
│                                      │
│ [Layer 3] 外层 monitor 脚本           │
│   账户单日 -5% / rolling -15%        │
│   → KILL terminal + 通知用户         │
└──────────────────────────────────────┘
```

**Layer 3 是关键**: backtest 看不到 tail risk 价值, 但实盘黑天鹅日 (e.g. CPI 单日 4%+) 必须有外层 cap.

### Paper test → 实盘 升级阶段

```
Paper test 30 天 ($10K demo)
  ↓ Sharpe ≥ A 段水平
中等实盘 30 天 ($25K demo or $10K real)
  ↓ Sharpe 一致, MDD < 20%
正式实盘 ($50K+ real)
  ↓ 周报 + 月报 + 季度 review
长期持仓 (每月 review per-magic profit)
```

每阶段 fail → 退回上一阶段或直接下架.

---

## 7. Archive 完整模板

每个 lock 版本的 archive 目录必须包含:

```
~/factor_factory_archive/v<YYYYMMDD>_<NAME>/
├── MANIFEST.md           # lock 说明: 改动 / 数据 / 决策依据
├── <EA>.ex5              # 编译好的 EA
├── <EA>.mq5              # 源码 (备份, 防 KK 失联)
├── <NAME>_22m_raw.ini    # 测试 INI (确切配置)
├── <NAME>_22m_raw.htm    # MT5 测试报告
├── deepseek_review_<date>.md  # DeepSeek 评价 (必须)
├── gemini_review_<date>.md    # Gemini 评价 (可选)
├── walk_forward_<date>.md     # walk-forward 结果
└── whitenoise_baseline.md     # 白噪声对比
```

**MANIFEST.md 必须字段**:
1. 版本号 + lock 时间
2. 跟前版的 diff (改了什么, 为什么改)
3. 22m IS 关键指标 (Profit / PF / Sharpe / MDD / Trades)
4. OOS 段定义 (时间 / 数据覆盖 / regime similarity)
5. OOS 实际结果 (vs IS 对比)
6. 已通过 SOP (哪些步骤 done, 哪些 todo)
7. 已知缺口 (上线前必修 / 上线后修)
8. 回滚路径 (退回哪个版本)
9. 部署位置 (broker / 账户 / install)

---

## 8. 常用工具速查

| 工具 | 位置 | 用途 |
|---|---|---|
| lookahead_decorator | KK `C:\Tools\factor_factory\reports\` / mac `/tmp/` | 运行时 audit |
| lookahead_lint | (待重建) | 静态扫描 |
| ds_ask.py | mac `~/.claude/scripts/` | DeepSeek API |
| gemini_ask.py | mac `~/.claude/scripts/` | Gemini API |
| fetch_h1_10y.py | KK `C:\Tools\` | XAU H1 数据拉取 |
| clean_backtest.py | mac `/tmp/` | 干净 Python 引擎参考 |
| factor_factory framework | KK `C:\Tools\factor_factory\` | 全套 framework |
| monitor_ebc3 | (待定位) | EBC 跟单监控脚本 |

---

## 9. 团队工作模式

### 角色 (memory `user_assistant_identity.md`)
- **Joker** (头号): 企微图表, 主决策
- **TT** (次号): 跟单监控
- **VV** (三号): 因子工厂 (用户口述策略 + VV 写代码 + 工厂跑分)

### VV 工作流 (memory `feedback_factor_factory_workflow.md`)
```
用户口述策略
  → VV 写 *_signal.py
  → bash vv_push_factor.sh 推 KK
  → 自动回测评分 (A/B/C/D) 入库
  → UI 看 tier (http://kk-win:8501)
```

### 每日 20:00 备忘录同步
顶层里程碑同步, 任务行只顶层不细节.

---

## 10. 上线 checklist 一页纸 (打印贴墙上)

**部署前必须每项 ✓**:

- [ ] 1. Generator lookahead static scan: 0 CRITICAL
- [ ] 2. Generator lookahead runtime audit: PASS
- [ ] 3. Signal sanity: trades > 100, long/short 平衡
- [ ] 4. EA 编译 0 errors
- [ ] 5. 22m IS backtest trades > 0, log clean
- [ ] 6. 白噪声 baseline 200 个 → 真因子 PF > 95 分位
- [ ] 7. Walk-forward 同 regime 内 K-fold Sharpe 一致
- [ ] 8. DeepSeek 评价 ≤ 7/10 过拟合风险
- [ ] 9. Archive 完整 (MANIFEST + EA + INI + HTM + review)
- [ ] 10. Paper test 30 天 Sharpe ≥ A 段水平
- [ ] 11. 外层 monitor 启动 (单日 -5% / rolling -15% kill)
- [ ] 12. 用户最终批准

12 项任一 fail = **不能上**.

---

## 附录: 红线一句话总结

1. **Sharpe > 3 必 challenge**
2. **MDD < 5% (跨多年) 必 challenge**
3. **胜率 > 60% 必 challenge**
4. **Python 模拟不可信, MT5 only**
5. **未来函数检查必须 runtime audit, 不能只看代码**
6. **OOS 段必须同 regime, 跨 regime 验证无效**
7. **lock 前必须第三方 AI 评价 + 归档**
8. **任何乘数 / 系数都要 grid sweep + walk-forward**
9. **白噪声 baseline 200 个对比, 真因子击败 95 分位才算 alpha**
10. **paper test 30 天 forward 才是终极裁判**
11. **实盘必须外层 kill switch (backtest 看不到价值)**
12. **archive-first, 改任何东西前先快照**

**违反任一 = 必然踩坑**. 见 [[08-犯错经验档案]] 具体案例.
