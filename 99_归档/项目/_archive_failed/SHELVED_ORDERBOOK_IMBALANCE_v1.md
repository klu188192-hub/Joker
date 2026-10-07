# 盘口失衡剥头皮因子 — 暂存

**生成日期**: 2026-05-08
**状态**: 暂存（数据 + 引擎能力不足）

---

## 因子规格（用户原始）

**TF**: tick / 1 分钟
**信号**: 订单簿 5 档买卖挂单量失衡

**做多条件：**
1. 失衡度 = bid_vol_5档 / (bid_vol_5档 + ask_vol_5档) > 0.7
2. 过去 5 秒最后 5 笔成交，4+ 笔是主动买入
3. 当前 spread < 0.3 点

**入场**: 市价
**SL/TP**: 固定 3 点（RR=1:1）
**时间止损**: 30 秒

**做空**: 镜像 (失衡度 < 0.3)

---

## 暂存原因

| 限制 | 详情 |
|---|---|
| **L2 数据缺失** | Dukascopy/MT5 broker 都不提供 5 档历史挂单量；tick_volume 不区分主动买卖方向；5y 历史 L2 数据全市场稀缺资源 |
| **时间分辨率** | factor_factory 引擎最细 M1 (60s)，无法切 30s 持仓；当前 ffill 机制是 H1×12=12h 量级 |
| **品种不适配** | 3 点 TP/SL = $0.03 在 XAU spread $0.20-0.50 上完全被 spread 吃光，规格设计场景是 EURUSD/股票主流品种 |

## 未来启动条件

满足任一即可重启：

1. **EBC MT5 L2 实时采集 ≥ 4 周累积**
   - KK 上 24/7 跑 Python monitor (`mt5.market_book_get`)
   - 累积 ~1 万样本后做 forward test
2. **BTCUSD Binance L2 历史下载**
   - 公开免费数据
   - 4-6 小时下载 + 处理
   - 但回测结果不能直接迁移 EBC broker
3. **factor_factory 引擎升级支持 tick-level event backtest**
   - 大工程量，需要重写 BacktestConfig + Engine

## 文件

- 因子规格: 此文档
- 无代码（未实现）
- 无回测数据
