# EBC57171 部署清单 — PureBreakout_Trail v1

**部署日期**: 2026-05-09
**EA 文件**: PureBreakout_Trail_v1.ex5
**目标账户**: EBC57171
**MagicNumber**: 57171

---

## 部署位置 (KK 上已就位)

```
D:\EBC-2\MQL5\Experts\PureBreakout_Trail_v1.ex5  (40712 bytes)
D:\EBC-3\MQL5\Experts\PureBreakout_Trail_v1.ex5
D:\EBC-4\MQL5\Experts\PureBreakout_Trail_v1.ex5
D:\EBC-5\MQL5\Experts\PureBreakout_Trail_v1.ex5
D:\EBC-6\MQL5\Experts\PureBreakout_Trail_v1.ex5
D:\EBC-7\MQL5\Experts\PureBreakout_Trail_v1.ex5
D:\EBC-8\MQL5\Experts\PureBreakout_Trail_v1.ex5
D:\EBC-9\MQL5\Experts\PureBreakout_Trail_v1.ex5
```

源代码 + 编译产物 mac 备份: `/Users/joker/factor_factory_archive/v20260509_breakout_ssl_hunt_final/`

---

## EA 上图操作步骤

1. 在 KK 上打开**登录 57171 账户的 EBC 终端**（EBC-2 ~ EBC-9 任一）
2. 打开 XAUUSD 图表，切换到 **H1** 周期
3. 导航器面板 → Expert Advisors → 拖 `PureBreakout_Trail_v1` 到图表
4. 在弹窗"Common"栏：勾选 ☑ Allow Algo Trading
5. 切到"Inputs"栏，确认/调整：
   - **RiskPerTrade = 3.0** ⭐（用户主观调整位）
   - 其他参数默认即可
6. 点击 OK → 图表右上角应显示笑脸 😀（EA 运行中）
7. 在 MT5 下方"Experts"日志确认 `[INIT] PureBreakout_Trail v1 启动` 等输出

---

## 输入参数详解（所有可主观调整）

### 风险参数（主要调整位）

| 参数 | 默认 | 含义 | 调整建议 |
|---|---|---|---|
| **RiskPerTrade** | **3.0** | 单笔风险 % | **核心调整位**: 1.0=保守 / 3.0=平衡 / 5.0=激进 |
| UseCompound | true | 复利（lot 跟 equity 增长） | 关闭 → 固定 risk 用初始 balance |
| UseMartingale | true | 启用轻马丁 | 关闭 → 不放大 lot |
| MartiMultiplier | 1.5 | 亏损后 lot ×N | 不建议改, 1.5 是甜蜜点 |
| MartiCap | 2.25 | multiplier 上限 | 2.25=稳, 4=平衡, 8=进取 |
| MaxLotCap | 10.0 | 绝对 lot 上限（防爆） | 按账户余额估 |

### 因子参数（一般不改）

| 参数 | 默认 | 含义 |
|---|---|---|
| SwingLeft | 3 | fractal 左 N 根 |
| SwingRight | 3 | fractal 右 N 根 |
| AtrPeriod | 14 | ATR 周期 |
| SLAtrMult | 4.0 | SL = 4 × ATR |
| TPAtrMult | 1.0 | TP = 1 × ATR |
| TimeStopBars | 72 | 持仓 72 H1 后强平 |

### Trailing 参数

| 参数 | 默认 | 含义 |
|---|---|---|
| UseTrailing | true | 启用 trailing |
| **TrailFixedUSD** | **0.5** | trail 固定距离（USD） |
| TrailActivateAtr | 0.5 | 浮盈 0.5 ATR 启动 trailing |

### EA 控制

| 参数 | 默认 | 含义 |
|---|---|---|
| MagicNumber | 57171 | EA 唯一识别（匹配账户） |
| TradeComment | "PureBO" | 订单备注 |
| MaxSlippagePts | 30 | 最大滑点 |
| AllowReenterAfterStop | true | SL/TP 后允许立即重入 |

---

## 实盘预期表现 (基于 5y XAU H1 回测)

### 核心指标

