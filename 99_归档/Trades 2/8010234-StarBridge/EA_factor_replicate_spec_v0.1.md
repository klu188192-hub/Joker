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

| 参数                    | 类型     | 默认            | 说明                                |
| --------------------- | ------ | ------------- | --------------------------------- |
| `InpVolHighConf`      | double | 1.5           | A 级信号手数                           |
| `InpVolLowConf`       | double | 0.1           | B 级信号手数                           |
| `InpScalpMaxSec`      | int    | 60            | 剥头皮超时（秒）                          |
| `InpMaxHoldMin`       | int    | 30            | 全局超时（分钟）                          |
| `InpUseHardSL`        | bool   | false         | 是否挂硬 SL                           |
| `InpEquityCutoffPct`  | double | 2.0           | 浮亏熔断（账户余额 %）                      |
| `InpSessionWhitelist` | string | "04,10,14,19" | 允许时段（UTC 小时）                      |
| `InpSessionBlacklist` | string | "07,09"       | 禁止时段                              |
| `InpStrictSession`    | boola  | false         | 严格白名单（true=只在白名单时段交易；false=黑名单优先） |

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

## 八、v0.2 路径修正（2026-05-06 · 9 版回测全员失败后的反思）

### 1. 反思：v0.1-v0.9 为什么 PF 都达不到 1.55

v0.1 的根本假设错了——它把李德江的"金钥匙"理解成 **入场信号本身**，所以 EA 拼命模仿他在哪一根 K 上 BUY/SELL（§V "A 级信号入场条件"那 5 条）。但 9 版回测 PF 全在 0.6–1.1 之间，越调越差。

真正的原因：**李德江的两把最强金钥匙（🔑1 vol=1-2 / 🔑2 dur≤1m）都不是入场信号，是出场行为信号**。把它们当入场过滤器用 = 用错维度。

### 2. 两把金钥匙的真实逻辑（重新解读）

#### 🔑1 `vol_bucket=1-2 lot` ≠ 神奇的仓位区间

仓位是李德江**主观确信度的物理外化**，不是机械 Kelly 计算：

| 仓位 | 内在含义 | 30天WR | 30天PF |
|---|---|---|---|
| 0-0.5 lot | 试探单 | – | – |
| 0.5-1 lot | "看着像但没把握" | 68.9% | 1.59 |
| **1-2 lot** | **"我看准了，重砸"** | **88.9%** | **45.66** |
| 2+ lot | 情绪上头 / 抗单加码 | 中等 | 易出陷阱（如 5/6 16:33 那笔 2.97 lot） |

**钥匙真实意义**：仓位是"信心"的可观察代理变量。`vol >= 1` 这个 trigger = "李德江对这单的确信度跨过了他的内部阈值"。

**正确用法**：在 copier 入口做仓位过滤——只镜像 1 ≤ vol ≤ 2 的开仓单，自动跳过试探单和抗单加码。

#### 🔑2 `dur≤1m` ≠ 短持仓有 edge（**这是个数据陷阱**）

直觉以为"持仓越短胜率越高"是市场结构 edge，**错**。真实因果是：

> 李德江赢了立刻跑（被分到 ≤1m 桶），输了抗着（被分到 >30m 桶）。
> 所以"≤1m"标签 **自动只筛出赢单**——亏单都被他抗成长持。

证据：
- `dur ≤1m` → WR 94.7%（38 单）/ mean +$405
- `dur >30m` → WR 50.7%（75 单）/ mean **-$43**

**钥匙真实意义**：李德江有两个**不对称**能力：
- ✅ 1 分钟内识别盈利信号 + 立刻锁定（真 edge）
- ❌ 1 分钟内识别错误 + 立刻止损（这他做不到，硬抗 → 陷阱❌1 全亏 $32K）

**正确用法**：copier 镜像每一笔单时，**强制 1 分钟硬性 timeout 退出**（无视盈亏），把"快出"行为对称地施加到所有单上——拿走他的 edge（快出锁利）+ 砍掉他的弱点（远 SL 抗单）= 净改善。

### 3. v0.1 → v0.2 路径切换（核心）

