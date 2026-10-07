---
project: 因子工厂 - MACD+SSL 盈利回测库
date: 2026-05-08
maintained_by: VV
tags: [factor, xau, macd, ssl_sweep, profit_archive, INDEX]
---

# MACD+SSL 盈利回测库 — 总索引

> 所有 5y XAUUSD 回测结果中**确认盈利**的方案存档。每篇报告都对应可复现的 trades csv（KK + mac archive）

## 推荐档（按账户增长能力 + MDD 平衡）

| 排名 | 方案 | broker | 频率/日 | MDD% | 1万→ | CAGR | 文档 |
|---:|---|---|---:|---:|---:|---:|---|
| 1 ⭐ | **no smallest cmin=2 soft** | EBC 35pt | 9.71 | 14.1% | $32.8M | 357% | [[01_EBC35_4TF_cmin2_soft]] |
| 2 | only H4+H1 cmin=2 soft | EBC 35pt | 3.35 | 10.3% | $17.6M | 307% | [[02_EBC35_H4H1_cmin2_soft]] |
| 3 | 3 TF cmin=2 soft | EBC 35pt | 3.40 | 8.0% | $17.8M | 308% | [[03_EBC35_3TF_cmin2_soft]] |
| 4 | no smallest cmin=3 flat | EBC 35pt | 2.66 | 7.4% | $13.7M | 288% | [[04_EBC35_3TF_cmin3_flat]] |
| 5 | 4 TF cmin=3 flat | EBC 35pt | 3.59 | 10.0% | $13.4M | 286% | [[05_EBC35_4TF_cmin3_flat]] |
| **10** ⭐⭐ | **IC 4 TF cmin=2 soft 复利** | **IC 10pt** | **18.61** | **19.3%** | **$84.0M** | **445%** | [[10_IC10_4TF_cmin2_soft_compound]] |
| 11 | EBC 4 TF cmin=2 soft fixed lot | EBC 35pt | 17.57 | 7.8% | $139K | 64% | [[00_EBC35_fixed_lot_全方案]] |
| 20 | **MACD 4TF + Gap v3 组合 IC 复利** | IC 10pt | 18.61 | 19.3% | **$84.63M** | 446% | [[20_组合_MACD_Gap_v3]] |
| 20 | **MACD 4TF + Gap v3 组合 EBC 复利** | EBC 35pt | 9.71 | 14.1% | **$33.52M** | 359% | [[20_组合_MACD_Gap_v3]] |
| TBD | spread=20 4 TF compound | EBC w/filter | 跑中 | - | - | - | (待跑完) |

## 配置维度速查

| 维度 | 选项 | 说明 |
|---|---|---|
| broker spread | 10 / 20 / 35pt | 实战成本，越小越宽松 |
| RR | 0.5 / 1.0 / 2.0 | 1.0 是 ⭐ Obsidian 因子库登顶配置 |
| sl_spread_mul | 0 / 2 / 3 / 4 | M30/M15 在大 spread 下需要 ≥3 |
| TF 子集 | ALL 4 / no smallest 3 / only H4+H1 / etc | "no smallest" = 排除 M15 但仍参与 confluence 投票 |
| confluence min | 1 / 2 / 3 | EBC 35pt 必须 ≥2 |
| bonus | flat / soft / linear / aggr | soft 是中庸推荐 |
| SB hour filter | 开 / 关 | 一般不用（拖累 Sharpe） |
| 风控模式 | fixed lot / 1% compound | compound 是真实复利 |

## bonus 曲线对照

```
配置             conf=1  conf=2  conf=3  conf=4  含义
flat              1.0    1.0    1.0    1.0   所有 conf 用基础 lot
soft (cmin=2)     -      1.0    1.2    1.5   ⭐ 温和加权
soft (cmin=1)     1.0    1.2    1.3    1.5   保留单 TF + 共振温和加
linear            1.0    1.5    2.0    2.5   激进加权
aggr              1.0    2.0    3.0    4.0   最激进（容易爆仓）
```

## confluence 定义

> 在 60 分钟窗口内，同方向有多少个不同 TF 同时给信号

- conf=1: 只有该 TF 单独看到机会（孤立信号）
- conf=2: 该 TF + 1 个其他 TF 同向（双 TF 共振）
- conf=3: 3 个 TF 同向
- conf=4: 4 TF 全同向（最强）

## 数学硬约束

```
RR=1 break-even WR (含 spread):
  WR = (1 + 2 × spread / SL_pts) / 2

  SL=200pt (H1天然), spread=35: break_WR=59% (实测 58% 勉强)
  SL=70pt  (M30 + dyn), spread=35: break_WR=75% (实测 56% 不通过)
  SL=105pt (M30 + sl_mul=3), spread=35: break_WR=67% (实测 56% 不通过单跑，但 conf=2 共振拉到通过)
  SL=20pt (M1 天然), spread=35: break_WR=88% 不可达 ❌
```

→ EBC 35pt 下 confluence ≥2 是数学必需（单 TF PF<1）

## 归档位置

- mac: `/Users/joker/factor_factory_archive/v2026-05-08_*`
- KK: `D:\factor_factory_archive\v2026-05-08_*` (待同步)

## 相关文档

- [[因子_MACD_SSL_4TF复利_EBC_2026-05-08]] — 主报告
- [[因子_MACD_SSL_TF矩阵_2026-05-07]] — Obsidian 0pt 基准矩阵
- [[因子_MACD底背离SSL扫荡_2026-05-07]] — 单因子原始报告
- [[因子_MACD双向SSL_RR_IC全报告_2026-05-07]] — RR scan + IC 检验

---

*v0.1 · 2026-05-08 · 索引创建*
