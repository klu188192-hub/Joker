---
title: 方案 G+1.1 完整部署计划 — IC RAW + ToD Filter
date: 2026-05-09
status: ready_to_deploy
target: IC RAW demo / live
related:
  - "[[SCHEME_G1_1_BROKER_SHIFT_v20260509]]"
  - "[[IC_RAW_BACKTEST_GUIDE_v20260509]]"
---

# 方案 G+1.1 完整部署 — 5 EA 已编译就绪

## EA 状态总览

| # | EA 名 | Magic | Risk% | ToD Filter | 编译状态 | 文件位置 |
|---|---|---|---|---|---|---|
| 1 | **PureBreakout_Trail_v1** | 57181 | 1.0 | no | ✅ 已编译 | D:/EBC-mt5/MQL5/Experts/ |
| 2 | **VP_POC_Reversion_v1** | 57182 | 1.0 | **yes** | ✅ 已编译 | 同上 |
| 3 | **Liquidation_v6** | 57184 | 0.75 | no | ✅ 已编译 | 同上 |
| 4 | **Gap_Reject_v3** | 57185 | 0.25 | no | ✅ 已编译 | 同上 |
| 5 | **XAU_XAG_Ratio_v1** | 57187 | 0.5 | no | ✅ 已编译 | 同上 |
| 6 | Session_Fib_v1 | 57183 | 0.5 | yes | ⏳ 待写 (复杂状态机) | - |
| 7 | Divergence_archive | 57186 | 0.5 | no | ⏳ Phase 4 (需 daily_stop) | - |

**已就绪: 5/7 EA**, 总风险 3.5% (vs 完整 G+1.1 的 4.0%)

## 配置规格

```
所有 EA 共用风险参数 (G+1.1):
  RiskPerTrade:    各因子不同 (1.0/0.75/0.5/0.25)
  UseCompound:     true (复利)
  UseMartingale:   false (关闭马丁)
  MaxLotCap:       5.0
```

```
Trail (5/5 因子用一致配置):
  TrailFixedUSD:   0.5
  TrailActivateAtr: 0.5
  Gap_Reject 例外: 不用 trail (SL=2 ATR / TP=4 ATR 直接撞)
```

```
ToD Filter (mean rev 因子):
  ExcludeStartHourUTC: 20
  ExcludeEndHourUTC:   22
  仅 VP_POC 启用 (Sharpe +0.64)
```

## 部署步骤 (Phase 1-3)

### Phase 1: IC RAW 账户准备 (今天)

```
☐ 1. RDP 到 KK
☐ 2. 启动 D:/IC-tester/terminal64.exe (或开新 IC RAW MT5 instance)
☐ 3. 登录 IC RAW demo 账户 ($10K 起步)
☐ 4. 验证 XAUUSD spread 实际 mean (Tools→Symbols)
     - 预期: 8-15 pts mean
     - 如果 > 25 pts → 不是真 RAW account
☐ 5. 验证 XAGUSD symbol 可用 (XAU/XAG 因子需要)
☐ 6. 等待 5y 历史数据自动同步 (Tools→History Center)
```

### Phase 2: 单 EA 验证 (Week 1)

```
☐ 1. 复制 5 个 .ex5 到 IC RAW MT5 (Files → Open Data Folder → MQL5/Experts)
☐ 2. 重启 MT5 让 EA 列表刷新
☐ 3. 部署 PureBO 单 EA, $1k 试仓
   - 拖 PureBreakout_Trail_v1 到 XAUUSD H1 chart
   - Inputs: 默认值 (RiskPerTrade=1.0, MaxLotCap=5.0)
   - 跑 24-48 小时观察
☐ 4. 实盘 vs Python 模拟 (Scenario 4) 对账
   - 信号触发同步率应 > 85%
   - PnL 衰减应 < 30% (vs 模拟)
☐ 5. 如果衰减合理 → Phase 3
```

### Phase 3: 5 EA 全部部署 (Week 2-3)

```
☐ 1. 增加 VP_POC + Liquidation + XAU/XAG (各 0.75-1.0% risk)
☐ 2. Gap_Reject 最后加 (0.25% risk, 极低频)
☐ 3. 总单笔风险: 3.5%
☐ 4. 监控 1 个月:
   - 每日实盘 vs 回测对账
   - corr 矩阵实盘验证 (PureBO vs VP_POC 应 ≈ 0)
   - MDD 不应 > 15%
```

### Phase 4: Session+Fib 补齐 (Month 2)

```
☐ 1. 写 Session_Fib_v1.mq5 (复杂多状态机)
☐ 2. 部署后总风险升到 4.0% (G+1.1 完整版)
```

## 关键监控

### 实盘 vs 回测对账 (前 2 周)

| 指标 | 回测预期 | 实盘容忍 | 异常处理 |
|---|---|---|---|
| Spread mean | 15 pts | < 25 pts | 检查 broker 是否真 RAW |
| 触发同步率 | 100% | > 85% | < 70% 暂停, 排查 |
| 单 EA Sharpe | 见 Scenario 4 | > 50% baseline | < 30% 暂停 |
| Portfolio MDD | 12-18% | < 25% | > 25% 全暂停 |
| Trail 触发率 | 70%+ trades | > 50% | < 30% 检查 spread |