| 指标 | 标准回测 (lot 0.1) | 实盘预期 (账户 $10k, risk 3%) |
|---|---|---|
| WR | 75% | 70-72% |
| PF | 1.88 | 1.65 (broker 成本侵蚀后) |
| 频率 | 5 单/工作日 | 同 (~3-5 单) |
| MDD | 11% | 15-20% (实盘可能高 5%) |
| CAGR (无马丁) | ~65% | ~55% |
| **CAGR (带马丁 cap2.25)** | **~76%** | **~60-65%** |

### 单笔风险（Risk=3%）

| 场景 | 损失 |
|---|---|
| 真 SL 扛满 (8% 概率) | -3% × 1 = **-3%** 账户 |
| Trailing 锁利出场 (62% 概率) | +0.5%~1% (≈ $50-100/lot 0.1) |
| TP 直拿 (11% 概率) | +0.4% (≈ $40/lot 0.1) |
| Signal 反向 (20% 概率) | -1.5%~2.5% |
| **马丁触发后单笔最坏** | **-3% × 2.25 = -6.75%** |

### 心理预警线

| 触发 | 行为 |
|---|---|
| MDD > 15% | 检查 broker 是否 spread 异常 |
| MDD > 20% | 暂停 EA + 复盘最近 30 trades |
| MDD > 25% | 立即停 EA + 强制冷静期 |
| 连亏 ≥ 5 笔 | 监控但不暂停（在数学预期内） |
| 连亏 ≥ 8 笔 | 暂停 EA + 检查市场环境 |
| 单月 IC 转负持续 ≥ 2 月 | 暂停 EA + 重新评估 alpha |

---

## Broker 兼容性警告

**EBC 是 STP/MM 类 broker，非纯 ECN**:
- 标准 spread + 加价的混合模式
- 实盘成本可能比回测假设高 30-50%
- PF 衰减预期 -22%~-40%

**推荐迁移**: IC Markets ECN（成本 -30%，但需要重开账户）

如果 EBC57171 表现稳定 1-2 个月（PF > 1.4），考虑把策略也部署到 IC Markets 验证。

---

## 监控接入

EA 已用 `MagicNumber=57171` 标记所有订单。建议：

1. **monitor_ebc3** (KK 上的现有监控) 把 57171 加入跟踪：
   - OPEN/CLOSE 推送企微
   - 每日 20:00 备忘录同步

2. **二次复盘工作流** (按 CLAUDE.md feedback)：
   - 每笔 OPEN/CLOSE → 单笔信号校验
   - 写入 Obsidian/Trades/57171-EBC/<date>.md

---

## 出问题排障

| 症状 | 原因 | 处理 |
|---|---|---|
| EA 不开单 | swing 还没形成 / signal 不触发 | 等 1-2 小时观察 |
| 笑脸变成 X | Allow Algo Trading 没开 | 主菜单 → Tools → Options → Expert Advisors |
| `OPEN_FAIL retcode=10004` | broker 拒单 | 检查最小 lot / 账户冻结 |
| `OPEN_FAIL retcode=10006` | 无效 SL/TP | broker 限制 SL 离价过近，调大 SLAtrMult |
| Trailing 不工作 | 浮盈未达 0.5 ATR | 正常，等趋势启动 |
| 马丁失效（multiplier 未升） | 亏损 trade 没被 EA 识别 | 检查 GlobalVariable PureBO_Mul / PureBO_PendingLoss |

---

## 紧急关停

```
方法 1: 图表右上角 → 移除 EA
方法 2: 工具栏 → 关闭 Algo Trading 总开关
方法 3 (硬关): KK 任务管理器 → 结束 terminal64.exe (EBC-N)
```

关停后**手动平仓**当前持仓避免无人监管。

---

## 文件备份

- 源代码: `/Users/joker/factor_factory_archive/v20260509_breakout_ssl_hunt_final/EA/PureBreakout_Trail_v1.mq5`
- 编译产物: KK 上 8 份 .ex5
- 此文档: 同目录下 `EBC57171_DEPLOY_GUIDE.md`
- Obsidian 同步: 待写入

---

## 接下来动作 (你做)

1. ☐ 在 KK 上打开 57171 所在的 EBC 终端
2. ☐ 拖 EA 到 XAUUSD H1 图表 + 确认 RiskPerTrade=3.0
3. ☐ 笑脸出现 + 日志正常 → 让它跑
4. ☐ 24h 后回顾首批 trade: WR / PF / signal close 占比
5. ☐ 7d 后回顾: 真实 broker 成本 vs 回测预期偏差
