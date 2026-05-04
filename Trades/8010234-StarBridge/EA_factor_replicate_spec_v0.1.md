# 李德江盈利因子 → EA 复刻规格（v0.1 spec）

> 基于 30 天 / 377 笔实盘 XAU 数据的因子分析（Obsidian: `Trades/8010234-StarBridge/factor_analysis_2026-05-04.md`）。
> 本文档把发现的高显著盈利因子翻译成可执行的 EA 过滤逻辑 + MQL5 参数 + 决策伪代码。

## 一、因子→规则映射

| 因子（实盘观察） | EA 实现规则 | 参数 |
|---|---|---|
| 手数 1-2 = 高确信信号（PF 45） | 把信号分级：A=高确信→1-2手；B=低确信→0.05-0.5手 | `InpVolHighConf=1.5`, `InpVolLowConf=0.1` |
| 持仓 ≤1m WR 94.7% | 入场后 60s 内若没到 TP 也没到 SL，则按超时逻辑评估 | `InpScalpMaxSec=60`, `InpScalpExitMode=tp_or_close` |
| 不挂 SL，扛单 / 手动管理 | EA 不挂硬 SL，改用浮亏熔断（绝对金额或 % 触发市价平仓） | `InpUseHardSL=false`, `InpEquityCutoffPct=2.0` |
| TP 触发占 32%，每次 +$336 | TP 设定要保证 32% 命中率（不能太远） | `InpTPDistance=动态` 见下 |
| UTC 14/19/04/10 时段甜区 | 时段白名单 | `InpSessionWhitelist="04,10,14,19"` |
| UTC 7/9 禁区 | 时段黑名单 | `InpSessionBlacklist="07,09"` |
| 持仓 >30m 吃亏 | 强制超时平仓 | `InpMaxHoldMin=30` |

## 二、EA 决策树（伪代码）

```
OnNewBar(M1):
    hour_utc = TimeUTC.Hour
    if hour_utc in InpSessionBlacklist: return
    if hour_utc not in InpSessionWhitelist and InpStrictSession: return

    sig = EvaluateSignal()       // 你已有的 SMC / 均线 / 形态等
    if sig.confidence == NONE: return

    confidence = sig.confidence  // HIGH | LOW

    // 手数分档
    lots = (confidence == HIGH) ? InpVolHighConf : InpVolLowConf

    // 不挂硬 SL，挂宽 SL（broker 强平保护）+ 浮亏熔断
    sl_safety = entry_price + ATR * 5 * dir   // 5×ATR 远 SL，主要防隔夜爆仓

    // TP 距离按持仓类型
    tp_distance = (target_scalp) ? ATR * 0.8 : ATR * 2.5
    tp_price = entry_price + tp_distance * dir

    OpenOrder(lots, sl_safety, tp_price, comment="A1_L_b1")

OnTick:
    for each open position:
        held_sec = TimeUTC - position.open_time
        floating = position.profit

        // 浮亏熔断
        equity_pct = (-floating) / account.balance * 100
        if equity_pct >= InpEquityCutoffPct:
            ClosePosition()
            continue

        // 剥头皮超时
        if held_sec > InpScalpMaxSec and floating > 0:
            ClosePosition()  // 既然 1 分钟没到 TP，浮盈先兑现
            continue

        // 整体超时
        held_min = held_sec / 60
        if held_min > InpMaxHoldMin:
            ClosePosition()
            continue
```

## 三、参数 default

| 参数 | 类型 | 默认 | 说明 |
|---|---|---|---|
| `InpVolHighConf` | double | 1.5 | A 级信号手数 |
| `InpVolLowConf` | double | 0.1 | B 级信号手数 |
| `InpScalpMaxSec` | int | 60 | 剥头皮超时（秒） |
| `InpMaxHoldMin` | int | 30 | 全局超时（分钟） |
| `InpUseHardSL` | bool | false | 是否挂硬 SL |
| `InpEquityCutoffPct` | double | 2.0 | 浮亏熔断（账户余额 %） |
| `InpSessionWhitelist` | string | "04,10,14,19" | 允许时段（UTC 小时） |
| `InpSessionBlacklist` | string | "07,09" | 禁止时段 |
| `InpStrictSession` | bool | false | 严格白名单（true=只在白名单时段交易；false=黑名单优先） |

