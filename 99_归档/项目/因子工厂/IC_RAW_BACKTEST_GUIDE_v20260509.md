---
title: IC RAW 真实 Strategy Tester 5y Backtest 操作指南
date: 2026-05-09
status: ready_to_run
note: SSH 无法触发 GUI, 必须 KK 上手动操作
---

# IC RAW MT5 Strategy Tester 5y Backtest 指南

> [!warning] 必须 KK GUI 操作
> SSH 命令模式启动 terminal64.exe /config 30秒退出 (detected another instance), 必须用 GUI 触发. Python factor_factory + spread 15pts 模拟已验证: avg Sharpe 2.24 ⭐.

## 已准备就绪

```
EA 已编译 (D:/EBC-mt5/MQL5/Experts/):
  ✅ PureBreakout_Trail_v1.ex5  (G+1.1: 1% + 关马丁, Magic 57181)
  ✅ VP_POC_Reversion_v1.ex5    (G+1.1: ToD filter, Magic 57182)
  ✅ Liquidation_v6.ex5          (G+1.1: 0.75%, Magic 57184)
  
EA 已 copy 到 IC-tester (D:/IC-tester/MQL5/Experts/):
  ✅ PureBreakout_Trail_v1.ex5

待写 EA:
  ❌ Session+Fib (Magic 57183, 含 ToD filter)
  ❌ Gap_Reject_v3 (Magic 57185)
  ❌ XAU_XAG_Ratio_v1 (Magic 57187)
  ❌ Divergence_archive (Magic 57186, 需要 daily_stop, Phase 4)

INI 配置已 scp:
  ✅ D:/IC-tester/tester_purebo_icraw.ini
```

## 步骤 — 在 KK GUI 上跑 PureBO 5y backtest

### 1. RDP 到 KK

```
RDP: kk-win 或 100.105.10.32
账户: Administrator
```

### 2. 启动 IC-tester MT5

```
双击 D:\IC-tester\terminal64.exe
登录 IC RAW demo 账户
等待自动同步历史数据 (5y XAU H1 第一次同步可能 5-10 分钟)
```

### 3. 强制下载 5y 历史数据

```
Tools → History Center (F2)
选 XAUUSD → H1
点 Download (可能需要等几分钟)

确认数据范围: 2021.01.01 ~ 2026.05.01
```

### 4. 启动 Strategy Tester

```
View → Strategy Tester (Ctrl+R)
设置:
  Expert:    PureBreakout_Trail_v1
  Symbol:    XAUUSD (或 IC RAW 实际 symbol 名)
  Period:    H1
  Date:     2021.01.01 - 2026.05.01
  Model:     Every tick based on real ticks (or "1 minute OHLC" 较快)
  Deposit:   10000 USD
  Leverage:  1:500
  Optimization: Disabled

EA Inputs (确认):
  RiskPerTrade   = 1.0
  UseMartingale  = false
  UseCompound    = true
  MaxLotCap      = 5.0

→ Start
```

### 5. 等待结果 (5-30 min)

```
完成后 → Report tab
关键指标:
  Total trades
  Profit factor
  Drawdown %
  Sharpe ratio
  Net profit

→ Right click → Save report as HTML
```

### 6. 跟 Python 模拟对比

```
Python factor_factory + spread 15 pts 模拟 (5y):
  PureBO: PF 1.85, Sharpe 3.78, MDD 14.36%, CAGR +64%
  
如果 IC RAW 实测在 ±20% 之内, 验证完成
如果 < 50% 或 > 200%, 检查 spread / commission / 历史数据完整性
```

## VP_POC + Liquidation 同样流程

跑完 PureBO 后, 重复步骤 4-6:
- VP_POC_Reversion_v1 (Magic 57182)
- Liquidation_v6 (Magic 57184)

## 关键观察点

```
1. 实际 IC RAW 平均 spread (在 Tools → Symbols → XAUUSD 看):
   预期 8-15 pts (如果 > 25 pts 说明不是真 RAW account)

2. Strategy Tester 显示的 spread (顶部 stats):
   每笔 trade 的 spread 应该 ≤ 15 pts

3. Slippage (Symbol settings):
   IC RAW ECN 通常 ≤ 5 pts
   差点差 broker 可能 > 20 pts
```

## 为什么 SSH 无法触发

```
1. terminal64.exe /config 模式 detect 已有 portable instance → 30s 退出
2. metatester64.exe 是 distributed agent, 不是单机 backtester
3. MT5 Strategy Tester 设计为 GUI 互动模式
4. 无法 RDP 远程控制 GUI 实现自动化 (没有 PowerShell SendKeys 适配)

解决方案:
  - GUI 手动 (本文档)
  - 或 Python factor_factory 模拟 (已做, Scenario 4 avg Sharpe 2.24)
```

## 替代: 用 dukascopy ASK + BID 数据 (可 SSH 跑)

如果不想在 KK GUI 操作, 我可以:
1. 拉 dukascopy 5y XAU ASK + BID 数据 (1 年已有, 5 年要再下)
2. 算真实 spread (而非假设 15 pts)
3. 用 factor_factory 真实 spread 重跑 7 因子

这是 100% SSH 可触发的, 但 spread 不是 IC RAW 实际值, 是 dukascopy ECN 真实值 (mean 66 pts).

> 关键: dukascopy 真实 mean 66 pts 也比 default 30 pts 严格 (already tested).
> IC RAW 真实 spread 必须 GUI 实测, 没有 SSH 替代.

## 现在 → 你需要做的

```
☐ 选 1: KK GUI 手动跑 PureBO 5y backtest (30 分钟)
☐ 选 2: 接受 Python 模拟结果 (Scenario 4: avg Sharpe 2.24), 直接部署
☐ 选 3: 先看 IC RAW symbol 实际 spread 数 (5 分钟 GUI 查询), 决定是否需要真实回测
```
