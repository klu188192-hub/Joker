# VWAP-FVG Confluence 验证模块 — 暂存到 EA Backlog

**生成日期**: 2026-05-08
**状态**: 因子工厂端验证为独立无 alpha；归档作 Scalper20_Pro EA 升级 backlog

---

## 用户规格（原文）

**核心定义：**
- Virgin VWAP: 当前 session 内未被价格穿越的 VWAP 轨迹
- FVG Zone: M15 失衡区 [Gap_Low, Gap_High]（3 根 K 形态）

**判定逻辑：**
- VWAP_Price ∈ [FVG_Low - 0.2×ATR, FVG_High + 0.2×ATR] → "价值共振"

**执行逻辑：**
- 主策略发 Retest FVG 入场信号时验证
- 共振 → Quality_Score +2
- Virgin VWAP 处 → A+ 级，跳过 M1 二次确认

**失效条件：**
- FVG 完全回补
- 收盘穿透 VWAP ≥2 根 K

**变量：Session-Based VWAP（UTC 日内重置）**

---

## 因子工厂端验证（v1/v2 双双失败）

| 版本 | n | WR | PF | MDD | net_pnl |
|---|---|---|---|---|---|
| v1 (无过滤) | 7,591 | 28.9% | 0.75 | 431% | -$34,484 |
| v2 (+Virgin+H1 trend+失效) | 4,720 | 30.1% | 0.79 | 240% | -$18,896 |

**结论：FVG retest + VWAP 共振作为独立 build_signal 入场触发器在 XAU M15 上是负 alpha**，跟之前所有 "retail TF 教科书形态" 翻车一致：
- EMA5 Pullback Scalp (PF 0.88)
- Open 5min Reversal (PF 0.37)
- RSI 极端反转 (PF 0.73)

**FVG retest 是 retail 共识入场点 → 流动性提供方 → 收割对象。**

---

## 因子工厂局限 vs 用户规格不匹配

用户规格本质是 **EA 内部 Quality_Score 加成模块**：

| 用户规格要求 | 因子工厂能力 |
|---|---|
| Quality_Score +2 | ❌ 只输出 -1/0/+1 |
| 跳过 M1 二次确认 | ❌ 不控制 EA 执行流 |
| 验证主策略 entry | ❌ 只能独立 build_signal |
| 高权重 confluence | ⚠️ 可模拟但样本小 |

**因子工厂不适合实现这个模块**，必须在 Scalper20_Pro EA 内部 MQL5 实现。

---

## EA 升级 Backlog（未来执行）

**前置条件**: 用户决定重启 EA 工作流（P3 锁定后暂停）

**实现路径：**

### 1. ComputeQualityScore() 扩展
在 v3 Phase 3 已有的 6 维度基础上加入 7 维度 (VWAP-FVG):
```mql5
// 现有 6 维度
int ComputeQualityScore(int sig_dir) {
    int score = 0;
    // 1. Volume ratio (0-3)
    // 2. FVG size / ATR (0-2)
    // 3. H1 EMA200 alignment (0-2)
    // 4. struct_dir same (0-1)
    // 5. Space ≥ 1.5×ATR(M15) (0-1)
    // 6. Overlap < 0.40 (0-1)
    
    // 新增 7. VWAP-FVG Confluence (0-2)
    if (IsVWAPInFVG()) score += 2;
    
    // 新增 8. A+ 级别 (Virgin VWAP, optional override)
    if (IsVirginVWAPAtFVG()) {
        score += 2;  // 累加而不是替换
        skipM1Confirm = true;  // 触发 EA 流程跳过 M1 验证
    }
    return score;
}
```

### 2. Session VWAP 计算
```mql5
double GetSessionVWAP(int shift) {
    datetime sessionStart = iTime(_Symbol, PERIOD_D1, 0);
    double cumTPV = 0, cumV = 0;
    for (int i = shift; iTime(_Symbol, PERIOD_M15, i) >= sessionStart; i++) {
        double tp = (iHigh(_Symbol, PERIOD_M15, i) + iLow(_Symbol, PERIOD_M15, i) + iClose(_Symbol, PERIOD_M15, i)) / 3.0;
        double v = iVolume(_Symbol, PERIOD_M15, i);
        cumTPV += tp * v;
        cumV += v;
    }
    return cumV > 0 ? cumTPV / cumV : 0;
}
```

### 3. Virgin VWAP 检测
```mql5
bool IsVirginVWAP(int lookback = 6) {
    double currentVWAP = GetSessionVWAP(0);
    bool aboveAll = true, belowAll = true;
    for (int i = 1; i <= lookback; i++) {
        double c = iClose(_Symbol, PERIOD_M15, i);
        if (c <= currentVWAP) aboveAll = false;
        if (c >= currentVWAP) belowAll = false;
    }
    return aboveAll || belowAll;
}
```

### 4. FVG 检测（已在 v3 Phase 2 实现）
```mql5
// 已存在 - 见 Scalper20_Pro v3 Phase 2 代码
bool DetectFVG(int direction, double &fvgLow, double &fvgHigh) {
    // K1.high < K3.low (bull) or K1.low > K3.high (bear)
}
```

### 5. 集成到 IsSignalAllowed() / Quality_Score 流程
- v3 P3 当前 IsSignalAllowed() 仅检查 mkt_state
- 加入 IsValueConfluence() 子检查
- A+ 级别 (Virgin VWAP) 触发 SkipM1Confirm 标志

### 6. MetaTrader Strategy Tester 验证
- 用 EBC-2-Tester 实例
- 配置 tester_v300_p3_vwap.ini
- 时间窗口: 2026-04-01 ~ 2026-05-04 (跟之前 P1-P3 一致)
- 对比基线: P3 (-2.41 USD net) vs P3+VWAP-FVG

**预期效果**:
- P3 已 PF ≈ 1.0 (gross)，VWAP-FVG 加成可能让 PF 升至 1.2-1.5（Quality_Score 配合 InpQualityScoreMin 阈值过滤）
- A+ 级别加大仓位（lot×1.5-2）放大 Sharpe

---

## 触发时机建议

EA 升级建议**等以下任一条件满足**：
1. **当前组合架构（MACD+Gap v3+POC+SB）实盘灰度跑 4-8 周**，确认稳定后再加新模块
2. **Scalper20_Pro v3 P3 实盘观察 4 周**，看 -2.41% 是否在实盘复刻或更糟（可能需要 VWAP-FVG 优化）
3. **重启 EA 工作流的明确指令**

不建议 P3 锁定后立即追加模块，原因：
- 验证的策略堆叠会让单一改进效果难定位
- v3 EA 状态机已复杂（MKT_TREND_LONG/SHORT/IMPULSE/CORRECTIVE/RANGE/TRANSITION 6 状态 + Quality_Score 6 维度）
- 加 VWAP-FVG 维度需要重新跑 4-6 sub-phase 验证

---

## 文件位置

- **代码 v1**: `/tmp/vwap_fvg_confluence_m15.py`
- **代码 v2**: `/tmp/vwap_fvg_v2.py`
- **因子库 v1**: `factor_library/VWAP-FVG_Confluence_M15.json` (KK, Tier D)
- **因子库 v2**: `factor_library/VWAP-FVG_Confluence_M15_v2.json` (KK, Tier D)
- **EA 集成代码**: 待 Scalper20_Pro v3 重启时编写
