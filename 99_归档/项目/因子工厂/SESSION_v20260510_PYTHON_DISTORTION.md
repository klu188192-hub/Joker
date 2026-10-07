---
title: 2026-05-10 会话 — Python 失真 285× 颠覆性发现
date: 2026-05-10
tags:
  - 量化
  - 痛史
  - Python失真
  - MT5验证
  - Gemini接入
  - 因子库重判
status: critical
related:
  - "[[INTEGRATED_ANALYSIS_v20260509]]"
  - "[[PORTFOLIO_7FACTOR_XAUXAG_v20260509]]"
  - "[[REALITY_CHECK_v20260509]]"
  - "[[CROSS_TF_SYMBOL_TEST_v20260509]]"
---

# 2026-05-10 会话 — Python 失真 285× 颠覆性发现

> [!danger] 重大教训
> **Python 回测高估 285×**: Plan A Python CAGR 1432% vs MT5 实测 5%
> 比 MEMORY 痛史警告的 50× 还严重 5 倍
> **所有 Python 因子审计结论作废**, 需重判

---

## 1. 关键发现

### 1.1 Python vs MT5 真实差异 (Portfolio_G11_Master baseline 2.4y)

| 指标 | Python 模拟 (Plan A) | MT5 实测 (IC-tester) | 失真 |
|---|---|---|---|
| CAGR | 1432% | **5.0%** | **285×** |
| Sharpe | 5.46 | **0.92** | 5.9× |
| MDD | 11.91% | 10.05% | 接近 ✓ |
| PF (各因子) | 1.5-2.7 | **1.0-1.2** | 显著缩水 |

### 1.2 反转: 之前 Python 判读全错

| 因子 | Python 判读 | MT5 实测真相 |
|---|---|---|
| **VP_POC** | 白噪声 88% 击败 = 假信号 删除 | PF **1.142** 微赚, 应保留 |
| **Liquidation v6** | PF 1.82 强真 alpha | PF **0.902** 实测亏 -$56, 必删 |
| **Session+Fib** | PF 1.62 边缘 | PF **1.166** 反而正贡献 |
| **PureBO** | PF 1.91 主力 | PF **1.087** (跟白噪声 1.51 比是负 alpha?) |

### 1.3 原以为白噪声 PF 中位数 1.51 也是 Python 幻觉

之前所有"白噪声击败率 ≤ 5% = 真 alpha"判读基于 Python 跑出来的 PF 1.51.
本次尝试用 MT5 跑 RandomSignal_v1 EA 验证, 发现:
- MT5 MathRand 在 Strategy Tester 中是 deterministic (改 seed 没用)
- 改用自己的 LCG 后, 跑出来的 7 个有效 seed **全部亏损**
- MT5 真实白噪声 PF 中位数 < 1.0 (而不是 Python 给的 1.51)
- → PureBO MT5 PF 1.087 **可能不是负 alpha**, 反而是中性偏正

---

## 2. 当前 MT5 真实因子库 (替代之前所有 Python 数据)

### 2.1 Portfolio baseline (MT5 IC-tester, 2024-01-02 ~ 2026-05-04)

```
Final balance: $11,248.67 (initial $10,000)
Net: +$1,248.67 = +12.5% / 2.4y
CAGR: ~5.0%/年
MDD: 10.05%
PF: 1.092
Sharpe: 0.92
n: 2,027 trades
```

### 2.2 各因子贡献 (按 net 排序)

| Magic | 因子 | n | WR | Net | PF | 状态 |
|---|---|---|---|---|---|---|
| 57181 | PureBO | 829 | 90.1% | **+$514** | 1.087 | ✅ Tier 1 |
| 57187 | XAU/XAG | 785 | 92.1% | **+$419** | 1.103 | ✅ Tier 1 |
| 57183 | Session+Fib | 214 | 83.6% | +$312 | 1.166 | ✅ Tier 1 (注释 disable 但实跑) |
| 57182 | VP_POC | 96 | 83.3% | +$151 | 1.142 | ⚠️ Tier 2 |
| 57185 | Gap_Reject | 3 | 66.7% | +$75 | 4.335 | ⚠️ n=3 不可信 |
| 57184 | **Liquidation v6** | 100 | 89% | **-$56** | **0.902** | ❌ 必删 |
| 57186 | Divergence | - | - | - | 0.83-0.93 | ❌ EA 注释 OFF |

### 2.3 LiqHunt v1 (单 EA 候选)

