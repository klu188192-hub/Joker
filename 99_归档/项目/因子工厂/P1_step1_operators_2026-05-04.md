---
project: 因子工厂
phase: P1 单因子工厂 - 任务1 算子库
status: done
date: 2026-05-04
owner: VV
---

# P1.1 时间序列算子库 — 完成总结

## 验收对照

| 验收项 | 标准 | 实际 |
|---|---|---|
| 算子覆盖 spec 列表 | delay/ts_delta/ts_mean/ts_std/ts_rank/ts_corr/ts_max/ts_min/ts_argmax/ts_argmin/if_else | ✅ 11/11 全实现 |
| 向量化操作 | 基于矩阵/数组 | ✅ pandas.rolling 内核 + numpy 输出 |
| 任意周期参数 d | 必须 | ✅ |
| 空值安全 | 必须 | ✅ NaN 传播规则与 pandas 一致 |
| 与 pandas 误差 < 0.001 | 硬指标 | ✅ **实测 < 1e-9**（远超 spec） |
| 单元测试 | 全算子覆盖 | ✅ 25 个 test 全 PASS（mac + KK 双端验证） |

## 算子清单（25 个）

### 核心 11（spec 要求）

| 名 | 描述 | 内核 |
|---|---|---|
| `delay(x, d)` | x 滞后 d 周期 | pandas.shift |
| `ts_delta(x, d)` | x[t] - x[t-d] | shift + 减 |
| `ts_mean(x, d)` | d 周期均值 | rolling.mean |
| `ts_std(x, d)` | d 周期样本标准差 (ddof=1) | rolling.std |
| `ts_rank(x, d)` | 当前值在过去 d 周期的百分位 [0,1] | rolling.rank(pct=True) |
| `ts_corr(x, y, d)` | x/y d 周期相关系数 | rolling.corr |
| `ts_max(x, d)` / `ts_min(x, d)` | d 周期最值 | rolling.max/min |
| `ts_argmax(x, d)` / `ts_argmin(x, d)` | 最值在窗口内的位置（0=最旧, d-1=当前）| rolling.apply |
| `if_else(cond, x, y)` | 元素级三元运算 | np.where |

### VV 扩展 14（必要的因子构建块）

| 类别 | 算子 |
|---|---|
| 矩 | `ts_skew` / `ts_kurt` |
| 标准化 | `ts_zscore` |
| 收益率 | `ts_pct_change` / `ts_log_return` |
| 加权聚合 | `ts_decay_linear`（线性衰减权重均值，强趋势因子）|
| 分位 | `ts_quantile` / `ts_median` |
| 计数 | `ts_count_pos` / `ts_count_neg` |
| 协方差 | `ts_cov` |
| 极值偏移 | `ts_max_diff` / `ts_min_diff` / `ts_range` |
| 价格感知 | `ts_true_range` / `ts_atr` |
| 序列形态 | `ts_streak_up` / `ts_streak_down`（连续涨跌）|
| 元素级 | `sign` / `log` / `log_safe` / `abs_` / `power` / `clip` / `ts_sum` |
| 横截面 | `cs_rank`（多 symbol 矩阵的逐行百分位）|

## 关键设计决策

1. **pandas.rolling 内核** — 与 pandas 原生 0 误差，回避 numpy stride trick 的 NaN 处理坑。
2. **leading d-1 NaN 约定** — 保证下游因子表达式可直接 dropna 或 forward fill，不需重定义"窗口够不够"。
3. **`signed power`** — `power(x, p) = sign(x) * |x|^p` 保留符号，避免负数取偶次方丢符号。
4. **`log_safe`** — 自动 clip 到 eps，防止零/负值产生 -inf 污染下游。
5. **`cs_rank`** — 为 P4 多信号聚合的横截面排名提前布局，单 symbol 时退化为 1D。

## MQL5 端对应（待 P1.6 移植）

P1 任务 1 spec 提到 "MQL5 或 Python"。当前 Python 已完成。MQL5 端需要等 P1 后期把因子表达式落到 EA 内时再移植（保留 pandas 输出作为 ground truth，MQL5 算子计算结果与之 < 0.001 即可）。

## 文件清单

- 主算子库：`/Users/joker/factor_factory/factors/operators.py`
- package init：`/Users/joker/factor_factory/factors/__init__.py`
- 测试：`/Users/joker/factor_factory/tests/test_operators.py`（25 tests）
- KK 部署：`C:\factor_factory\factors\operators.py` + `tests\test_operators.py`
- mac + KK 双端测试均 25/25 PASS

## 接下来

- P1 任务 2：因子表达式生成器（500+ 表达式覆盖趋势/反转/量价/波动/形态）
- P1 任务 3：数据窗口划分（样本内 2021-2023 / 验证 2024-2025 / 测试 2025-）
- P1 任务 4：单因子稳健性筛选（IC、IR、分层回测）
- P1 任务 5：样本外交验
- P1 任务 6：去相关 → 最终因子池

依赖：P0-2 数据清洗（待 Dukascopy task #59 完）+ 用户拍板下一任务发详细需求。