|  | v0.1（机械复刻入场） | **v0.2（行为修复）** |
|---|---|---|
| 信号来源 | EA 自产 M1/EMA/ATR/时段信号 | **直接订阅 8010234 master OPEN event** |
| 主路径 | EA 独立交易 | **copier 跟单 + 入口 filter + 出口 constraint** |
| 用 🔑1 | 给 EA 信号分级 → A 级开 1.5 lot | **只镜像 1 ≤ vol ≤ 2 的开仓信号** |
| 用 🔑2 | 60s 没到 TP 就出场 | **所有镜像单强制 60s timeout 平仓**（不论盈亏） |
| 用 ❌1 | `InpUseHardSL=false` + 浮亏熔断 | **每个镜像单强制硬 SL = entry ± 8 pips**（XAU），切断抗单陷阱 |
| EA 路径角色 | main | **fallback**（master 离线时启用） |

### 4. v0.2 copier 跟单伪代码

```python
def on_master_open(event):
    # 🔑1 仓位过滤（关键过滤器）
    if event.volume < 1.0:
        log.skip("试探单"); return
    if event.volume > 2.5:
        log.skip("情绪/抗单加码"); return

    # ❌1 切断抗单陷阱：强制硬 SL（master 自己不挂 SL，我们替他挂）
    sl_pips = 8 if event.symbol == 'XAUUSD' else 20  # BTC 等其他符号待标定
    pip = symbol_pip(event.symbol)
    if event.dir == 'BUY':
        sl_price = event.entry - sl_pips * pip
        tp_price = event.tp if event.tp else event.entry + 12 * pip
    else:
        sl_price = event.entry + sl_pips * pip
        tp_price = event.tp if event.tp else event.entry - 12 * pip

    slave_ticket = copier.mirror(
        symbol=event.symbol,
        direction=event.dir,
        volume=event.volume * BALANCE_RATIO,
        sl=sl_price,                     # 替 master 加硬 SL
        tp=tp_price,
    )

    # 🔑2 强制 60s 快出（无视盈亏）
    schedule(slave_ticket, sec=60, action="market_close")

def on_master_close(event):
    # 镜像 master 主动平仓动作（如果已存在镜像单且未 timeout）
    if has_mirror(event.master_ticket):
        copier.close(mirror_of(event.master_ticket))
```

### 5. 预期改进（vs 李德江原始 30 天 +$26,561 / PF 1.55）

| 改造点 | 预期效果 |
|---|---|
| 砍掉试探单（vol < 1，约 200/377 笔） | 笔数 ↓ 53%、总盈利 ↓ 但单笔均值 ↑ |
| 砍掉抗单加码（vol > 2.5，约 5-10 笔） | **避开最大几笔陷阱**（含 5/6 -$1,883 -$1,974） |
| 强制硬 SL 8 pips | **❌1 那 74 单从 -$32K 收敛到 ~-$8K** |
| 强制 60s timeout | 把"被抗成 5-30m"的单提前砍仓，平均改善 |

理论 PF：1.55 → **2.0–2.4**（最大改善来自砍 ❌1 陷阱）

### 6. v0.2 阻塞 / 待验证

- [ ] **copier 协议层**：coordinator/server.py 是否能在 ingress 拦截 master event 做 vol 过滤？还是要在 agent/agent.py slave 端拒单？（需 read 代码确认插入点）
- [ ] **slave 单加自定义 SL/TP**：当前 copier route 是按 master 1:1 复制还是允许 override？（route id=4 8010234→57171 max_lot=0.1，看现有协议是否支持 sl/tp override）
- [ ] **timeout 实现**：外部 watchdog 进程 vs 协议内置定时器（推荐外部，解耦）
- [ ] **hindsight backtest**：把 377 笔按 v0.2 规则重放（vol filter + sl 8pip + 60s timeout），看模拟净 PnL 是否真到 $30K+ / PF 2.0+
- [ ] **8 pip SL 标定**：8 pip 是粗估，需要看 ❌1 那 74 单实际"如果 SL 在 8 pip 触发会怎样"的反事实

### 7. 部署节奏

1. **本周**：拿 30 天数据做 hindsight backtest（无需新代码，直接 pandas 模拟规则）→ 验证 PF 假设
2. **PF 假设站住** → 改 copier ingress filter（最小改动）+ 单独写 timeout watchdog
3. **57171 demo 跑 1 周**：观察实际 vs hindsight 一致性
4. **一致性 > 80%** → 上 EBC-3 / 57169 实盘小额验证
5. **EA 路径**（v0.1 的 §V）继续保留，作为 master 链路异常时的独立信号源

---

*v0.1 · 2026-05-04 · TT 写于因子分析后 30 分钟内*
*v0.2 · 2026-05-06 · TT 写于 9 版回测全员失败 + 重新拆解金钥匙真实逻辑后*
