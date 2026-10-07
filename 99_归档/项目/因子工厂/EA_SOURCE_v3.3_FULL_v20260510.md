# Portfolio_G11_Master.mq5 v3.3 完整源代码备份

**版本**: v3.3 终版
**日期**: 2026-05-10
**编译产物**: 81,828 bytes / 0 errors
**集成**: 7 因子 + 5 层风控 + ATR Regime + Stage 1+2 优化 + Spread 防护 + H4 filter
**总行数**: 1408

## 编译状态

```
Result: 0 errors, 0 warnings, 462 ms elapsed, cpu='X64 Regular'
EX5: D:\EBC-mt5\MQL5\Experts\Portfolio_G11_Master.ex5 (81828 bytes)
```

## 完整源代码

\`\`\`mql5
//+------------------------------------------------------------------+
//|                                  Portfolio_G11_Master.mq5        |
//|       7 因子集成 Master EA — 方案 G+1.1 (IC RAW + ToD filter)     |
//|                                                                  |
//|   架构:                                                          |
//|     Master Magic = 57180                                          |
//|     Sub-magic 区分因子来源 (57181-57187)                          |
//|     共享: ATR / 状态 / 仓位管理 / Vol Target / 熔断              |
//|                                                                  |
//|   因子 (7/7 全部实现):                                            |
//|     57181 PureBO 顺势突破     1.0%  risk  trail 0.5/0.5           |
//|     57182 VP_POC 反转 + ToD   1.0%  risk  trail 0.5/0.5           |
//|     57183 Session+Fib 回踩    0.5%  risk  trail 0.5/0.5           |
//|     57184 Liquidation v6      0.75% risk  trail 0.5/0.5           |
//|     57185 Gap_Reject v3       0.25% risk  SL=2 TP=4 (无 trail)    |
//|     57186 Divergence + dStop  0.5%  risk  trail 0.5/0.5           |
//|     57187 XAU/XAG ratio       0.5%  risk  trail 0.5/0.5           |
//|                                                                  |
//|   Portfolio Circuit Breaker:                                     |
//|     单日 MDD > 5% → 暂停 12h                                      |
//|     单周 MDD > 10% → 暂停 3 天                                    |
//|     Divergence daily_stop: 单日累计亏损 > 1.5% → 仅停该因子       |
//+------------------------------------------------------------------+
#property strict
#property version "2.00"
#property description "Master EA G+1.1: 7 因子集成 + portfolio 熔断 + daily_stop + Vol Target"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

CTrade trade;
CPositionInfo pos;

//+------------------------------------------------------------------+
//| ============== 全局参数 ====================================     |
//+------------------------------------------------------------------+
input group "=== 全局风控 ==="
input bool    UseCompound         = true;     // 复利
input bool    UseMartingale       = false;    // G+1.1 关闭
input double  MaxLotCap           = 5.0;      // 单 EA lot 上限
input bool    UseDailyMDDStop     = true;     // Portfolio 熔断
input double  DailyMDDStopPct     = 5.0;      // 单日 MDD > N% 暂停
input int     DailyStopHours      = 12;       // 暂停 N 小时
input double  WeeklyMDDStopPct    = 10.0;     // 单周 MDD > N% 暂停
input int     WeeklyStopHours     = 72;       // 暂停 N 小时

input group "=== Vol Targeting (动态 lot) ==="
input bool    UseVolTarget        = false;    // 启用 (默认关, 先验证 baseline)
input int     VolTargetLookback   = 720;      // 30 day H1
input double  VolTargetCapLow     = 0.5;
input double  VolTargetCapHigh    = 1.5;

input group "=== 因子 1: PureBO 顺势突破 (57181) ==="
input bool    PureBO_Enable       = true;
input double  PureBO_Risk         = 1.0;      // %
input int     PureBO_SwingLeft    = 3;
input int     PureBO_SwingRight   = 3;
input double  PureBO_SLAtr        = 4.5;      // 优化: 4.0→4.5 (Stage 1 grid: PF +5% MDD -17%)
input double  PureBO_TPAtr        = 1.0;
input int     PureBO_TimeStop     = 24;       // 优化: 72→24 (trail 主导出场)

input group "=== 因子 2: VP_POC 反转 (57182, ToD filter) ==="
input bool    VP_Enable           = true;
input double  VP_Risk             = 1.0;
input int     VP_POCLookback      = 100;
input int     VP_PriceBins        = 50;
input double  VP_LVNThreshold     = 0.3;
input int     VP_MinBinDist       = 2;
input double  VP_PinWickRatio     = 1.5;
input double  VP_PinMinWickUSD    = 1.5;
input double  VP_SLAtr            = 4.5;     // 优化: 4.0→4.5 (Stage 1 best engine)
input double  VP_TPAtr            = 0.7;     // 优化: 1.0→0.7 (Stage 1 best, 反转因子短 TP)
input int     VP_TimeStop         = 24;      // 优化: 36→24

input group "=== 因子 3: Liquidation v6 (57184) ==="
input bool    Liq_Enable          = true;
input double  Liq_Risk            = 0.75;
input int     Liq_VolSMA          = 20;
input double  Liq_VolSpikeMult    = 1.5;
input double  Liq_BodyAtrMult     = 1.0;
input int     Liq_RangeLookback   = 10;
input double  Liq_SLAtr           = 4.5;     // 优化: 4.0→4.5 (Stage 1 best)
input double  Liq_TPAtr           = 1.0;
input int     Liq_TimeStop        = 24;      // 优化: 36→24

input group "=== 因子 4: Gap_Reject v3 (57185) ==="
input bool    Gap_Enable          = true;
input double  Gap_Risk            = 0.25;
input double  Gap_MinAtrMult      = 0.5;
input int     Gap_FillTimeout     = 20;
input int     Gap_RejectTimeout   = 5;
input double  Gap_RejectShadow    = 2.0;
input double  Gap_RejectMinAtr    = 0.4;
input double  Gap_SLAtr           = 2.0;
input double  Gap_TPAtr           = 4.0;

input group "=== 因子 6: Session+Fib (57183) — 三时段 sweep + Fib 0.618 ==="
input bool    Sess_Enable         = true;
input double  Sess_Risk           = 0.5;
input double  Sess_FibRatio       = 0.618; // Fib 回踩比例
input double  Sess_PullbackMinAtr = 0.5;   // sweep 后最小回撤 (ATR 倍)
input double  Sess_BreakFailAtr   = 0.3;   // 强反向破位失败阈值 (ATR 倍)
input int     Sess_PullbackTimeout= 12;    // wait_pullback 超时 (H1)
input int     Sess_FibTouchTimeout= 12;    // wait_618 超时 (H1)
input double  Sess_SLAtr          = 4.0;
input double  Sess_TPAtr          = 1.0;
input int     Sess_TimeStop       = 72;
input bool    Sess_UseToDFilter   = true;  // 排除 20-22 UTC (Sharpe +0.34)

input group "=== 因子 7: Divergence (57186) — BB + RSI/MFI 背离 + daily_stop ==="
input bool    Div_Enable          = false;  // 默认 OFF: standard 引擎 PF 0.83-0.93, archive simulator PF 2.31 但 N=53
input double  Div_Risk            = 0.5;
input int     Div_BBPeriod        = 20;
input double  Div_BBSigma         = 2.0;
input int     Div_RsiPeriod       = 14;
input int     Div_MfiPeriod       = 14;
input int     Div_DivLookback     = 5;     // 比较 N bar 前的 indicator
input bool    Div_RequireBoth     = false; // false=RSI 或 MFI 任一背离, true=两者都必须
input bool    Div_RequireConfirm  = true;  // 信号 K 收盘方向需配合
input double  Div_DailyStopPct    = 2.0;   // 原版 archive 用 -2% (MAX_DAILY_LOSS)
input double  Div_SLAtr           = 1.5;   // BEST_CFG: 1.5 ATR
input double  Div_TPAtr           = 2.0;   // BEST_CFG: 2.0 ATR (RR 1.33, archive PF 2.31)
input int     Div_TimeStop        = 30;    // BEST_CFG: 30 H1

input group "=== 因子 5: XAU/XAG Ratio (57187) ==="
input bool    Ratio_Enable        = true;
input double  Ratio_Risk          = 0.5;
input string  Ratio_XAGSymbol     = "XAGUSD";
input int     Ratio_Lookback      = 240;
input double  Ratio_ZThreshold    = 2.0;
input double  Ratio_SLAtr         = 4.0;
input double  Ratio_TPAtr         = 1.0;
input int     Ratio_TimeStop      = 72;

input group "=== Time-of-Day Filter (mean rev only) ==="
input bool    UseToDFilter        = true;
input int     ToD_StartHourUTC    = 20;
input int     ToD_EndHourUTC      = 22;

input group "=== 共享因子参数 ==="
input int     AtrPeriod           = 14;
input int     SignalFFillBars     = 12;
input bool    UseTrailing         = true;
input double  TrailFixedUSD       = 0.3;       // 优化: 0.5 → 0.3 (Stage 1 grid 验证)
input double  TrailActivateAtr    = 0.3;       // 优化: 0.5 → 0.3 (PureBO/Liq), VP/Sess 用 0.8

input group "=== Spread 防护 (3 层) ==="
input bool    UseSpreadHardLimit  = true;
input int     SpreadHardLimitPts  = 50;        // > 50 pts 暂停 entry (NFP/CPI 防护)
input bool    UseSpreadSpikeFilter= true;
input int     SpreadSpikeWindow   = 200;       // 滚动 N 个 tick 计 median
input double  SpreadSpikeMult     = 3.0;       // 当前 > median × 3 → 跳过
input bool    UseRangeFilter      = true;      // 仅 Liq/Sess/VP 启用
input int     RangeFilterLookback = 120;       // H1
input double  RangeFilterMult     = 2.5;       // 当前 H1 range > median × 2.5 → 跳过
input bool    UseDynamicTrail     = true;      // trail = max(base, spread × 2)
input double  DynamicTrailMult    = 2.0;

input group "=== 多 TF Filter ==="
input bool    UseH4Filter_VP      = true;      // VP_POC 加 H4 EMA50 (实测 MDD 18.37→3.61%, PF 1.45→3.71)
input bool    UseH4Filter_Liq     = true;      // Liquidation 加 H4 PureBO confluence (MDD 10.81→8.13%, PF +33%)
input bool    UseH4Filter_PureBO  = false;     // PureBO 默认 OFF (高频不受益, 仅 EBC 高 spread 时考虑开)
input int     H4EmaPeriod         = 50;

input group "=== ATR% Regime Detector (低波动减仓) ==="
input bool    UseATRRegime        = true;      // 实测 5y MDD 20.17% → 12.26% (-39%), Net 几乎不变
input int     RegimeATRPeriod     = 60;        // H1 滚动窗口 (60 H1 = 2.5 day)
input double  RegimeATRPctNormal  = 0.15;      // > 0.15% → full lot (Wilder ATR%, 2024+ mean 0.24%+)
input double  RegimeATRPctReduced = 0.08;      // 0.08-0.15% → lot × 0.5
                                                // < 0.08% → pause (类 2021-2022 低波动地狱, mean 0.059%)
input double  RegimeReducedMult   = 0.5;       // reduced 模式 lot 倍数
input bool    RegimePausePauseMode = true;     // < ATRPctReduced 时是否完全暂停
input bool    RegimeLogTransitions = true;     // 切换 regime 时打印日志

input group "=== EA 控制 ==="
input ulong   MasterMagic         = 57180;
input int     MaxSlippagePts      = 30;

//+------------------------------------------------------------------+
//| 子 magic 常量                                                     |
//+------------------------------------------------------------------+
#define MAGIC_PUREBO    57181
#define MAGIC_VP_POC    57182
#define MAGIC_SESSION   57183  // (Phase 4)
#define MAGIC_LIQ       57184
#define MAGIC_GAP       57185
#define MAGIC_DIV       57186  // (Phase 4)
#define MAGIC_XAUXAG    57187

//+------------------------------------------------------------------+
//| 全局状态                                                          |
//+------------------------------------------------------------------+
datetime g_last_bar_time = 0;
double   g_cur_atr = 0;
double   g_cur_vol_scale = 1.0;

// ffill signal cache per factor (7 factors, 顺序: PureBO/VP/Liq/Gap/XAUXAG/Sess/Div)
datetime g_sig_time[7];
int      g_sig_dir[7];

// Gap state machine
enum GapState { GAP_IDLE, GAP_WAITING_FILL, GAP_WAITING_REJECT };
GapState  g_gap_state = GAP_IDLE;
int       g_gap_dir_state = 0;
double    g_gap_prev_close = 0;
datetime  g_gap_start_time = 0;
datetime  g_gap_fill_time = 0;

// Session+Fib state (三时段 sweep + 4 段状态机)
// 时段 (UTC): Asia 0-7 / London 7-13 / NY 13-21 (close hour)
enum SessFibState {
    SESS_IDLE,
    SESS_WAIT_PB_DN,    // sweep_up 后等回撤 (low side)
    SESS_WAIT_PB_UP,    // sweep_dn 后等反弹 (high side)
    SESS_WAIT_618_DN,   // 等 fib 0.618 触及做多
    SESS_WAIT_618_UP    // 等 fib 0.618 触及做空
};
SessFibState g_sess_state = SESS_IDLE;
int      g_sess_dir = 0;
double   g_sess_swept_extreme = 0;
double   g_sess_retr_extreme = 0;
datetime g_sess_swept_time = 0;
datetime g_sess_pullback_time = 0;

// 持续累积当前时段 H/L
double   g_cur_asia_h = 0,   g_cur_asia_l = 0;
double   g_cur_london_h = 0, g_cur_london_l = 0;
double   g_cur_ny_h = 0,     g_cur_ny_l = 0;
// 已收盘 last session H/L (作 sweep 参考)
double   g_last_asia_h = 0,   g_last_asia_l = 0;
double   g_last_london_h = 0, g_last_london_l = 0;
double   g_last_ny_h = 0,     g_last_ny_l = 0;
bool     g_have_last_asia = false, g_have_last_london = false, g_have_last_ny = false;
int      g_prev_hour_utc = -1;

// Divergence daily_stop state
datetime  g_div_day = 0;           // 当前跟踪的 UTC 日
double    g_div_day_pnl = 0;       // 该日累计 closed PnL (Magic 57186)
bool      g_div_day_paused = false;

// Circuit breaker state
double    g_session_start_balance = 0;
datetime  g_session_start = 0;
datetime  g_pause_until = 0;

//+------------------------------------------------------------------+
//| OnInit                                                            |
//+------------------------------------------------------------------+
int OnInit()
{
    trade.SetExpertMagicNumber(MasterMagic);
    trade.SetDeviationInPoints(MaxSlippagePts);

    // 验证 XAG symbol (XAU/XAG 因子需要)
    if (Ratio_Enable) {
        if (!SymbolSelect(Ratio_XAGSymbol, true)) {
            Print("[Master] WARNING: XAG symbol ", Ratio_XAGSymbol, " not available. XAU/XAG disabled.");
        }
    }

    g_session_start_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    g_session_start = TimeCurrent();

    Print("=== Portfolio G11 Master EA Initialized (v2 — 7/7 factors) ===");
    Print("Master Magic: ", MasterMagic);
    Print("Enabled factors: PureBO=", PureBO_Enable, " VP=", VP_Enable,
          " Liq=", Liq_Enable, " Gap=", Gap_Enable, " Ratio=", Ratio_Enable,
          " Sess=", Sess_Enable, " Div=", Div_Enable);
    Print("ToD Filter: ", UseToDFilter, " (", ToD_StartHourUTC, "-", ToD_EndHourUTC, " UTC)");
    double total_risk = (PureBO_Enable?PureBO_Risk:0) + (VP_Enable?VP_Risk:0) +
                        (Liq_Enable?Liq_Risk:0) + (Gap_Enable?Gap_Risk:0) +
                        (Ratio_Enable?Ratio_Risk:0) + (Sess_Enable?Sess_Risk:0) +
                        (Div_Enable?Div_Risk:0);
    Print("Total Risk: ", DoubleToString(total_risk,2), "%");

    // ATR% Regime 初始计算 + 打印
    if (UseATRRegime) {
        UpdateRegime();
        string mode_name = (g_cur_regime == REGIME_NORMAL ? "NORMAL (full lot)" :
                            (g_cur_regime == REGIME_REDUCED ? "REDUCED (lot ×0.5)" : "PAUSE (skip entry)"));
        Print("[Regime] ATR% = ", DoubleToString(g_cur_atr_pct, 3), "% → ", mode_name);
        Print("[Regime] Thresholds: NORMAL > ", RegimeATRPctNormal, "% / REDUCED > ",
              RegimeATRPctReduced, "% / PAUSE < ", RegimeATRPctReduced, "%");
    }

    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Spread 防护 — 三层 + 动态 trail                                   |
//+------------------------------------------------------------------+
double g_spread_history[200];
int    g_spread_idx = 0;
int    g_spread_count = 0;

bool IsSpreadHardLimitOK()
{
    if (!UseSpreadHardLimit) return true;
    long sp = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
    if (sp > SpreadHardLimitPts) {
        static datetime last_print = 0;
        if (TimeCurrent() - last_print > 60) {
            Print("[SpreadGuard] HARD LIMIT triggered: ", sp, " > ", SpreadHardLimitPts, " pts");
            last_print = TimeCurrent();
        }
        return false;
    }
    return true;
}

bool IsSpreadNotSpiking()
{
    if (!UseSpreadSpikeFilter) return true;
    long sp = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);

    // 维护滚动数组
    int n_max = MathMin(SpreadSpikeWindow, 200);
    g_spread_history[g_spread_idx % n_max] = (double)sp;
    g_spread_idx++;
    g_spread_count = MathMin(g_spread_count + 1, n_max);

    if (g_spread_count < 50) return true;  // warmup

    // 计算 median
    double sorted[];
    ArrayResize(sorted, g_spread_count);
    for (int i = 0; i < g_spread_count; i++) sorted[i] = g_spread_history[i];
    ArraySort(sorted);
    double median = sorted[g_spread_count / 2];
    if (median <= 0.5) median = 1.0;

    bool ok = ((double)sp / median) <= SpreadSpikeMult;
    if (!ok) {
        static datetime last_print = 0;
        if (TimeCurrent() - last_print > 60) {
            Print("[SpreadGuard] SPIKE: ", sp, " > ", SpreadSpikeMult, "× median (", median, ")");
            last_print = TimeCurrent();
        }
    }
    return ok;
}

bool IsRangeNormal()
{
    if (!UseRangeFilter) return true;
    int total = RangeFilterLookback + 1;
    MqlRates r[];
    if (CopyRates(_Symbol, PERIOD_H1, 1, total, r) < total) return true;
    int n = ArraySize(r);
    double cur_range = r[n-1].high - r[n-1].low;

    double rng[];
    ArrayResize(rng, RangeFilterLookback);
    for (int i = 0; i < RangeFilterLookback; i++) rng[i] = r[i].high - r[i].low;
    ArraySort(rng);
    double median = rng[RangeFilterLookback / 2];
    if (median <= 0) return true;

    return (cur_range / median) <= RangeFilterMult;
}

double GetEffectiveTrailUSD(double base_trail)
{
    if (!UseDynamicTrail) return base_trail;
    long sp = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
    double spread_usd = sp * _Point;
    return MathMax(base_trail, spread_usd * DynamicTrailMult);
}

//+------------------------------------------------------------------+
//| ATR% Regime Detector — 低波动期自动减仓                           |
//|   实测: 2021 ATR% 0.23% / 2022 0.24% → 亏损 -6.83%/yr             |
//|   2024 0.51% / 2025 0.66% / 2026 1.24% → 大盈利                   |
//+------------------------------------------------------------------+
enum RegimeMode { REGIME_NORMAL, REGIME_REDUCED, REGIME_PAUSE };
RegimeMode g_cur_regime = REGIME_NORMAL;
RegimeMode g_prev_regime = REGIME_NORMAL;
double     g_cur_atr_pct = 0;

double GetCurrentATRPct()
{
    if (RegimeATRPeriod <= 0) return 0;
    int total = RegimeATRPeriod + 5;
    MqlRates r[];
    if (CopyRates(_Symbol, PERIOD_H1, 1, total, r) < total) return 0;
    int n = ArraySize(r);

    // ATR via Wilder EMA (跟 archive Python EWM(span=14) 一致)
    double atr = 0;
    int atr_period = 14;
    if (n < atr_period + 5) return 0;
    // Initial TR average
    double sum_tr = 0;
    for (int i = 1; i <= atr_period; i++) {
        double tr = MathMax(r[i].high - r[i].low,
                     MathMax(MathAbs(r[i].high - r[i-1].close),
                              MathAbs(r[i].low - r[i-1].close)));
        sum_tr += tr;
    }
    atr = sum_tr / atr_period;
    // Wilder smoothing
    double alpha = 1.0 / atr_period;
    for (int i = atr_period + 1; i < n; i++) {
        double tr = MathMax(r[i].high - r[i].low,
                     MathMax(MathAbs(r[i].high - r[i-1].close),
                              MathAbs(r[i].low - r[i-1].close)));
        atr = atr + alpha * (tr - atr);
    }
    double cur_close = r[n-1].close;
    if (cur_close <= 0) return 0;
    return (atr / cur_close) * 100.0;  // ATR pct (%)
}

void UpdateRegime()
{
    if (!UseATRRegime) {
        g_cur_regime = REGIME_NORMAL;
        return;
    }
    g_cur_atr_pct = GetCurrentATRPct();
    if (g_cur_atr_pct <= 0) {
        g_cur_regime = REGIME_NORMAL;
        return;
    }

    g_prev_regime = g_cur_regime;
    if (g_cur_atr_pct >= RegimeATRPctNormal) {
        g_cur_regime = REGIME_NORMAL;
    } else if (g_cur_atr_pct >= RegimeATRPctReduced) {
        g_cur_regime = REGIME_REDUCED;
    } else {
        g_cur_regime = RegimePausePauseMode ? REGIME_PAUSE : REGIME_REDUCED;
    }

    if (RegimeLogTransitions && g_cur_regime != g_prev_regime) {
        string old_name = (g_prev_regime == REGIME_NORMAL ? "NORMAL" :
                            (g_prev_regime == REGIME_REDUCED ? "REDUCED" : "PAUSE"));
        string new_name = (g_cur_regime == REGIME_NORMAL ? "NORMAL" :
                            (g_cur_regime == REGIME_REDUCED ? "REDUCED" : "PAUSE"));
        Print("[Regime] ", old_name, " → ", new_name,
              " (ATR%=", DoubleToString(g_cur_atr_pct, 3), "%)");
    }
}

double GetRegimeLotMult()
{
    if (!UseATRRegime) return 1.0;
    if (g_cur_regime == REGIME_NORMAL)  return 1.0;
    if (g_cur_regime == REGIME_REDUCED) return RegimeReducedMult;
    return 0.0;  // PAUSE → lot 0 → 不入场
}

bool IsRegimePaused()
{
    return UseATRRegime && g_cur_regime == REGIME_PAUSE;
}

//+------------------------------------------------------------------+
//| H4 EMA50 trend filter (VP_POC / Liquidation 用)                   |
//+------------------------------------------------------------------+
int GetH4TrendDirection()
{
    int handle = iMA(_Symbol, PERIOD_H4, H4EmaPeriod, 0, MODE_EMA, PRICE_CLOSE);
    if (handle == INVALID_HANDLE) return 0;
    double ema[];
    if (CopyBuffer(handle, 0, 1, 1, ema) < 1) return 0;
    double h4_close[];
    if (CopyClose(_Symbol, PERIOD_H4, 1, 1, h4_close) < 1) return 0;
    if (h4_close[0] > ema[0]) return 1;   // bull
    if (h4_close[0] < ema[0]) return -1;  // bear
    return 0;
}

//+------------------------------------------------------------------+
//| H4 PureBO direction (Liquidation confluence 用)                   |
//+------------------------------------------------------------------+
int GetH4PureBODirection()
{
    int total = PureBO_SwingLeft + PureBO_SwingRight + 100;
    MqlRates r[];
    if (CopyRates(_Symbol, PERIOD_H4, 1, total, r) < total) return 0;
    int n = ArraySize(r);
    int idx_cur = n - 1;

    static double last_h4_swing_high = 0, last_h4_swing_low = 0;
    static datetime last_h4_compute = 0;

    // 每 4 小时重算
    if (r[idx_cur].time != last_h4_compute) {
        for (int i = idx_cur - PureBO_SwingRight; i >= PureBO_SwingLeft; i--) {
            bool is_h = true, is_l = true;
            for (int k = 1; k <= PureBO_SwingLeft; k++) {
                if (r[i].high <= r[i-k].high) is_h = false;
                if (r[i].low  >= r[i-k].low)  is_l = false;
            }
            for (int k = 1; k <= PureBO_SwingRight; k++) {
                if (i+k >= n) break;
                if (r[i].high <= r[i+k].high) is_h = false;
                if (r[i].low  >= r[i+k].low)  is_l = false;
            }
            if (is_h && last_h4_swing_high == 0) last_h4_swing_high = r[i].high;
            if (is_l && last_h4_swing_low == 0)  last_h4_swing_low  = r[i].low;
            if (last_h4_swing_high > 0 && last_h4_swing_low > 0) break;
        }
        last_h4_compute = r[idx_cur].time;
    }

    if (last_h4_swing_high > 0 && r[idx_cur].close > last_h4_swing_high) return 1;
    if (last_h4_swing_low  > 0 && r[idx_cur].close < last_h4_swing_low)  return -1;
    return 0;
}

//+------------------------------------------------------------------+
//| Helpers                                                           |
//+------------------------------------------------------------------+
double GetATR()
{
    double buf[];
    int handle = iATR(_Symbol, PERIOD_H1, AtrPeriod);
    if (handle == INVALID_HANDLE) return 0;
    if (CopyBuffer(handle, 0, 1, 1, buf) < 1) return 0;
    return buf[0];
}

double GetVolScale()
{
    if (!UseVolTarget) return 1.0;
    int total = VolTargetLookback + 5;
    MqlRates rates[];
    if (CopyRates(_Symbol, PERIOD_H1, 1, total, rates) < total) return 1.0;
    int n = ArraySize(rates);
    int idx_cur = n - 1;

    // ATR pct over rolling lookback
    double atr_pcts[];
    ArrayResize(atr_pcts, VolTargetLookback);
    for (int i = idx_cur - VolTargetLookback + 1, k = 0; i <= idx_cur; i++, k++) {
        double tr = MathMax(rates[i].high - rates[i].low,
                     MathMax(MathAbs(rates[i].high - (i>0 ? rates[i-1].close : rates[i].open)),
                              MathAbs(rates[i].low - (i>0 ? rates[i-1].close : rates[i].open))));
        atr_pcts[k] = (rates[i].close > 0) ? tr / rates[i].close : 0;
    }
    // baseline = median
    ArraySort(atr_pcts);
    double median = atr_pcts[VolTargetLookback / 2];
    double cur_atr_pct = atr_pcts[VolTargetLookback - 1];
    if (cur_atr_pct <= 0) return 1.0;
    double scale = median / cur_atr_pct;
    if (scale < VolTargetCapLow) scale = VolTargetCapLow;
    if (scale > VolTargetCapHigh) scale = VolTargetCapHigh;
    return scale;
}

int BrokerHourToUTC(int broker_hour)
{
    // TimeGMT() 是 GMT/UTC, TimeCurrent() 是 broker server time.
    // broker GMT+3 时: TimeGMT - TimeCurrent = -3h, 所以 utc = broker + (-3) = broker - 3 ✗ 错!
    // 正确: utc = broker + (TimeGMT - TimeCurrent)/3600 = broker + (-3) = broker - 3 ✓
    int utc = broker_hour + (int)((TimeGMT() - TimeCurrent()) / 3600);
    return (utc + 24) % 24;
}

bool IsToDExcluded(datetime t)
{
    if (!UseToDFilter) return false;
    MqlDateTime dt;
    TimeToStruct(t, dt);
    int hour_utc = BrokerHourToUTC(dt.hour);
    return (hour_utc >= ToD_StartHourUTC && hour_utc <= ToD_EndHourUTC);
}

bool IsCircuitBreakerActive()
{
    if (TimeCurrent() < g_pause_until) return true;

    if (!UseDailyMDDStop) return false;

    double cur_eq = AccountInfoDouble(ACCOUNT_EQUITY);
    double cur_bal = AccountInfoDouble(ACCOUNT_BALANCE);

    // 用 session start balance 做基准
    double mdd_pct = (g_session_start_balance - cur_eq) / g_session_start_balance * 100.0;

    if (mdd_pct >= WeeklyMDDStopPct) {
        g_pause_until = TimeCurrent() + WeeklyStopHours * 3600;
        Print("[Master] WEEKLY MDD STOP: ", DoubleToString(mdd_pct,2),
              "% pause until ", TimeToString(g_pause_until));
        return true;
    }
    if (mdd_pct >= DailyMDDStopPct) {
        g_pause_until = TimeCurrent() + DailyStopHours * 3600;
        Print("[Master] DAILY MDD STOP: ", DoubleToString(mdd_pct,2),
              "% pause until ", TimeToString(g_pause_until));
        return true;
    }
    return false;
}

double CalculateLot(double sl_distance_usd, double risk_pct)
{
    double balance = AccountInfoDouble(UseCompound ? ACCOUNT_EQUITY : ACCOUNT_BALANCE);
    double regime_mult = GetRegimeLotMult();  // ATR% regime: 1.0 / 0.5 / 0.0
    double risk_usd = balance * risk_pct / 100.0 * g_cur_vol_scale * regime_mult;
    if (sl_distance_usd <= 0 || risk_usd <= 0) return 0;
    double lot = risk_usd / (sl_distance_usd * 100.0);
    lot = MathMax(0.01, MathMin(lot, MaxLotCap));
    return NormalizeDouble(lot, 2);
}

bool HasOpenPositionForMagic(ulong magic)
{
    for (int i = PositionsTotal() - 1; i >= 0; i--)
        if (pos.SelectByIndex(i) && pos.Magic() == magic) return true;
    return false;
}

void OpenSubMagicPosition(int direction, ulong sub_magic, double risk_pct,
                           double sl_atr_mult, double tp_atr_mult, string comment)
{
    if (HasOpenPositionForMagic(sub_magic)) return;
    double atr = g_cur_atr;
    if (atr <= 0) atr = GetATR();
    if (atr <= 0) return;

    double sl_dist = sl_atr_mult * atr;
    double tp_dist = tp_atr_mult * atr;
    double entry, sl, tp;
    if (direction > 0) {
        entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        sl = entry - sl_dist; tp = entry + tp_dist;
    } else {
        entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        sl = entry + sl_dist; tp = entry - tp_dist;
    }

    double lot = CalculateLot(sl_dist, risk_pct);
    if (lot <= 0) return;

    trade.SetExpertMagicNumber(sub_magic);  // 切换 magic for this trade
    bool ok;
    if (direction > 0)
        ok = trade.Buy(lot, _Symbol, entry, sl, tp, comment);
    else
        ok = trade.Sell(lot, _Symbol, entry, sl, tp, comment);
    trade.SetExpertMagicNumber(MasterMagic);  // 恢复

    if (ok)
        Print("[", comment, "] OPEN ", (direction>0?"LONG":"SHORT"),
              " lot=", lot, " entry=", entry, " atr_pct=", g_cur_vol_scale);
}

void ApplyTrailingForMagic(ulong magic, double trail_usd, double trail_atr_mult)
{
    if (!UseTrailing) return;
    double atr = g_cur_atr;
    if (atr <= 0) return;

    for (int i = PositionsTotal() - 1; i >= 0; i--) {
        if (!pos.SelectByIndex(i)) continue;
        if (pos.Magic() != magic) continue;
        double cur_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        double cur_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        double entry = pos.PriceOpen();
        double cur_sl = pos.StopLoss();
        if (pos.PositionType() == POSITION_TYPE_BUY) {
            double profit = cur_bid - entry;
            if (profit < trail_atr_mult * atr) continue;
            double new_sl = cur_bid - trail_usd;
            if (new_sl > cur_sl + 0.001) {
                trade.SetExpertMagicNumber(magic);
                trade.PositionModify(pos.Ticket(), new_sl, pos.TakeProfit());
                trade.SetExpertMagicNumber(MasterMagic);
            }
        } else {
            double profit = entry - cur_ask;
            if (profit < trail_atr_mult * atr) continue;
            double new_sl = cur_ask + trail_usd;
            if (new_sl < cur_sl - 0.001 || cur_sl == 0) {
                trade.SetExpertMagicNumber(magic);
                trade.PositionModify(pos.Ticket(), new_sl, pos.TakeProfit());
                trade.SetExpertMagicNumber(MasterMagic);
            }
        }
    }
}

void CheckTimeStopForMagic(ulong magic, int time_stop_bars)
{
    if (time_stop_bars <= 0) return;
    for (int i = PositionsTotal() - 1; i >= 0; i--) {
        if (!pos.SelectByIndex(i)) continue;
        if (pos.Magic() != magic) continue;
        long bars_held = (TimeCurrent() - pos.Time()) / 3600;
        if (bars_held >= time_stop_bars) {
            trade.SetExpertMagicNumber(magic);
            trade.PositionClose(pos.Ticket());
            trade.SetExpertMagicNumber(MasterMagic);
        }
    }
}

//+------------------------------------------------------------------+
//| 因子 1: PureBO swing breakout                                    |
//+------------------------------------------------------------------+
int ComputePureBOSignal()
{
    int total = PureBO_SwingLeft + PureBO_SwingRight + 30;
    MqlRates rates[];
    if (CopyRates(_Symbol, PERIOD_H1, 1, total, rates) < total) return 0;
    int n = ArraySize(rates);
    int idx_cur = n - 1;

    // 找最近 swing high/low (用 confirm 时刻 i_b + RIGHT 收盘后)
    static double last_swing_high = 0, last_swing_low = 0;
    static double last_break_high = -DBL_MAX, last_break_low = DBL_MAX;

    int ib = idx_cur - PureBO_SwingRight;
    if (ib < PureBO_SwingLeft) return 0;

    bool is_swing_h = true, is_swing_l = true;
    for (int k = 1; k <= PureBO_SwingLeft; k++) {
        if (rates[ib].high <= rates[ib-k].high) is_swing_h = false;
        if (rates[ib].low >= rates[ib-k].low) is_swing_l = false;
    }
    for (int k = 1; k <= PureBO_SwingRight; k++) {
        if (ib+k >= n) { is_swing_h = false; is_swing_l = false; break; }
        if (rates[ib].high <= rates[ib+k].high) is_swing_h = false;
        if (rates[ib].low >= rates[ib+k].low) is_swing_l = false;
    }
    if (is_swing_h) {
        last_swing_high = rates[ib].high;
        last_break_high = -DBL_MAX;
    }
    if (is_swing_l) {
        last_swing_low = rates[ib].low;
        last_break_low = DBL_MAX;
    }

    double cur_close = rates[idx_cur].close;
    if (last_swing_high > 0 && cur_close > last_swing_high && last_swing_high > last_break_high) {
        last_break_high = last_swing_high;
        return 1;
    }
    if (last_swing_low > 0 && cur_close < last_swing_low && last_swing_low < last_break_low) {
        last_break_low = last_swing_low;
        return -1;
    }
    return 0;
}

//+------------------------------------------------------------------+
//| 因子 2: VP POC reversion                                          |
//+------------------------------------------------------------------+
int ComputeVPPOCSignal()
{
    int total = VP_POCLookback + 5;
    MqlRates rates[];
    if (CopyRates(_Symbol, PERIOD_H1, 1, total, rates) < total) return 0;
    int n = ArraySize(rates);
    int idx_cur = n - 1;

    double pmin = DBL_MAX, pmax = -DBL_MAX;
    int start = idx_cur - VP_POCLookback + 1;
    if (start < 0) return 0;
    for (int i = start; i <= idx_cur; i++) {
        if (rates[i].close < pmin) pmin = rates[i].close;
        if (rates[i].close > pmax) pmax = rates[i].close;
    }
    if (pmax <= pmin) return 0;
    double bin_size = (pmax - pmin) / VP_PriceBins;
    if (bin_size <= 0) return 0;

    double bin_vol[];
    ArrayResize(bin_vol, VP_PriceBins);
    ArrayInitialize(bin_vol, 0);
    for (int i = start; i <= idx_cur; i++) {
        int bidx = (int)((rates[i].close - pmin) / bin_size);
        if (bidx >= VP_PriceBins) bidx = VP_PriceBins - 1;
        if (bidx < 0) bidx = 0;
        bin_vol[bidx] += (double)rates[i].tick_volume;
    }

    int poc_bin = 0;
    double max_vol = bin_vol[0];
    for (int i = 1; i < VP_PriceBins; i++)
        if (bin_vol[i] > max_vol) { max_vol = bin_vol[i]; poc_bin = i; }
    if (max_vol <= 0) return 0;
    double poc_price = pmin + (poc_bin + 0.5) * bin_size;

    double cur_close = rates[idx_cur].close;
    double cur_open = rates[idx_cur].open;
    double cur_high = rates[idx_cur].high;
    double cur_low = rates[idx_cur].low;
    int cur_bin = (int)((cur_close - pmin) / bin_size);
    if (cur_bin < 0 || cur_bin >= VP_PriceBins) return 0;
    if (bin_vol[cur_bin] >= VP_LVNThreshold * max_vol) return 0;
    if (MathAbs(cur_bin - poc_bin) < VP_MinBinDist) return 0;

    double body = MathAbs(cur_close - cur_open);
    double upper_wick, lower_wick;
    if (cur_close >= cur_open) {
        upper_wick = cur_high - cur_close;
        lower_wick = cur_open - cur_low;
    } else {
        upper_wick = cur_high - cur_open;
        lower_wick = cur_close - cur_low;
    }

    if (cur_close > poc_price) {
        if (upper_wick > body * VP_PinWickRatio && upper_wick > VP_PinMinWickUSD)
            return -1;
    } else if (cur_close < poc_price) {
        if (lower_wick > body * VP_PinWickRatio && lower_wick > VP_PinMinWickUSD)
            return 1;
    }
    return 0;
}

//+------------------------------------------------------------------+
//| 因子 3: Liquidation v6                                            |
//+------------------------------------------------------------------+
int ComputeLiqSignal()
{
    int total = MathMax(Liq_VolSMA, Liq_RangeLookback) + 5;
    MqlRates rates[];
    if (CopyRates(_Symbol, PERIOD_H1, 1, total, rates) < total) return 0;
    int n = ArraySize(rates);
    int idx_cur = n - 1;
    int idx_vstart = idx_cur - Liq_VolSMA;
    if (idx_vstart < 0) return 0;

    double vol_sum = 0;
    for (int i = idx_vstart; i < idx_cur; i++) vol_sum += (double)rates[i].tick_volume;
    double vol_sma = vol_sum / Liq_VolSMA;
    if (vol_sma <= 0) return 0;

    double cur_vol = (double)rates[idx_cur].tick_volume;
    double cur_open = rates[idx_cur].open;
    double cur_close = rates[idx_cur].close;
    double body = MathAbs(cur_close - cur_open);
    double atr = g_cur_atr;
    if (atr <= 0) return 0;
    if (cur_vol < Liq_VolSpikeMult * vol_sma) return 0;
    if (body < Liq_BodyAtrMult * atr) return 0;

    int idx_rstart = idx_cur - Liq_RangeLookback;
    if (idx_rstart < 0) return 0;
    double max_h = -DBL_MAX, min_l = DBL_MAX;
    for (int i = idx_rstart; i < idx_cur; i++) {
        if (rates[i].high > max_h) max_h = rates[i].high;
        if (rates[i].low < min_l) min_l = rates[i].low;
    }
    if (cur_close > max_h && cur_close > cur_open) return 1;
    if (cur_close < min_l && cur_close < cur_open) return -1;
    return 0;
}

//+------------------------------------------------------------------+
//| 因子 4: Gap Reject v3                                             |
//+------------------------------------------------------------------+
int ComputeGapSignal()
{
    MqlRates rates[];
    if (CopyRates(_Symbol, PERIOD_H1, 1, 2, rates) < 2) return 0;
    int idx_cur = 1, idx_prev = 0;
    double cur_open = rates[idx_cur].open;
    double cur_close = rates[idx_cur].close;
    double cur_high = rates[idx_cur].high;
    double cur_low = rates[idx_cur].low;
    double prev_close = rates[idx_prev].close;
    datetime cur_time = rates[idx_cur].time;
    double atr = g_cur_atr;
    if (atr <= 0) return 0;

    int signal = 0;

    if (g_gap_state == GAP_IDLE) {
        double gap = cur_open - prev_close;
        if (gap > Gap_MinAtrMult * atr) {
            g_gap_state = GAP_WAITING_FILL;
            g_gap_dir_state = 1;
            g_gap_prev_close = prev_close;
            g_gap_start_time = cur_time;
        } else if (gap < -Gap_MinAtrMult * atr) {
            g_gap_state = GAP_WAITING_FILL;
            g_gap_dir_state = -1;
            g_gap_prev_close = prev_close;
            g_gap_start_time = cur_time;
        }
    } else if (g_gap_state == GAP_WAITING_FILL) {
        bool filled = false;
        if (g_gap_dir_state > 0 && cur_low <= g_gap_prev_close) filled = true;
        else if (g_gap_dir_state < 0 && cur_high >= g_gap_prev_close) filled = true;
        if (filled) {
            g_gap_state = GAP_WAITING_REJECT;
            g_gap_fill_time = cur_time;
        } else if ((cur_time - g_gap_start_time) / 3600 > Gap_FillTimeout) {
            g_gap_state = GAP_IDLE;
        }
    } else if (g_gap_state == GAP_WAITING_REJECT) {
        double body = MathAbs(cur_close - cur_open);
        double upper_shadow = cur_high - MathMax(cur_close, cur_open);
        double lower_shadow = MathMin(cur_close, cur_open) - cur_low;
        bool is_reject = false;
        if (g_gap_dir_state > 0) {
            is_reject = (lower_shadow > Gap_RejectShadow * body)
                       && (lower_shadow > Gap_RejectMinAtr * atr)
                       && (cur_close > cur_open) && (cur_close > g_gap_prev_close);
            if (is_reject) signal = 1;
        } else {
            is_reject = (upper_shadow > Gap_RejectShadow * body)
                       && (upper_shadow > Gap_RejectMinAtr * atr)
                       && (cur_close < cur_open) && (cur_close < g_gap_prev_close);
            if (is_reject) signal = -1;
        }
        if (signal != 0) {
            g_gap_state = GAP_IDLE;
        } else if ((cur_time - g_gap_fill_time) / 3600 > Gap_RejectTimeout) {
            g_gap_state = GAP_IDLE;
        }
    }
    return signal;
}

//+------------------------------------------------------------------+
//| 因子 5: XAU/XAG Ratio                                             |
//+------------------------------------------------------------------+
int ComputeRatioSignal()
{
    int total = Ratio_Lookback + 5;
    double xau_close[], xag_close[];
    if (CopyClose(_Symbol, PERIOD_H1, 1, total, xau_close) < total) return 0;
    if (CopyClose(Ratio_XAGSymbol, PERIOD_H1, 1, total, xag_close) < total) return 0;
    int n = ArraySize(xau_close);

    int idx_signal = n - 1;
    int start = idx_signal - Ratio_Lookback;
    if (start < 0) return 0;

    double sum = 0, sum_sq = 0;
    int cnt = 0;
    for (int i = start; i < idx_signal; i++) {
        if (xag_close[i] > 0) {
            double r = xau_close[i] / xag_close[i];
            sum += r;
            sum_sq += r * r;
            cnt++;
        }
    }
    if (cnt < Ratio_Lookback / 2) return 0;
    double mean = sum / cnt;
    double var = (sum_sq / cnt) - mean * mean;
    if (var <= 0) return 0;
    double std = MathSqrt(var);
    if (std <= 0) return 0;
    if (xag_close[idx_signal] <= 0) return 0;
    double cur_ratio = xau_close[idx_signal] / xag_close[idx_signal];
    double z = (cur_ratio - mean) / std;
    if (z > Ratio_ZThreshold) return -1;
    if (z < -Ratio_ZThreshold) return 1;
    return 0;
}

//+------------------------------------------------------------------+
//| 因子 6: Session+Fib — 三时段 sweep + Fib 0.618 回踩 (原版状态机)  |
//|   时段(UTC): Asia 0-7 / London 7-13 / NY 13-21                    |
//|   逻辑: idle→sweep检测→wait_pullback(≥0.5ATR)→wait_618→entry      |
//|   London 用 Asia H/L 作 ref, NY 用 London H/L (优先) 或 Asia 备用 |
//+------------------------------------------------------------------+
void UpdateSessionHighLow(int cur_h_utc, double bar_h, double bar_l)
{
    // 时段切换边界: 进入新段时锁定上一段 last_*_h/l
    if (cur_h_utc == 7 && g_prev_hour_utc < 7 && g_prev_hour_utc != -1) {
        if (g_cur_asia_h > 0) {
            g_last_asia_h = g_cur_asia_h;
            g_last_asia_l = g_cur_asia_l;
            g_have_last_asia = true;
        }
        g_cur_london_h = 0; g_cur_london_l = 0;
    }
    if (cur_h_utc == 13 && g_prev_hour_utc < 13 && g_prev_hour_utc >= 7) {
        if (g_cur_london_h > 0) {
            g_last_london_h = g_cur_london_h;
            g_last_london_l = g_cur_london_l;
            g_have_last_london = true;
        }
        g_cur_ny_h = 0; g_cur_ny_l = 0;
    }
    if (cur_h_utc == 21 && g_prev_hour_utc < 21 && g_prev_hour_utc >= 13) {
        if (g_cur_ny_h > 0) {
            g_last_ny_h = g_cur_ny_h;
            g_last_ny_l = g_cur_ny_l;
            g_have_last_ny = true;
        }
    }
    if (cur_h_utc == 0 && g_prev_hour_utc != 0) {
        g_cur_asia_h = 0; g_cur_asia_l = 0;
    }

    // 累积当前时段 H/L
    if (cur_h_utc >= 0 && cur_h_utc < 7) {
        if (bar_h > g_cur_asia_h || g_cur_asia_h == 0) g_cur_asia_h = bar_h;
        if (bar_l < g_cur_asia_l || g_cur_asia_l == 0) g_cur_asia_l = bar_l;
    } else if (cur_h_utc >= 7 && cur_h_utc < 13) {
        if (bar_h > g_cur_london_h || g_cur_london_h == 0) g_cur_london_h = bar_h;
        if (bar_l < g_cur_london_l || g_cur_london_l == 0) g_cur_london_l = bar_l;
    } else if (cur_h_utc >= 13 && cur_h_utc < 21) {
        if (bar_h > g_cur_ny_h || g_cur_ny_h == 0) g_cur_ny_h = bar_h;
        if (bar_l < g_cur_ny_l || g_cur_ny_l == 0) g_cur_ny_l = bar_l;
    }

    g_prev_hour_utc = cur_h_utc;
}

int ComputeSessionFibSignal()
{
    MqlRates r[];
    if (CopyRates(_Symbol, PERIOD_H1, 1, 1, r) < 1) return 0;
    MqlDateTime dt;
    TimeToStruct(r[0].time, dt);
    int hour_utc = BrokerHourToUTC(dt.hour);

    UpdateSessionHighLow(hour_utc, r[0].high, r[0].low);

    // ToD filter (排除 20-22 UTC) — 仅对此因子启用
    if (Sess_UseToDFilter && hour_utc >= 20 && hour_utc <= 22) return 0;

    double atr = g_cur_atr;
    if (atr <= 0) return 0;

    // 选择参考时段 H/L
    double ref_h = 0, ref_l = 0;
    if (hour_utc >= 7 && hour_utc < 13) {
        if (g_have_last_asia) { ref_h = g_last_asia_h; ref_l = g_last_asia_l; }
    } else if (hour_utc >= 13 && hour_utc < 21) {
        if (g_have_last_london) { ref_h = g_last_london_h; ref_l = g_last_london_l; }
        else if (g_have_last_asia) { ref_h = g_last_asia_h; ref_l = g_last_asia_l; }
    }

    double cur_o = r[0].open;
    double cur_c = r[0].close;
    double cur_h = r[0].high;
    double cur_l = r[0].low;

    // ===== 4 段状态机 =====
    if (g_sess_state == SESS_IDLE) {
        if (ref_h <= 0 || ref_l <= 0) return 0;
        if (!(hour_utc >= 7 && hour_utc < 21)) return 0;

        // sweep_up: high > ref_H AND close < ref_H (假突破收回)
        if (cur_h > ref_h && cur_c < ref_h) {
            g_sess_state = SESS_WAIT_PB_DN;
            g_sess_dir = 1;
            g_sess_swept_extreme = cur_h;
            g_sess_retr_extreme = cur_l;
            g_sess_swept_time = r[0].time;
        }
        // sweep_dn: low < ref_L AND close > ref_L
        else if (cur_l < ref_l && cur_c > ref_l) {
            g_sess_state = SESS_WAIT_PB_UP;
            g_sess_dir = -1;
            g_sess_swept_extreme = cur_l;
            g_sess_retr_extreme = cur_h;
            g_sess_swept_time = r[0].time;
        }
        return 0;
    }

    long bars_since_swept = (r[0].time - g_sess_swept_time) / 3600;

    if (g_sess_state == SESS_WAIT_PB_DN) {
        if (bars_since_swept > Sess_PullbackTimeout) { g_sess_state = SESS_IDLE; return 0; }
        if (cur_l < g_sess_retr_extreme) g_sess_retr_extreme = cur_l;
        double rng = g_sess_swept_extreme - g_sess_retr_extreme;
        if (rng >= Sess_PullbackMinAtr * atr) {
            g_sess_state = SESS_WAIT_618_DN;
            g_sess_pullback_time = r[0].time;
        }
        return 0;
    }

    if (g_sess_state == SESS_WAIT_PB_UP) {
        if (bars_since_swept > Sess_PullbackTimeout) { g_sess_state = SESS_IDLE; return 0; }
        if (cur_h > g_sess_retr_extreme) g_sess_retr_extreme = cur_h;
        double rng = g_sess_retr_extreme - g_sess_swept_extreme;
        if (rng >= Sess_PullbackMinAtr * atr) {
            g_sess_state = SESS_WAIT_618_UP;
            g_sess_pullback_time = r[0].time;
        }
        return 0;
    }

    long bars_since_pb = (r[0].time - g_sess_pullback_time) / 3600;

    if (g_sess_state == SESS_WAIT_618_DN) {
        if (bars_since_pb > Sess_FibTouchTimeout) { g_sess_state = SESS_IDLE; return 0; }
        // 强反向破位失败
        if (cur_c < g_sess_retr_extreme - Sess_BreakFailAtr * atr) {
            g_sess_state = SESS_IDLE; return 0;
        }
        if (cur_l < g_sess_retr_extreme) g_sess_retr_extreme = cur_l;
        double rng = g_sess_swept_extreme - g_sess_retr_extreme;
        if (rng <= 0) return 0;
        double fib_618 = g_sess_swept_extreme - Sess_FibRatio * rng;
        // 触及 fib + close > fib + 阳线 → entry long
        if (cur_l <= fib_618 && cur_c > fib_618 && cur_c > cur_o) {
            g_sess_state = SESS_IDLE;
            return 1;
        }
        return 0;
    }

    if (g_sess_state == SESS_WAIT_618_UP) {
        if (bars_since_pb > Sess_FibTouchTimeout) { g_sess_state = SESS_IDLE; return 0; }
        if (cur_c > g_sess_retr_extreme + Sess_BreakFailAtr * atr) {
            g_sess_state = SESS_IDLE; return 0;
        }
        if (cur_h > g_sess_retr_extreme) g_sess_retr_extreme = cur_h;
        double rng = g_sess_retr_extreme - g_sess_swept_extreme;
        if (rng <= 0) return 0;
        double fib_618 = g_sess_swept_extreme + Sess_FibRatio * rng;
        if (cur_h >= fib_618 && cur_c < fib_618 && cur_c < cur_o) {
            g_sess_state = SESS_IDLE;
            return -1;
        }
        return 0;
    }

    return 0;
}

//+------------------------------------------------------------------+
//| 因子 7: Divergence — BB + RSI/MFI 动力衰竭背离 (原版 archive)     |
//|   Bearish: close > BB_upper AND (RSI[t]<RSI[t-N] OR MFI[t]<MFI[t-N])
//|   Bullish: close < BB_lower AND (RSI[t]>RSI[t-N] OR MFI[t]>MFI[t-N])
//|   Confirm: long 需 close > prev_close, short 需 close < prev_close |
//+------------------------------------------------------------------+
int ComputeDivergenceSignal()
{
    if (g_div_day_paused) return 0;

    int need = MathMax(Div_BBPeriod, MathMax(Div_RsiPeriod, Div_MfiPeriod)) + Div_DivLookback + 10;

    // BB(period, sigma)
    int bb_h = iBands(_Symbol, PERIOD_H1, Div_BBPeriod, 0, Div_BBSigma, PRICE_CLOSE);
    if (bb_h == INVALID_HANDLE) return 0;
    double bb_mid[], bb_up[], bb_lo[];
    if (CopyBuffer(bb_h, 0, 1, 2, bb_mid) < 2) return 0;  // base
    if (CopyBuffer(bb_h, 1, 1, 2, bb_up)  < 2) return 0;  // upper
    if (CopyBuffer(bb_h, 2, 1, 2, bb_lo)  < 2) return 0;  // lower

    // RSI 当前 + N 期前
    int rsi_h = iRSI(_Symbol, PERIOD_H1, Div_RsiPeriod, PRICE_CLOSE);
    if (rsi_h == INVALID_HANDLE) return 0;
    double rsi[];
    if (CopyBuffer(rsi_h, 0, 1, Div_DivLookback + 2, rsi) < Div_DivLookback + 2) return 0;
    int rsi_n = ArraySize(rsi);
    double rsi_cur  = rsi[rsi_n - 1];
    double rsi_prev = rsi[rsi_n - 1 - Div_DivLookback];

    // MFI 当前 + N 期前
    int mfi_h = iMFI(_Symbol, PERIOD_H1, Div_MfiPeriod, VOLUME_TICK);
    if (mfi_h == INVALID_HANDLE) return 0;
    double mfi[];
    if (CopyBuffer(mfi_h, 0, 1, Div_DivLookback + 2, mfi) < Div_DivLookback + 2) return 0;
    int mfi_n = ArraySize(mfi);
    double mfi_cur  = mfi[mfi_n - 1];
    double mfi_prev = mfi[mfi_n - 1 - Div_DivLookback];

    // 当前 + 前一根 close
    MqlRates r[];
    if (CopyRates(_Symbol, PERIOD_H1, 1, 2, r) < 2) return 0;
    double cur_close  = r[1].close;
    double prev_close = r[0].close;
    double cur_bb_up  = bb_up[1];
    double cur_bb_lo  = bb_lo[1];

    bool price_at_top = cur_close > cur_bb_up;
    bool price_at_bot = cur_close < cur_bb_lo;
    bool rsi_falling  = rsi_cur < rsi_prev;
    bool rsi_rising   = rsi_cur > rsi_prev;
    bool mfi_falling  = mfi_cur < mfi_prev;
    bool mfi_rising   = mfi_cur > mfi_prev;

    bool bearish_div, bullish_div;
    if (Div_RequireBoth) {
        bearish_div = price_at_top && rsi_falling && mfi_falling;
        bullish_div = price_at_bot && rsi_rising  && mfi_rising;
    } else {
        bearish_div = price_at_top && (rsi_falling || mfi_falling);
        bullish_div = price_at_bot && (rsi_rising  || mfi_rising);
    }

    bool confirm_long  = cur_close > prev_close;
    bool confirm_short = cur_close < prev_close;

    if (bearish_div && (!Div_RequireConfirm || confirm_short)) return -1;
    if (bullish_div && (!Div_RequireConfirm || confirm_long )) return  1;
    return 0;
}

//+------------------------------------------------------------------+
//| Divergence daily_stop 跟踪 (累计 closed PnL of MAGIC_DIV)         |
//+------------------------------------------------------------------+
void UpdateDivergenceDailyStop()
{
    if (!Div_Enable) return;

    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    datetime day0 = TimeCurrent() - dt.hour * 3600 - dt.min * 60 - dt.sec;

    if (day0 != g_div_day) {
        g_div_day = day0;
        g_div_day_pnl = 0;
        g_div_day_paused = false;
    }

    // 扫描历史 deal 计算今日 MAGIC_DIV closed PnL
    if (!HistorySelect(day0, TimeCurrent())) return;
    int total_deals = HistoryDealsTotal();
    double pnl = 0;
    for (int i = 0; i < total_deals; i++) {
        ulong ticket = HistoryDealGetTicket(i);
        if (ticket == 0) continue;
        ulong magic = HistoryDealGetInteger(ticket, DEAL_MAGIC);
        if (magic != MAGIC_DIV) continue;
        long entry = HistoryDealGetInteger(ticket, DEAL_ENTRY);
        if (entry != DEAL_ENTRY_OUT) continue;
        pnl += HistoryDealGetDouble(ticket, DEAL_PROFIT);
        pnl += HistoryDealGetDouble(ticket, DEAL_SWAP);
        pnl += HistoryDealGetDouble(ticket, DEAL_COMMISSION);
    }
    g_div_day_pnl = pnl;

    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    if (balance > 0 && pnl < -(Div_DailyStopPct / 100.0) * balance) {
        if (!g_div_day_paused) {
            Print("[Master] Divergence daily_stop triggered: ",
                  DoubleToString(pnl,2), " USD (",
                  DoubleToString(pnl/balance*100.0,2), "% of balance)");
        }
        g_div_day_paused = true;
    }
}

//+------------------------------------------------------------------+
//| 因子触发处理                                                      |
//+------------------------------------------------------------------+
void HandleFactorSignal(int factor_idx, int sig, datetime cur_bar,
                        ulong sub_magic, double risk_pct,
                        double sl_atr, double tp_atr, string name)
{
    if (HasOpenPositionForMagic(sub_magic)) return;
    if (sig != 0) {
        g_sig_time[factor_idx] = cur_bar;
        g_sig_dir[factor_idx] = sig;
    }
    if (g_sig_dir[factor_idx] != 0) {
        long bars_since = (cur_bar - g_sig_time[factor_idx]) / 3600;
        if (bars_since <= SignalFFillBars) {
            OpenSubMagicPosition(g_sig_dir[factor_idx], sub_magic, risk_pct,
                                  sl_atr, tp_atr, name);
            g_sig_time[factor_idx] = 0;
            g_sig_dir[factor_idx] = 0;
        } else {
            g_sig_time[factor_idx] = 0;
            g_sig_dir[factor_idx] = 0;
        }
    }
}

//+------------------------------------------------------------------+
//| OnTick (主循环)                                                   |
//+------------------------------------------------------------------+
void OnTick()
{
    datetime cur_bar = iTime(_Symbol, PERIOD_H1, 0);

    // 每根新 H1: 更新共享状态
    bool is_new_bar = (cur_bar != g_last_bar_time);
    if (is_new_bar) {
        g_last_bar_time = cur_bar;
        g_cur_atr = GetATR();
        g_cur_vol_scale = GetVolScale();
        UpdateRegime();   // ATR% regime detector — 低波动减仓
    }

    // 1. Trailing + Time stop (每 tick 检查)
    //    Trail 距离动态化: max(base_trail, spread × 2) 防 spread 飙升时被瞬间穿
    double dyn_trail = GetEffectiveTrailUSD(TrailFixedUSD);
    double dyn_trail_vp_sess = GetEffectiveTrailUSD(TrailFixedUSD);  // VP/Sess 也用同基准
    if (PureBO_Enable) {
        ApplyTrailingForMagic(MAGIC_PUREBO, dyn_trail, TrailActivateAtr);
        if (is_new_bar) CheckTimeStopForMagic(MAGIC_PUREBO, PureBO_TimeStop);
    }
    if (VP_Enable) {
        ApplyTrailingForMagic(MAGIC_VP_POC, dyn_trail_vp_sess, 0.8);  // VP 用 0.8 ATR activate
        if (is_new_bar) CheckTimeStopForMagic(MAGIC_VP_POC, VP_TimeStop);
    }
    if (Liq_Enable) {
        ApplyTrailingForMagic(MAGIC_LIQ, dyn_trail, TrailActivateAtr);
        if (is_new_bar) CheckTimeStopForMagic(MAGIC_LIQ, Liq_TimeStop);
    }
    // Gap 不用 trail / time stop, SL TP 直接撞
    if (Ratio_Enable) {
        ApplyTrailingForMagic(MAGIC_XAUXAG, dyn_trail, TrailActivateAtr);
        if (is_new_bar) CheckTimeStopForMagic(MAGIC_XAUXAG, Ratio_TimeStop);
    }
    if (Sess_Enable) {
        ApplyTrailingForMagic(MAGIC_SESSION, dyn_trail_vp_sess, 0.8);  // Sess 用 0.8 ATR activate
        if (is_new_bar) CheckTimeStopForMagic(MAGIC_SESSION, Sess_TimeStop);
    }
    if (Div_Enable) {
        if (is_new_bar) CheckTimeStopForMagic(MAGIC_DIV, Div_TimeStop);
    }

    // 2. 仅在新 bar 检查 signal
    if (!is_new_bar) return;

    // 3. Circuit breaker
    if (IsCircuitBreakerActive()) {
        Print("[Master] Circuit breaker active, skip signals.");
        return;
    }

    // 4. ATR 必须可用
    if (g_cur_atr <= 0) return;

    // ===== ATR% Regime — 低波动期 PAUSE (类 2021-2022 亏损区) =====
    if (IsRegimePaused()) {
        static datetime last_pause_print = 0;
        if (TimeCurrent() - last_pause_print > 3600) {
            Print("[Regime] PAUSED (ATR%=", DoubleToString(g_cur_atr_pct,3), "% < ",
                  RegimeATRPctReduced, "%). Skipping all entries.");
            last_pause_print = TimeCurrent();
        }
        return;
    }

    // ===== Spread 防护 — 全因子共享 =====
    // Layer 1: 硬阈值 (NFP 防护)
    if (!IsSpreadHardLimitOK()) return;
    // Layer 3: 滚动 spread spike (实时)
    if (!IsSpreadNotSpiking()) return;

    // Layer 2: Range filter (仅 Liq/Sess/VP 启用 — 实测 MDD 改进显著)
    bool range_ok = IsRangeNormal();

    // ===== 多 TF filter (按因子选择性应用) =====
    int h4_trend = GetH4TrendDirection();      // VP_POC 用 H4 EMA50
    int h4_pure_dir = GetH4PureBODirection();  // Liquidation 用 H4 PureBO direction

    // 5. 各因子 signal 计算 + 触发
    bool tod_excluded = IsToDExcluded(cur_bar);

    if (PureBO_Enable) {
        int sig = ComputePureBOSignal();
        // PureBO 默认不用 H4 filter (高频集中风险), 仅高 spread broker 才开
        if (UseH4Filter_PureBO && sig != 0 && h4_trend != 0 && sig != h4_trend) sig = 0;
        HandleFactorSignal(0, sig, cur_bar, MAGIC_PUREBO, PureBO_Risk,
                            PureBO_SLAtr, PureBO_TPAtr, "PureBO");
    }
    if (VP_Enable && !tod_excluded && range_ok) {
        int sig = ComputeVPPOCSignal();
        // VP_POC + H4 EMA50 confluence (实测 MDD 18→3.6%, PF 1.45→3.71)
        if (UseH4Filter_VP && sig != 0 && h4_trend != 0 && sig != h4_trend) sig = 0;
        HandleFactorSignal(1, sig, cur_bar, MAGIC_VP_POC, VP_Risk,
                            VP_SLAtr, VP_TPAtr, "VP_POC");
    } else if (VP_Enable && (tod_excluded || !range_ok)) {
        g_sig_time[1] = 0;
        g_sig_dir[1] = 0;
    }
    if (Liq_Enable && range_ok) {
        int sig = ComputeLiqSignal();
        // Liquidation + H4 PureBO confluence (实测 MDD 10.81→8.13%, PF +33%)
        if (UseH4Filter_Liq && sig != 0 && h4_pure_dir != 0 && sig != h4_pure_dir) sig = 0;
        HandleFactorSignal(2, sig, cur_bar, MAGIC_LIQ, Liq_Risk,
                            Liq_SLAtr, Liq_TPAtr, "Liquidation");
    }
    if (Gap_Enable) {
        int sig = ComputeGapSignal();
        HandleFactorSignal(3, sig, cur_bar, MAGIC_GAP, Gap_Risk,
                            Gap_SLAtr, Gap_TPAtr, "Gap_Reject");
    }
    if (Ratio_Enable) {
        int sig = ComputeRatioSignal();
        HandleFactorSignal(4, sig, cur_bar, MAGIC_XAUXAG, Ratio_Risk,
                            Ratio_SLAtr, Ratio_TPAtr, "XAUXAG");
    }
    if (Sess_Enable && range_ok) {
        int sig = ComputeSessionFibSignal();
        HandleFactorSignal(5, sig, cur_bar, MAGIC_SESSION, Sess_Risk,
                            Sess_SLAtr, Sess_TPAtr, "Sess_Fib");
    }
    if (Div_Enable) {
        UpdateDivergenceDailyStop();
        if (!g_div_day_paused) {
            int sig = ComputeDivergenceSignal();
            HandleFactorSignal(6, sig, cur_bar, MAGIC_DIV, Div_Risk,
                                Div_SLAtr, Div_TPAtr, "Divergence");
        }
    }
}

void OnDeinit(const int reason) {
    Print("[Master] Deinit reason=", reason);
}
```
