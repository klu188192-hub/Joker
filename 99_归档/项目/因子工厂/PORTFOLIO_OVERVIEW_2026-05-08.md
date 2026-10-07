# 因子工厂组合架构总览

**生成日期**: 2026-05-08
**经历**: 42 版扫荡（2026-05-04 ~ 2026-05-08）
**部署目标**: EBC-3 实盘账户

---

## 终极配置（MACD + Gap Reject v3 并行）

```
EBC-3 主账户 ($10,000)
│
├── MACD_div_SSL (主力)
│   - 配置: H1+M15 long_short, lot 0.10
│   - SB confluence 加权 (1.5/0.5): Sharpe 提升至 3.78
│
├── Gap Reject v3 (A 方案 RR 1:2 极致版)
│   - 配置: sl 2.0 / tp 4.0 ATR, lot 2.5, 全账户
│   - MDD 控制 20.30%
│   - 2 笔/年 极低频精射手
│
└── 辅助角色
    - POC Magnet (独立子仓 Sharpe 1.14)
    - Silent Breakout (人工警报, 不开仓)
```

---

## 单独 vs 组合 关键数据 (5y XAU H1 backtest)

| 指标 | MACD only | Gap v3 only | **MACD + Gap v3 并行** |
|---|---|---|---|
| **5y 总盈利** | $62,463 | $31,183 | **$93,646** ⬆ +50% |
| **CAGR** | 44.14% | 29.86% | **53.99%** ⬆ +10pp |
| **MDD%** | 3.46% | 9.62% | **2.97%** ⬇ 反而降低 |
| 月均 PnL | $961 | $480 | $1,441 |
| 月度 std | $1,157 | $2,526 | $2,971 |
| Sharpe (年化) | 2.88 | 0.66 | 1.68 (Gap 巨盈月膨胀 std 假象) |
| 月度 corr | — | 0.190 | (低相关) |

**结论：组合数学全胜（总收益 +50%, MDD% 改善, CAGR +10pp），Sharpe 下降是 std 被上行波动膨胀的伪信号。**

---

## 部署候选因子库（4 个真 alpha）

| 因子 | Tier | PF | Sharpe | MDD | corr vs MACD | 实战定位 |
|---|---|---|---|---|---|---|
| **MACD_div_SSL_H1_M5** | A | 2.09 | 2.74 | 3% | 1.00 (本身) | 主力 alpha |
| **POC Magnet** | C | 1.36 | 1.14 | 17% | 0.58 | 独立子仓 |
| **Structure Breakout** | C | 1.06 | 0.32 | 33% | 0.08 | confluence 加权器 |
| **Gap Reject v3** | **B** | **8.57** | 1.18 | **20%** | 0.19 | **稀有精射手 全账户** |
| Silent Breakout | D | 1.03 | N/A | 9% | N/A | 事件警报 |

---

## 暂存归档（3 个翻车）

| 因子 | 原因 |
|---|---|
| Order Book Imbalance | 需要 L2 历史数据（不存在）|
| EMA5 Pullback Scalp | retail TF 教科书回踩 = noise |
| Open 5min Reversal | retail TF 教科书反转 = noise |

---

## 42 版扫荡的核心方法论沉淀

### 1. 真 alpha 的共同特征
- **多阶段结构性事件链**（≥3 阶段状态机）
- **隐含 trend filter**（reject + 同向 close 突破）
- **不是教科书形态**（教科书 = retail 共识 = 收割对象）

### 2. 失败因子的共同特征
- **单一阶段触发**（如"开盘大实体反转"）
- **retail TF 教科书形态**（趋势回踩、极端反转、突破延续）
- **持仓时间过短**（30 分钟 / 1-2 根 K 不够 alpha 释放）

### 3. corr 拖累定律
```
Sharpe(新) ≥ corr × Sharpe(主)
↓
- corr 0.0 → 任何正 alpha 都能提升组合
- corr 0.3 → 新因子 Sharpe 至少 0.82
- corr 0.5 → 新因子 Sharpe 至少 1.37
```

### 4. 调参资格 4 条
- 核心 alpha 已被验证 (PF > 1.5 + MDD < 10% + p < 0.01)
- 不破坏核心机制（调阈值不调结构）
- trade-off 合理（牺牲 1 项换另 1 项）
- 调参后增加可用性（confluence/corr/组合）

### 5. 5 大风控铁律（实战必加）
1. 连亏 2 → 减半仓位
2. 连亏 3 → 暂停 30 天 + 复盘
3. 单月最大累计 lot 上限
4. 账户 MDD -25% 熔断
5. 杠杆使用警告（Gap v3 lot 2.5 = 50% margin）

---

## 实战部署 Checklist

- [ ] EA 端实现 Gap Reject 状态机（或 Python monitor + 手动开仓）
- [ ] EA 端实现 SB confluence 检测（amplify/dampen MACD 仓位）
- [ ] 风控规则编码：连亏减仓 / MDD 熔断 / 单月 lot 上限
- [ ] Phase 1 模拟跟踪 4-8 周（不开仓只记录）
- [ ] Phase 2 灰度实盘（lot 减半起步）
- [ ] Phase 3 全仓部署（按文档配置）

---

## 详细文档索引

| 文档 | 内容 |
|---|---|
| MACD_SB_CONFLUENCE_v1.md | MACD + SB confluence 完整方案 |
| POC_MAGNET_v1.md | POC 磁吸独立子仓方案 |
| GAP_REJECT_v3.md | Gap Reject 极致版（A 方案 RR 1:2 / lot 2.5） |
| GAP_REJECT_v1.md | Gap Reject 探索版（参考） |
| GAP_REJECT_v2.md | Gap Reject 中频可加权版（参考） |
| SILENT_BREAKOUT_v1.md | Silent Breakout 事件警报 |
| SHELVED_*.md | 暂存翻车归档（学习参考）|

---

## 同步状态

- mac: `/Users/joker/factor_factory/docs/`
- KK: `C:/Tools/factor_factory/docs/`
- **Obsidian: 本文档为入口，详细 docs 在同目录**