- Magic: 57181 (跟 PureBO 撞) → 已修 57188
- 单 EA MT5 实测: **+5.05% / 2.4y, ~161 trades**
- 唯一架构上不依赖 trail 红利的真 alpha 候选
- 当前 swing_lookback=50, sl=2.5, tp=3.0, ts=12, NO trail

### 2.4 待 MT5 验证 (Python 数据全废)

- PureBO_H4
- Intraday_Mom (Python PF 1.78 Sharpe 5.59 全失真)
- Donchian_24 / 48
- Pullback_v2 (Python PF 1.32 grid search 出来)
- Divergence (重测验证 EA 注释)

---

## 3. Gemini API 因子分析师接入

### 3.1 配置
- Helper: `/Users/joker/.claude/scripts/gemini_ask.py`
- Key: `/Users/joker/.claude/secrets/gemini_api_key`
- System prompt: `/Users/joker/.claude/prompts/factor_analyst_system.md`
- 模型: gemini-2.5-flash 免费 1500/day

### 3.2 Gemini 多轮判读 (基于 Python 数据, 但中后期被 MT5 真相反驳)

| 轮次 | Gemini 判读 | 实际验证 |
|---|---|---|
| R1 全库审查 | 推荐 Tier 划分 PureBO 0.010 主力 | 基于失真数据 |
| R1 Black swan 分析 | PureBO_H4 黑天鹅 36.8% 风险 | 基于失真数据 |
| R2 真数据反驳 | "PureBO PF 1.087 < 白噪声 1.51 = 负 alpha" | 1.51 基线本身失真 |
| R3 战略 70h | 70h 全部修 Python-MT5 失真 | 用户决定 MT5-only |

### 3.3 Gemini 仍有价值的洞察
- 高 WR 低 R/R 模式对成本敏感的数学论证 (PF 1.087 → spread +$0.05 即崩)
- 强调多 broker 分散 + spread filter 重要性
- "无 trail 是真 alpha 试金石" 的方法论

---

## 4. 战略决策: 完全切到 MT5-only Workflow

### 4.1 分工

| 用途 | 工具 |
|---|---|
| 写 EA 代码骨架 | Python (生成 mq5 模板) |
| Lookahead 静态扫描 | Python (lookahead_lint.py) |
| 数据探索/画图 | Python |
| **因子开发审计** | **MT5 Strategy Tester** |
| **参数 grid search** | **MT5 Optimization 模式** |
| **组合权重测试** | **Portfolio EA + 多 ini 文件** |
| **白噪声基线** | **MT5 + LCG-fix 后 EA** |

### 4.2 新因子准入门槛 (Gemini 给 + 用户接受)
- 单因子 MT5 PF ≥ 1.3 (入库最低)
- 组合整体 MT5 PF ≥ 1.5 (上线最低)
- Walk-forward 跨年 PF ≥ 1.2 (稳定性)
- **当前 Portfolio PF 1.092 不符合上线标准, 严禁实盘**

### 4.3 Python 失真要真修需 70h+ 工作 (暂不修)
- 修 backtest engine 加真实 spread/slippage 模型
- 改 position sizing 从 fixed lot → risk-based
- 集成 EA 所有 filter (spread/regime/range/H4 confluence)
- 修 trail 一致性 (trail_fixed_usd 单位/触发时机)
- 数据源对齐 (CSV vs broker history 时间戳)
- 验证 Python vs MT5 同 EA 差异 < 5%

---

## 5. 5 个候选真 alpha 因子 + Alpha 逻辑 (用户准备组合)

### 5.1 PureBO (Magic 57181) - 突破延续
- **信号**: close > 前 10 H1 high → +1 (反向同理)
- **Alpha 逻辑**: 黄金趋势启动突破跟随, 多头吃完空头止损
- **退场**: SL 4.5 ATR / TP 1 ATR + trail 0.3/0.3
- **MT5 实测**: n=829 WR 90% PF 1.087 +$514

### 5.2 XAU/XAG Ratio (Magic 57187) - 跨资产均值回归
- **信号**: ratio = XAUUSD/XAGUSD, |z| > 2 反向 (240H1 lookback)
- **Alpha 逻辑**: 金银比长期均值回归 80, 极值偏离修复
- **退场**: SL 4 ATR / TP 1 ATR + trail
- **价值**: 唯一基于宏观相关性, 跟技术派天然低 corr
- **MT5 实测**: n=785 WR 92% PF 1.103 +$419

