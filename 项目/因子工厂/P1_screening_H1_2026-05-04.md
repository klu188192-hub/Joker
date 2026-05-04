---
project: 因子工厂
phase: P1.3+P1.4 因子筛选
status: done
date: 2026-05-04
tf: H1
fwd_periods: 5
---

# P1.3+P1.4 因子稳健性筛选报告

**生成时间**: 2026-05-04 12:15 UTC
**数据**: XAUUSD.s H1
**前向周期**: 5 bars
**时间划分**: 训练(2021-2023) / 验证(2024-2025) / 测试(2026-)

## 筛选流程

1. 训练集 RankIC → IC均值/t值/IR/胜率
2. 过滤: |IR|>0.25 且 胜率>45% 且 多空年化差>8%
3. 验证集再评估: 同向 + IR衰减<30% + 验证IR>0.2
4. 相关性去重 (>0.7 保留高IR)
5. 检查最终池平均相关 <0.4

## 筛选统计

| 指标 | 数值 |
|---|---|
| 最终因子数 | **2** |
| 分类 | {'random': 1, 'reversion': 1} |
| 训练期 IR 均值 | 1.301 |
| 验证期 IR 均值 | 1.505 |
| 训练期胜率均值 | 83.33% |

## 因子明细

| 因子ID | 类别 | 训练IR | 验证IR | 胜率 | 多空年化 | IR衰减 | 备注 |
|---|---|---|---|---|---|---|---|
| rand_00089 | random | 1.993 | 2.403 | 97.22% | 51.77% | -20.60% | ok |
| r_neg_log_return_50 | reversion | 0.610 | 0.606 | 69.44% | 10.88% | 0.60% | ok |

## 分类分布

```
category
random       1
reversion    1
```


## 文件路径

- 因子池 CSV: `factor_factory/reports/factor_pool_H1_fwd5.csv`
- 因子矩阵: `factor_factory/data/factors_H1_v1.csv`
- 筛选模块: `factor_factory/factors/factor_screening.py`