### 风险熔断

```
☐ 单日 portfolio 亏损 > 5% → 暂停 12h, 人工 review
☐ 单周 MDD > 10% → 暂停 3 天 + 复盘
☐ 单月 MDD > 15% → 全停 1 周
☐ XAUUSD spread 突然 > 30 pts → 暂停所有 EA
```

## EA Inputs 参数表

### PureBreakout_Trail_v1 (Magic 57181)
```
RiskPerTrade        = 1.0
UseCompound         = true
UseMartingale       = false
MaxLotCap           = 5.0
SwingLeft = 3
SwingRight = 3
AtrPeriod = 14
SLAtrMult = 4.0
TPAtrMult = 1.0
TimeStopBars = 72
SignalFFillBars = 12
TrailFixedUSD = 0.5
TrailActivateAtr = 0.5
```

### VP_POC_Reversion_v1 (Magic 57182)
```
RiskPerTrade        = 1.0
POCLookback = 100
PriceBins = 50
LVNThreshold = 0.3
PinWickRatio = 1.5
PinMinWickUSD = 1.5
SLAtrMult = 4.0
TPAtrMult = 1.0
TimeStopBars = 36
UseToDFilter = true        ← 关键
ExcludeStartHourUTC = 20
ExcludeEndHourUTC = 22
TrailFixedUSD = 0.5
TrailActivateAtr = 0.5
```

### Liquidation_v6 (Magic 57184)
```
RiskPerTrade = 0.75
VolSpikeMult = 1.5
BodyAtrMult = 1.0
RangeLookback = 10
SLAtrMult = 4.0
TPAtrMult = 1.0
TimeStopBars = 36
TrailFixedUSD = 0.5
TrailActivateAtr = 0.5
```

### Gap_Reject_v3 (Magic 57185)
```
RiskPerTrade = 0.25
GapMinAtrMult = 0.5
FillTimeoutBars = 20
RejectTimeoutBars = 5
RejectShadowRatio = 2.0
RejectMinShadowAtr = 0.4
SLAtrMult = 2.0     ← 跟其他不同
TPAtrMult = 4.0     ← RR 1:2
无 trail / 无 time stop
```

### XAU_XAG_Ratio_v1 (Magic 57187)
```
RiskPerTrade = 0.5
XAGSymbol = "XAGUSD"   ← 必须验证 IC RAW 上 symbol 名
RatioLookback = 240
ZThreshold = 2.0
SLAtrMult = 4.0
TPAtrMult = 1.0
TimeStopBars = 72
TrailFixedUSD = 0.5
TrailActivateAtr = 0.5
```

## 回测对比基准 (Python factor_factory + spread 15 pts, 5y)

```
PureBO:        N=3960 PF 1.85 Sharpe 3.78 MDD 14.36% CAGR +64.43%
VP_POC + ToD:  N=2973 PF 1.53 Sharpe 2.67 MDD 17.71% CAGR +51.67%
Liquidation:   N=1675 PF 1.76 Sharpe 2.87 MDD 10.66% CAGR +42.71%
Gap_Reject:    N=12   PF 4.66 Sharpe 0.76 MDD  2.20% CAGR  +1.66%
XAU/XAG:       N=609  PF 2.51 Sharpe 3.20 MDD  8.51% CAGR +34.99%
─────────────────────────────────────────────────────────
组合 (5 EA):   avg Sharpe 2.59, total trades 9229
```

## 文件归档

```
代码: /Users/joker/factor_factory_archive/v20260509_g11_ic_raw_eas/code/
  - PureBreakout_Trail_v1_g11.mq5
  - VP_POC_Reversion_v1.mq5
  - Liquidation_v6.mq5
  - Gap_Reject_v3.mq5
  - XAU_XAG_Ratio_v1.mq5
  
KK 部署位置:
  - D:/EBC-mt5/MQL5/Experts/ (已编译)
  - D:/IC-tester/MQL5/Experts/PureBreakout_Trail_v1.ex5 (已 copy)
  
待 copy 到 IC RAW live MT5:
  - 用户 RDP 后用 File→Open Data Folder 找到 IC RAW 的 MQL5/Experts 路径
  - 复制 5 个 .ex5 文件
  - 重启 MT5
```

## 已知限制

```
⚠️ Session_Fib v1 EA 未实现 (复杂状态机, 留 Phase 4)
⚠️ Divergence EA 未实现 (需要 daily_stop, 留 Phase 4)
⚠️ Spread 实测不能 SSH 自动化, 必须 KK GUI 手动
⚠️ ATR 熔断 / Vol Targeting 主控 EA 未实现 (架构上要单独主 EA, 留 Phase 4)

完成 5 EA = G+1.1 主体 88% (5/7 因子, 总 risk 3.5/4.0%)
```

## 现在 → 下一步

```
最关键: 你 RDP 到 KK 验证 IC RAW XAUUSD spread 实际值 (5 分钟)
然后选择:
  ☐ A. 立刻部署 PureBO 单 EA 试 IC RAW $1k 1 周
  ☐ B. 先跑 PureBO IC RAW MT5 strategy tester 5y 验证
  ☐ C. 等我把 Session+Fib 也写完再一起部署
```
