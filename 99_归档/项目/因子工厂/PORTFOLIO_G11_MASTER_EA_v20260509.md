---
title: Portfolio G11 Master EA — 7 因子集成 + Portfolio 熔断 + Daily Stop
date: 2026-05-10
status: compiled_ready_v2
target: IC RAW
related:
  - "[[G11_DEPLOYMENT_PLAN_v20260509]]"
  - "[[SCHEME_G1_1_BROKER_SHIFT_v20260509]]"
---

# Portfolio_G11_Master.mq5 — 7 因子集成 (7/7 全实现, v2.0)

## 命名说明（2026-05-10 修正）

旧名 `ScalperPro_G11_Master.mq5` 是 CC 拍脑袋命名, 不在框架文档体系内.
统一规范命名: **Portfolio_G11_Master.mq5**, 对齐:
- 框架: `PORTFOLIO_7FACTOR_XAUXAG`
- 方案: `G+1.1` (broker shift + ToD filter)
- 角色: `Master` (vs 独立 EA)

## 架构

```
1 EA + 1 Chart 跑所有 7 因子
Master Magic = 57180 (识别 EA 实例)
Sub-magic 区分 trade 来源 (跟独立 EA 兼容):
  57181 PureBO
  57182 VP_POC (含 ToD filter)
  57183 Session+Fib  ← v2 新增
  57184 Liquidation v6
  57185 Gap_Reject v3
  57186 Divergence + daily_stop  ← v2 新增
  57187 XAU/XAG ratio
```

## v2 vs v1 差异

| 维度 | v1 (旧 ScalperPro) | v2 (Portfolio_G11) |
|---|---|---|
| 因子数 | 5/7 | **7/7** |
| Session+Fib (57183) | ❌ 缺 | ✅ 实现 |
| Divergence (57186) | ❌ 缺 | ✅ 实现 + daily_stop |
| EX5 体积 | 56,260 | **67,042** (+19%) |
| 总 Risk | 3.5% | **4.5%** (full G+1.1) |
| daily_stop 机制 | 无 | ✅ 仅 Divergence 启用 |

## v2 新增因子

### 因子 6: Session+Fib (Magic 57183) Risk 0.5%

```
跟踪 UTC session (07-21h) day high/low
当 day range >= 1.5 ATR 时, 计算 fib 0.5/0.618 区间
价格回踩 fib zone + pin bar 拒绝时 entry
每日仅交易 1 次 (g_sess_traded_today)

Long: 价格 low 落在 (day_low + 0.5*range, day_low + 0.618*range)
      + lower wick > 1.5 × body + lower wick > 1.0 USD
      + 阳线收盘
Short: 镜像逻辑

SL = 4 ATR, TP = 1 ATR, time stop = 36 H1
```

### 因子 7: Divergence + daily_stop (Magic 57186) Risk 0.5%

```
RSI(14) vs price swing 背离 (H1)
Bullish: 价格 LL + RSI HL + RSI prev < 40
Bearish: 价格 HH + RSI LH + RSI prev > 60

daily_stop:
  扫历史 deals (今日 UTC)
  累计 PnL of MAGIC_DIV < -1.5% balance → 该因子停剩余时段
  跨日 reset (g_div_day_paused = false)
  
SL = 4 ATR, TP = 1 ATR, time stop = 48 H1
```

## 关键功能 (沿用 v1)

### Portfolio Circuit Breaker
```
单日 MDD > 5%   → 全因子暂停 12h
单周 MDD > 10%  → 全因子暂停 72h
基准: session_start_balance
```

### Vol Targeting (可选, 默认关)
```
UseVolTarget=true 启用
g_cur_vol_scale = clip(median ATR pct / current ATR pct, 0.5, 1.5)
所有因子 lot 自动 × vol_scale
```

### ToD Filter (mean rev only)
```
UseToDFilter=true (默认)
排除 20-22 UTC 仅对 VP_POC
PureBO/Liq/Gap/XAU-XAG/Sess/Div 不受影响
```

### 各因子独立 ON/OFF
```
PureBO_Enable, VP_Enable, Liq_Enable, Gap_Enable,
Ratio_Enable, Sess_Enable, Div_Enable
```

## 输入参数全表 (默认值)