### 5.3 Session+Fib (Magic 57183) - 扫荡 + Fib 共振
- **信号**: Asia/London/NY sweep + Fib 0.618 回踩反转
- **Alpha 逻辑**: 大资金扫止损 + 散户技术派共振
- **退场**: SL 4 ATR / TP 1 ATR + ToD filter (排除 20-22 UTC)
- **MT5 实测**: n=214 WR 83.6% PF 1.166 +$312

### 5.4 VP_POC (Magic 57182) - 微观结构反转
- **信号**: 100-bar POC + LVN 反向 + pin bar 拒收
- **Alpha 逻辑**: POC 公平价值, LVN 流动性缺口, 价格穿越后回归
- **退场**: SL 4.5 ATR / TP 0.7 ATR + ToD filter
- **MT5 实测**: n=96 WR 83% PF 1.142 +$151 (n 较少)

### 5.5 LiqHunt v1 ⭐ (Magic 57188) - 趋势中扫荡反转 (无 trail)
- **信号**: EMA50>EMA200 + low<前 50 H1 swing low + close>swing low → SHORT (反转)
- **Alpha 逻辑**: 趋势中扫多头止损后, 反转启动 (反直觉, 不是顺势)
- **退场**: SL 2.5 ATR / TP 3 ATR / time_stop 12 H1 / **NO TRAIL**
- **唯一价值**: 架构上不依赖 trail 红利
- **MT5 单 EA**: +5.05% / 2.4y, ~161 trades

---

## 6. 阻塞点 + 未处理事项

### 6.1 MT5 弹窗根因 (双重: copier agent 双实例 + IC-tester Optimization)

**根因 1 (主因, 来自 MEMORY 23 行)**: KK 上 copier agent 双实例
- 实测 KK 当前 11 个 python 进程 (9 个 5/8 启动 + 2 个今天 12:48 启动)
- terminal64 从 5 个掉到 1 个 = 有进程在 kill MT5
- 用户应 ssh kk 杀掉重复 python 进程, 只留一份 copier agent

**根因 2 (次因)**: 我的 grid optimization
- IC-tester Optimization 模式触发 18 Agent 并发登录
- PowerShell loop ShutdownTerminal=1 每 seed 重启
- 解决: Tester Settings → Local Agents 设 1 (或 Offline 模式)

### 6.2 LiqHunt v1 优化 (待 IC-tester 设置完成)
- ✅ Magic 57181 → 57188 修复
- ✅ OnDeinit 加 [METRIC] 输出
- ⏸ Grid: SwingLookback 20-70 + R/R 矩阵
- ⏸ 集成 Portfolio_G11 + A/B 测试

### 6.3 EA Bug 待查
- Liquidation v6 注释 enable=false 但实测仍跑 100 trades (.set 文件覆盖?)
- Session_Fib 注释说 PF 0.884 但实测 PF 1.166 (参数版本不同步?)

### 6.4 真 alpha 候选待 MT5 单测
- PureBO_H4 / Intraday_Mom / Donchian / Pullback / Divergence 全部待重测

---

## 7. 关联文档

- 之前: [[INTEGRATED_ANALYSIS_v20260509]] (基于失真 Python 数据, 已废弃多数结论)
- 之前: [[PORTFOLIO_7FACTOR_XAUXAG_v20260509]] (Tier 划分基于幻觉)
- 之前: [[REALITY_CHECK_v20260509]] (痛史警告 50×, 但实际是 285×)
- 之前: [[CROSS_TF_SYMBOL_TEST_v20260509]] (XAG/BTC 失败, 但 XAU H4 候选数据待 MT5 重测)
- MEMORY: feedback_python_distortion_285x.md
- MEMORY: project_factor_library_v20260510.md
- MEMORY: project_open_tasks_20260510.md
- MEMORY: reference_gemini_api.md

---

## 8. 下次会话首读

恢复时按 next 顺序:
1. 用户**本地解决 IC-tester Local Agents 设置** (减弹窗)
2. 跑 LiqHunt grid 优化 (swing_lb 20-70 + R/R, 找 PF≥1.3 + n≥200 配置)
3. LiqHunt 集成进 Portfolio_G11_Master + A/B 测
4. PureBO_H4 等其他候选写独立 EA + 单 MT5 测
5. 修 EA bug (Liquidation enable / Session_Fib 参数版本)