## 四、风控护栏（必须的）

1. **单日最大笔数** `InpMaxTradesPerDay=20`（19/天是李德江实盘均值）
2. **同方向最大持仓数** `InpMaxConcurrentPerSide=3`（防一边倒堆叠）
3. **总浮亏熔断** `InpTotalEquityCutoffPct=5.0`（所有持仓浮亏总和达 5% 全平）
4. **连亏暂停** `InpMaxConsecutiveLoss=3` + `InpPauseMinutes=15`

## 五、信号评级源（A 级 / B 级入场条件）— **Task B 已回填 ✅**

> 基于 38 笔 ≤1m WR 94.7% 单的逆向（详见 Obsidian/Trades/8010234-StarBridge/lidejiang_sub1m_features.csv）

**A 级信号 = 高确信度入场（手数 1-2）**：

```
条件 1: 时段 UTC ∈ [11..19]                          // 33/38 笔在此
条件 2: M1 触发 K 方向明确，回踩入场：
        - 多向：bull K（close > open），entry ≤ (high+low)/2
        - 空向：bear K（close < open），entry ≥ (high+low)/2
条件 3: 不要求 M5 EMA20 同向（实测 82% 入场不在 M5 EMA20 同侧）
条件 4: 最近 5 根 M1 bull_count ∈ [1, 4]（避开 0/5 极端单边）
条件 5: M1 ATR(14) > 2.0（过滤极静止市场）

5 条全满足 → A 级 → InpVolHighConf=1.5
```

**B 级信号 = 低确信度（手数 0.05-0.5）**：
- 任一条件不满足，但触发 K 方向明确 + 不在禁区时段 → B 级

**完全跳过**：UTC 7/9 / doji K / ATR < 2

### Task B 数值证据

| 维度 | 38 笔统计 |
|---|---|
| BUY × bull K | 19 笔（占 BUY 26 的 73%）|
| BUY × bear K | 7 笔（反转尝试少数）|
| SELL × bear K | 11 笔（占 SELL 12 的 **92%**）|
| SELL × bull K | 1 笔（罕见）|
| BUY 入场在 K 中下半 | mean 0.36 |
| SELL 入场在 K 中上半 | mean 0.59 |
| 入场不要 M5 EMA20 同向 | 31/38 = 82% |
| 最近 5 根 M1 bull count | mode=2 / 多数 1-3 |
| M1 ATR(14) | mean 4.09 |
| 时段 UTC 11-19 | 33/38 = 87% |

**核心模式**：M1 顺势 K + 回踩入场 + 1 分钟内 TP 退出。**不要** M5 EMA20 高 TF 确认（这是他的 edge）。

### 原本待 Task B 的提问（保留供历史）

李德江的 confidence = 手数。我们要逆向：**哪些 setup 让他下 1-2 手？**

下一步任务（**Task B 深挖**）会输出 38 笔 ≤1m 高胜率单的共同 setup（M1/M5 上下文 + ATR + 入场位置 + 前置 K 形态）。这些就是 A 级信号的入场条件。

待 Task B 完成后回填本文档第 V 节。

## 六、回测验证流程

1. 把上面 EA 用 Scalper20_Pro 框架改造（已有信号库 + 风控层 + 面板，只需替换信号过滤 + 风控参数）
2. 在 MT5 测试器上用 30 天历史 XAUUSD 数据回测
3. 对比指标：
   - 总盈亏 vs 李德江实盘 +$26,561
   - 笔数 vs 实盘 377
   - PF vs 1.55
   - WR vs 65.5%
4. 如果回测 PF >= 1.30 + WR >= 60% + 期望/笔 > $30，部署 EBC-3 / 57169 demo 前向测试 1 周
5. Forward 一致性 >= 80% → 移到实盘

## 七、当前阻塞

- [ ] Task B（≤1m 深挖）输出后回填 §V "A 级信号入场条件"
- [ ] 57170 终端 trade_allowed=False 需 GUI 操作启用（这是另一回事）
- [ ] EA 框架选定：基于 Scalper20_Pro v2.10 改 / 还是新建

---

*v0.1 · 2026-05-04 · TT 写于因子分析后 30 分钟内*