```
=== 全局风控 ===
UseCompound = true
UseMartingale = false
MaxLotCap = 5.0
UseDailyMDDStop = true
DailyMDDStopPct = 5.0 / DailyStopHours = 12
WeeklyMDDStopPct = 10.0 / WeeklyStopHours = 72

=== Vol Targeting ===
UseVolTarget = false (默认关)
VolTargetLookback = 720
VolTargetCapLow = 0.5 / VolTargetCapHigh = 1.5

=== 因子 1: PureBO (57181) Enable=true Risk=1.0% ===
PureBO_SLAtr=4.0 PureBO_TPAtr=1.0 PureBO_TimeStop=72

=== 因子 2: VP_POC (57182) Enable=true Risk=1.0% ToD=yes ===
VP_POCLookback=100 VP_PriceBins=50
VP_LVNThreshold=0.3 VP_PinWickRatio=1.5 VP_PinMinWickUSD=1.5
VP_SLAtr=4.0 VP_TPAtr=1.0 VP_TimeStop=36

=== 因子 3: Liquidation (57184) Enable=true Risk=0.75% ===
Liq_VolSpikeMult=1.5 Liq_BodyAtrMult=1.0 Liq_RangeLookback=10
Liq_SLAtr=4.0 Liq_TPAtr=1.0 Liq_TimeStop=36

=== 因子 4: Gap_Reject (57185) Enable=true Risk=0.25% ===
Gap_MinAtrMult=0.5 Gap_FillTimeout=20 Gap_RejectTimeout=5
Gap_RejectShadow=2.0 Gap_RejectMinAtr=0.4
Gap_SLAtr=2.0 Gap_TPAtr=4.0 (无 trail/无 time stop)

=== 因子 5: XAU/XAG (57187) Enable=true Risk=0.5% ===
Ratio_XAGSymbol="XAGUSD"
Ratio_Lookback=240 Ratio_ZThreshold=2.0
Ratio_SLAtr=4.0 Ratio_TPAtr=1.0 Ratio_TimeStop=72

=== 因子 6: Session+Fib (57183) Enable=true Risk=0.5% ===  v2 新增
Sess_StartHourUTC=7 Sess_EndHourUTC=21
Sess_MinRangeAtr=1.5
Sess_FibLow=0.5 Sess_FibHigh=0.618
Sess_PinWickRatio=1.5 Sess_PinMinWickUSD=1.0
Sess_SLAtr=4.0 Sess_TPAtr=1.0 Sess_TimeStop=36

=== 因子 7: Divergence (57186) Enable=true Risk=0.5% ===  v2 新增
Div_RsiPeriod=14
Div_SwingLeft=3 Div_SwingRight=3
Div_LookbackBars=60
Div_DailyStopPct=1.5  ← 关键 daily_stop 阈值
Div_SLAtr=4.0 Div_TPAtr=1.0 Div_TimeStop=48

=== ToD Filter ===
UseToDFilter=true
ToD_StartHourUTC=20 ToD_EndHourUTC=22

=== 共享 ===
AtrPeriod=14 SignalFFillBars=12
UseTrailing=true TrailFixedUSD=0.5 TrailActivateAtr=0.5

=== EA 控制 ===
MasterMagic=57180 MaxSlippagePts=30
```

## 编译状态

```
✅ Portfolio_G11_Master.ex5  67,042 bytes  v2.00
   D:\EBC-mt5\MQL5\Experts\Portfolio_G11_Master.ex5
   归档: /Users/joker/factor_factory_archive/v20260509_g11_ic_raw_eas/code/

编译记录:
  Result: 0 errors, 0 warnings, 451 ms elapsed
  生成时间: 2026-05-10 12:48:10 (KK)
```

## 部署

```
☐ 1. RDP 到 KK
☐ 2. 启动 IC RAW MT5 instance
☐ 3. 复制 Portfolio_G11_Master.ex5 到 IC RAW MQL5/Experts/
☐ 4. 重启 MT5
☐ 5. 拖 Portfolio_G11_Master 到 XAUUSD H1 chart
☐ 6. 调整 Inputs:
    - 确认 Ratio_XAGSymbol 在 IC RAW 上的 symbol 名 (常见 XAGUSD/XAG/SILVER)
    - 验证 Div / Sess 风险匹配预期
☐ 7. 启用 AutoTrading

7 因子同时跑, 共享 ATR / 状态 / 熔断
```

## 验证 sub-magic 跟踪

```
EA 运行后, 在 Trade 面板观察:
  - 每笔 trade 的 Magic 应该是 sub-magic (57181-57187)
  - Master magic 57180 不会出现在 trade 中
  - Comment 显示: PureBO/VP_POC/Liquidation/Gap_Reject/XAUXAG/Sess_Fib/Divergence

attribution 工具 (后做):
  Python 脚本统计每 sub-magic 的 PnL/WR/PF
  Divergence 还要看 daily_stop 触发频次
```

## 已知风险 / Phase 4 优化

```
1. ⚠️ Session+Fib 这是 H1 简化版 (原设想 M5 入场), 实际效果待5y回测
2. ⚠️ Divergence standard backtest PF 0.83, 此版加 daily_stop 期望 PF > 1.0
3. ⚠️ 各因子无 cross-factor 共振过滤 (e.g. PureBO long + VP short → 都不开)
4. ⚠️ Vol Targeting 是简化 lot scaling, 不是 risk parity
5. ⚠️ Walk-forward audit 待做
```

## 总结

```
✅ 1 EA = 7 因子完整集成 (v2.0)
✅ 0 errors / 0 warnings 编译
✅ 67,042 bytes ex5
✅ Sub-magic 兼容独立 EA 部署 (可一键切换)
✅ Portfolio 熔断 + Divergence daily_stop 双层风控
✅ ToD filter / Vol Target 全局统一

vs 之前 5/7 ScalperPro 名 = 7/7 完整 + 规范命名
```
