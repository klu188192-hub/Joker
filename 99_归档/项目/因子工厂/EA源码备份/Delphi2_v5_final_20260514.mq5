//+------------------------------------------------------------------+
//|                                       Delphi2_Aggressive_v1.mq5  |
//|        Joker Factor Factory v20260514 — Trend Following Day      |
//|        仿 Striker Delphi II ER Aggressive (无源码, 仿其形态)      |
//|        核心: Adaptive Donchian + Chandelier + Day-Trading         |
//|        XAU H1, Aggressive 频率 (BaseDonchian 12 vs Conservative 24)|
//+------------------------------------------------------------------+
#property copyright "Joker Factor Factory v20260514"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>
CTrade trade;

input group "=== Adaptive Donchian (Delphi-II 仿) ==="
input int    BaseDonchian   = 12;
input int    AtrPeriod      = 14;
input int    AtrLookback    = 100;
input double AdaptK         = 0.0;    // 诊断阶段固定周期 (不自适应)
input double AtrFloorMult   = 0.0;    // 诊断阶段关 ATR floor
input bool   UseBuffer      = false;  // 诊断阶段关 buffer
input double BufferAtr      = 0.10;

input group "=== SL / TP ==="
input double SLAtrMult      = 1.50;
input double TPAtrMult      = 5.00;
input double RiskPctEquity  = 1.00;   // v5 实测最优 default

input group "=== 出场多阶段 (Multi-Stage Exit) ==="
input bool   UseBreakeven   = true;   // R ≥ BreakevenR 时 SL 移到入场价
input double BreakevenR     = 1.00;   // 1R 锁本
input bool   UseChandelier  = true;   // R ≥ TrailDelayR 时启动 trail
input double TrailDelayR    = 2.00;   // 2R 后才 trail
input double TrailAtrMult   = 2.50;   // trail 距离

input group "=== Pyramiding + Partial Close (v4) ==="
input bool   UsePyramid     = true;   // v6e: 实测保留 pyramid 反而 PF 更优
input double PyramidR       = 1.50;
input int    MaxPyramid     = 3;      // 最多总持仓数 (含初始)
input double PyramidLotMult = 0.7;    // 加仓 lot = 上一笔 × 此 (减仓加法)
input bool   UsePartial     = true;   // R≥PartialR1 平 % / R≥PartialR2 再平
input double PartialR1      = 1.00;
input double PartialPct1    = 0.50;   // 平 50%
input double PartialR2      = 3.00;
input double PartialPct2    = 0.50;   // 平剩余 50% 的 50% = 总仓 25%

input group "=== HMM Regime Filter (v5) ==="
input bool   UseRegimeFilter = true;
input string RegimeCsvFile  = "regime.csv";

input group "=== Regime Filter (v3) ==="
input bool   UseADXFilter   = true;   // ADX > min 才入场 (砍震荡市)
input int    ADXPeriod      = 14;
input double ADXMinValue    = 20.0;
input bool   UseH4Trend     = true;   // H4 close vs EMA50 同向才入场
input int    H4EmaPeriod    = 50;

input group "=== 时间 / 频率 ==="
input bool   UseSession       = true;   // v3 恢复 session 过滤
input int    SessionStartHour = 8;
input int    SessionEndHour   = 20;
input int    DayCloseHour     = 23;
input int    MaxTradesPerDay  = 4;
input int    MinBarsBetween   = 2;

input group "=== 系统 ==="
input ulong  Magic            = 57201;
input string CommentTag       = "Delphi2_Agg";
input bool   Debug            = true;   // 诊断阶段默认开

int atr_handle = INVALID_HANDLE;
int adx_handle = INVALID_HANDLE;
int h4_ema_handle = INVALID_HANDLE;
datetime g_last_bar = 0;

// HMM regime data
long g_regime_epoch[];
int  g_regime_allow[];
int  g_regime_n = 0;
datetime g_last_entry_bar = 0;
int g_today_trades = 0;
datetime g_today_start = 0;
double g_chandelier_high = 0;
double g_chandelier_low = 0;

//+------------------------------------------------------------------+
int g_tick_count = 0;
int g_bar_count = 0;
int g_sig_buy = 0;
int g_sig_sell = 0;
int g_send_ok = 0;
int g_send_fail = 0;

// 出场状态: 多仓时每个 ticket 独立 ctx
struct PosCtx {
   ulong   ticket;
   double  entry;
   double  sl_dist;       // 原始 SL 距离 (不变)
   double  init_lot;      // 原始 lot
   bool    be_done;
   bool    trail_done;
   bool    partial1_done;
   bool    partial2_done;
   int     level;         // 1=初始, 2=pyramid1, 3=pyramid2 ...
   long    type;          // POSITION_TYPE_BUY/SELL
};
PosCtx g_pos[];
int g_pos_count = 0;

// 旧单仓全局变量 (兼容 trail chandelier)
double g_entry_price = 0;
double g_entry_sl0   = 0;
double g_sl_dist     = 0;
bool   g_be_done     = false;
bool   g_trail_done  = false;

int OnInit() {
   trade.SetExpertMagicNumber(Magic);
   trade.SetTypeFillingBySymbol(_Symbol);
   atr_handle = iATR(_Symbol, PERIOD_CURRENT, AtrPeriod);
   if (atr_handle == INVALID_HANDLE) { Print("[INIT] FAIL atr_handle"); return INIT_FAILED; }
   adx_handle = iADX(_Symbol, PERIOD_CURRENT, ADXPeriod);
   if (adx_handle == INVALID_HANDLE) { Print("[INIT] FAIL adx_handle"); return INIT_FAILED; }
   h4_ema_handle = iMA(_Symbol, PERIOD_H4, H4EmaPeriod, 0, MODE_EMA, PRICE_CLOSE);
   if (h4_ema_handle == INVALID_HANDLE) { Print("[INIT] FAIL h4_ema_handle"); return INIT_FAILED; }
   PrintFormat("[INIT] OK symbol=%s digits=%d minlot=%.2f tick_size=%.5f tick_val=%.5f base=%d adaptK=%.2f sl=%.2f tp=%.2f trail=%.2f session=%d",
      _Symbol, _Digits,
      SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN),
      SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE),
      SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE),
      BaseDonchian, AdaptK, SLAtrMult, TPAtrMult, TrailAtrMult, UseSession);

   // Load HMM regime CSV
   if (UseRegimeFilter) {
      PrintFormat("[PATH] TERMINAL_DATA_PATH=%s", TerminalInfoString(TERMINAL_DATA_PATH));
      PrintFormat("[PATH] TERMINAL_COMMONDATA_PATH=%s", TerminalInfoString(TERMINAL_COMMONDATA_PATH));
      LoadRegimeCSV();
   }
   return INIT_SUCCEEDED;
}

void LoadRegimeCSV() {
   int fh = FileOpen(RegimeCsvFile, FILE_READ|FILE_CSV|FILE_ANSI|FILE_COMMON, ',');
   if (fh == INVALID_HANDLE) {
      PrintFormat("[REGIME] load fail err=%d (try sandbox)", GetLastError());
      // 兜底: 尝试 sandbox 路径
      fh = FileOpen(RegimeCsvFile, FILE_READ|FILE_CSV|FILE_ANSI, ',');
      if (fh == INVALID_HANDLE) {
         PrintFormat("[REGIME] load fail err=%d (sandbox)", GetLastError());
         return;
      }
   }
   ArrayResize(g_regime_epoch, 12000);
   ArrayResize(g_regime_allow, 12000);
   g_regime_n = 0;
   while (!FileIsEnding(fh)) {
      long ep = (long)FileReadNumber(fh);
      int st = (int)FileReadNumber(fh);
      int al = (int)FileReadNumber(fh);
      if (ep > 0 && g_regime_n < 12000) {
         g_regime_epoch[g_regime_n] = ep;
         g_regime_allow[g_regime_n] = al;
         g_regime_n++;
      }
   }
   FileClose(fh);
   ArrayResize(g_regime_epoch, g_regime_n);
   ArrayResize(g_regime_allow, g_regime_n);
   if (g_regime_n > 0) {
      PrintFormat("[REGIME] loaded %d rows, allow=%d (%.1f%%) first_ep=%d last_ep=%d",
         g_regime_n,
         g_regime_n - ArrayCount0(g_regime_allow, g_regime_n),
         100.0 * (g_regime_n - ArrayCount0(g_regime_allow, g_regime_n)) / g_regime_n,
         (int)g_regime_epoch[0], (int)g_regime_epoch[g_regime_n-1]);
   } else {
      Print("[REGIME] 0 rows loaded");
   }
}

int ArrayCount0(int &arr[], int n) {
   int c = 0;
   for (int i = 0; i < n; i++) if (arr[i] == 0) c++;
   return c;
}

bool RegimeAllow(datetime bar_time) {
   if (!UseRegimeFilter || g_regime_n == 0) return true;
   long ep = (long)bar_time;
   int lo = 0, hi = g_regime_n - 1, mid;
   while (lo < hi) {
      mid = (lo + hi + 1) / 2;
      if (g_regime_epoch[mid] <= ep) lo = mid;
      else hi = mid - 1;
   }
   if (MathAbs(g_regime_epoch[lo] - ep) > 7200) return true;  // 容差 2h (DST)
   return (g_regime_allow[lo] == 1);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   PrintFormat("[STATS] ticks=%d bars=%d buy_sig=%d sell_sig=%d send_ok=%d send_fail=%d reason=%d",
      g_tick_count, g_bar_count, g_sig_buy, g_sig_sell, g_send_ok, g_send_fail, reason);
   if (MQLInfoInteger(MQL_TESTER)) PrintMetrics();
}

double OnTester() {
   string fname = "Delphi2_v42_deals.csv";
   int fh = FileOpen(fname, FILE_WRITE|FILE_CSV|FILE_ANSI, ',');
   if (fh == INVALID_HANDLE) {
      PrintFormat("[CSV] open fail err=%d", GetLastError());
      return TesterStatistics(STAT_PROFIT);
   }
   FileWrite(fh, "deal_ticket","time_iso","type","entry","price","volume","profit","pos_id","comment");
   HistorySelect(0, TimeCurrent());
   int n = HistoryDealsTotal();
   int dumped = 0;
   for (int i = 0; i < n; i++) {
      ulong tk = HistoryDealGetTicket(i);
      if (HistoryDealGetInteger(tk, DEAL_MAGIC) != (long)Magic) continue;
      datetime t = (datetime)HistoryDealGetInteger(tk, DEAL_TIME);
      ENUM_DEAL_TYPE dt = (ENUM_DEAL_TYPE)HistoryDealGetInteger(tk, DEAL_TYPE);
      ENUM_DEAL_ENTRY de = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(tk, DEAL_ENTRY);
      string dt_str = (dt == DEAL_TYPE_BUY) ? "buy" : (dt == DEAL_TYPE_SELL) ? "sell" : "x";
      string de_str = (de == DEAL_ENTRY_IN) ? "in" : (de == DEAL_ENTRY_OUT) ? "out" : (de == DEAL_ENTRY_INOUT) ? "inout" : "x";
      double price = HistoryDealGetDouble(tk, DEAL_PRICE);
      double vol = HistoryDealGetDouble(tk, DEAL_VOLUME);
      double profit = HistoryDealGetDouble(tk, DEAL_PROFIT)
                    + HistoryDealGetDouble(tk, DEAL_SWAP)
                    + HistoryDealGetDouble(tk, DEAL_COMMISSION);
      long pos_id = (long)HistoryDealGetInteger(tk, DEAL_POSITION_ID);
      string cmt = HistoryDealGetString(tk, DEAL_COMMENT);
      FileWrite(fh, (long)tk, TimeToString(t, TIME_DATE|TIME_SECONDS), dt_str, de_str,
                DoubleToString(price, _Digits), DoubleToString(vol, 2),
                DoubleToString(profit, 2), pos_id, cmt);
      dumped++;
   }
   FileClose(fh);
   PrintFormat("[CSV] dumped %d deals to %s", dumped, fname);

   // 同时 dump XAU H1 OHLCV (覆盖 2024-2026 测试期, 给 HMM 用)
   string fn2 = "XAUUSD_H1_ohlcv.csv";
   int fh2 = FileOpen(fn2, FILE_WRITE|FILE_CSV|FILE_ANSI, ',');
   if (fh2 != INVALID_HANDLE) {
      FileWrite(fh2, "time","open","high","low","close","tick_volume","atr14");
      MqlRates rates[];
      int rn = CopyRates(_Symbol, PERIOD_H1, 0, 20000, rates);
      double atr_arr[];
      CopyBuffer(atr_handle, 0, 0, rn, atr_arr);
      ArraySetAsSeries(rates, false);
      ArraySetAsSeries(atr_arr, false);
      for (int i = 0; i < rn; i++) {
         double a = (i < ArraySize(atr_arr)) ? atr_arr[i] : 0;
         FileWrite(fh2, TimeToString(rates[i].time, TIME_DATE|TIME_SECONDS),
                   DoubleToString(rates[i].open, _Digits),
                   DoubleToString(rates[i].high, _Digits),
                   DoubleToString(rates[i].low, _Digits),
                   DoubleToString(rates[i].close, _Digits),
                   (long)rates[i].tick_volume,
                   DoubleToString(a, _Digits));
      }
      FileClose(fh2);
      PrintFormat("[CSV] dumped %d H1 bars to %s", rn, fn2);
   }

   return TesterStatistics(STAT_PROFIT);
}

void PrintMetrics() {
   double profit = 0, gp = 0, gl = 0;
   int trades = 0, wins = 0;
   HistorySelect(0, TimeCurrent());
   int n = HistoryDealsTotal();
   for (int i = 0; i < n; i++) {
      ulong tk = HistoryDealGetTicket(i);
      if (HistoryDealGetInteger(tk, DEAL_MAGIC) != (long)Magic) continue;
      if (HistoryDealGetInteger(tk, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;
      double p = HistoryDealGetDouble(tk, DEAL_PROFIT)
               + HistoryDealGetDouble(tk, DEAL_SWAP)
               + HistoryDealGetDouble(tk, DEAL_COMMISSION);
      profit += p; trades++;
      if (p > 0) { gp += p; wins++; } else { gl += -p; }
   }
   double pf = (gl > 0) ? gp / gl : (gp > 0 ? 999.0 : 0.0);
   double wr = (trades > 0) ? 100.0 * wins / trades : 0.0;
   double mdd_pct = TesterStatistics(STAT_BALANCE_DDREL_PERCENT);
   double mdd_abs = TesterStatistics(STAT_BALANCE_DD);
   double sharpe  = TesterStatistics(STAT_SHARPE_RATIO);
   PrintFormat("[METRIC] base=%d adaptK=%.2f sl=%.2f tp=%.2f trail=%.2f risk=%.2f maxday=%d profit=%.2f mdd_pct=%.2f mdd_abs=%.2f pf=%.3f n=%d wr=%.1f sharpe=%.2f",
      BaseDonchian, AdaptK, SLAtrMult, TPAtrMult, TrailAtrMult, RiskPctEquity, MaxTradesPerDay,
      profit, mdd_pct, mdd_abs, pf, trades, wr, sharpe);
}

//+------------------------------------------------------------------+
bool NewBar() {
   datetime t = iTime(_Symbol, PERIOD_CURRENT, 0);
   if (t == g_last_bar) return false;
   g_last_bar = t;
   return true;
}

void ResetDayCounter() {
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   tm.hour = 0; tm.min = 0; tm.sec = 0;
   datetime today = StructToTime(tm);
   if (today != g_today_start) {
      g_today_start = today;
      g_today_trades = 0;
   }
}

bool InSession() {
   if (!UseSession) return true;
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   if (tm.day_of_week == 0 || tm.day_of_week == 6) return false;
   return (tm.hour >= SessionStartHour && tm.hour < SessionEndHour);
}

bool ShouldForceClose() {
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   return (tm.hour >= DayCloseHour);
}

void CloseAllMagic() {
   for (int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong tk = PositionGetTicket(i);
      if (PositionSelectByTicket(tk) && PositionGetInteger(POSITION_MAGIC) == (long)Magic) {
         trade.PositionClose(tk);
      }
   }
}

bool HasOpenPos() {
   for (int i = 0; i < PositionsTotal(); i++) {
      ulong tk = PositionGetTicket(i);
      if (PositionSelectByTicket(tk) && PositionGetInteger(POSITION_MAGIC) == (long)Magic) return true;
   }
   return false;
}

//+------------------------------------------------------------------+
double GetMedianAtr(int lookback) {
   double buf[];
   if (CopyBuffer(atr_handle, 0, 1, lookback, buf) < lookback) return 0;
   double tmp[];
   ArrayResize(tmp, lookback);
   for (int i = 0; i < lookback; i++) tmp[i] = buf[i];
   ArraySort(tmp);
   return tmp[lookback / 2];
}

int AdaptivePeriod(double atr_z) {
   int p = (int)MathRound(BaseDonchian * (1.0 + AdaptK * atr_z));
   if (p < 5) p = 5;
   int cap = BaseDonchian * 3;
   if (p > cap) p = cap;
   return p;
}

double CalcLot(double sl_distance) {
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   double risk_cash = eq * RiskPctEquity / 100.0;
   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tick_val  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if (tick_size <= 0 || tick_val <= 0 || sl_distance <= 0) return 0.01;
   double lot = risk_cash / (sl_distance / tick_size * tick_val);
   double minlot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxlot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lot = MathFloor(lot / step) * step;
   if (lot < minlot) lot = minlot;
   if (lot > maxlot) lot = maxlot;
   return lot;
}

int FindCtxIdx(ulong tk) {
   for (int i = 0; i < g_pos_count; i++) if (g_pos[i].ticket == tk) return i;
   return -1;
}

void SyncCtx() {
   // 移除已平仓位的 ctx (ticket 在当前 PositionsTotal 找不到)
   for (int i = g_pos_count - 1; i >= 0; i--) {
      bool found = false;
      for (int j = 0; j < PositionsTotal(); j++) {
         ulong tk = PositionGetTicket(j);
         if (tk == g_pos[i].ticket) { found = true; break; }
      }
      if (!found) {
         for (int k = i; k < g_pos_count - 1; k++) g_pos[k] = g_pos[k+1];
         g_pos_count--;
      }
   }
}

int CountMagicPositions(long target_type) {
   int n = 0;
   for (int i = 0; i < PositionsTotal(); i++) {
      ulong tk = PositionGetTicket(i);
      if (!PositionSelectByTicket(tk)) continue;
      if (PositionGetInteger(POSITION_MAGIC) != (long)Magic) continue;
      if (target_type < 0 || PositionGetInteger(POSITION_TYPE) == target_type) n++;
   }
   return n;
}

void ManageExit(double atr) {
   SyncCtx();
   for (int i = 0; i < PositionsTotal(); i++) {
      ulong tk = PositionGetTicket(i);
      if (!PositionSelectByTicket(tk)) continue;
      if (PositionGetInteger(POSITION_MAGIC) != (long)Magic) continue;
      long type    = PositionGetInteger(POSITION_TYPE);
      double tp    = PositionGetDouble(POSITION_TP);
      double cur_sl= PositionGetDouble(POSITION_SL);
      double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      int idx = FindCtxIdx(tk);
      if (idx < 0) continue;
      double entry   = g_pos[idx].entry;
      double sl_dist = g_pos[idx].sl_dist;
      if (sl_dist <= 0) continue;

      double r = (type == POSITION_TYPE_BUY) ? (bid - entry) / sl_dist : (entry - ask) / sl_dist;

      // === Partial Close 1: R ≥ PartialR1 平 PartialPct1 ===
      if (UsePartial && !g_pos[idx].partial1_done && r >= PartialR1) {
         double cur_vol = PositionGetDouble(POSITION_VOLUME);
         double close_vol = NormalizeDouble(cur_vol * PartialPct1, 2);
         double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
         close_vol = MathFloor(close_vol / step) * step;
         if (close_vol >= SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN)) {
            if (trade.PositionClosePartial(tk, close_vol)) {
               g_pos[idx].partial1_done = true;
               if (Debug) PrintFormat("[PARTIAL1] tk=%d vol=%.2f@R=%.2f", tk, close_vol, r);
            }
         } else {
            g_pos[idx].partial1_done = true;  // lot 太小, skip
         }
      }

      // === Partial Close 2: R ≥ PartialR2 平 PartialPct2 ===
      if (UsePartial && g_pos[idx].partial1_done && !g_pos[idx].partial2_done && r >= PartialR2) {
         double cur_vol = PositionGetDouble(POSITION_VOLUME);
         double close_vol = NormalizeDouble(cur_vol * PartialPct2, 2);
         double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
         close_vol = MathFloor(close_vol / step) * step;
         if (close_vol >= SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN)) {
            if (trade.PositionClosePartial(tk, close_vol)) {
               g_pos[idx].partial2_done = true;
               if (Debug) PrintFormat("[PARTIAL2] tk=%d vol=%.2f@R=%.2f", tk, close_vol, r);
            }
         } else {
            g_pos[idx].partial2_done = true;
         }
      }

      // === Stage 1: Breakeven ===
      if (UseBreakeven && !g_pos[idx].be_done && r >= BreakevenR) {
         double be_sl = entry;
         if (type == POSITION_TYPE_BUY  && be_sl > cur_sl && be_sl < bid) {
            trade.PositionModify(tk, NormalizeDouble(be_sl, _Digits), tp);
            g_pos[idx].be_done = true;
         } else if (type == POSITION_TYPE_SELL && (cur_sl == 0 || be_sl < cur_sl) && be_sl > ask) {
            trade.PositionModify(tk, NormalizeDouble(be_sl, _Digits), tp);
            g_pos[idx].be_done = true;
         }
      }

      // === Stage 2: Chandelier trail (R ≥ TrailDelayR 后启动) ===
      if (UseChandelier && r >= TrailDelayR) {
         if (type == POSITION_TYPE_BUY) {
            if (bid > g_chandelier_high) g_chandelier_high = bid;
            double new_sl = g_chandelier_high - TrailAtrMult * atr;
            if (new_sl > cur_sl && new_sl < bid) {
               trade.PositionModify(tk, NormalizeDouble(new_sl, _Digits), tp);
               g_pos[idx].trail_done = true;
            }
         } else if (type == POSITION_TYPE_SELL) {
            if (g_chandelier_low == 0 || ask < g_chandelier_low) g_chandelier_low = ask;
            double new_sl = g_chandelier_low + TrailAtrMult * atr;
            if ((cur_sl == 0 || new_sl < cur_sl) && new_sl > ask) {
               trade.PositionModify(tk, NormalizeDouble(new_sl, _Digits), tp);
               g_pos[idx].trail_done = true;
            }
         }
      }
   }
}

// Pyramiding: 同向加仓
void TryPyramid(double atr_t1) {
   if (!UsePyramid) return;
   if (g_pos_count == 0) return;
   if (g_pos_count >= MaxPyramid) return;

   // 找当前主仓 (level 1)
   int main_idx = -1;
   for (int i = 0; i < g_pos_count; i++) if (g_pos[i].level == 1) { main_idx = i; break; }
   if (main_idx < 0) return;

   // 上次加仓时间 ≥ MinBarsBetween (复用)
   datetime last_entry_time = 0;
   for (int i = 0; i < g_pos_count; i++) {
      if (PositionSelectByTicket(g_pos[i].ticket)) {
         datetime t = (datetime)PositionGetInteger(POSITION_TIME);
         if (t > last_entry_time) last_entry_time = t;
      }
   }
   if (last_entry_time != 0) {
      int shift = iBarShift(_Symbol, PERIOD_CURRENT, last_entry_time);
      if (shift < MinBarsBetween) return;
   }

   // 主仓 R ≥ PyramidR
   long type = g_pos[main_idx].type;
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double r = (type == POSITION_TYPE_BUY) ? (bid - g_pos[main_idx].entry) / g_pos[main_idx].sl_dist
                                          : (g_pos[main_idx].entry - ask) / g_pos[main_idx].sl_dist;
   if (r < PyramidR) return;

   // 加仓
   double new_lot = g_pos[main_idx].init_lot * MathPow(PyramidLotMult, g_pos_count);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   new_lot = MathFloor(new_lot / step) * step;
   double minlot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   if (new_lot < minlot) return;

   double entry = (type == POSITION_TYPE_BUY) ? ask : bid;
   double sl    = (type == POSITION_TYPE_BUY) ? entry - SLAtrMult * atr_t1 : entry + SLAtrMult * atr_t1;
   double tp    = (type == POSITION_TYPE_BUY) ? entry + TPAtrMult * atr_t1 : entry - TPAtrMult * atr_t1;
   double sl_dist = MathAbs(entry - sl);

   bool ok = false;
   if (type == POSITION_TYPE_BUY) ok = trade.Buy(new_lot, _Symbol, entry, NormalizeDouble(sl, _Digits), NormalizeDouble(tp, _Digits), "Delphi2_Pyr");
   else                           ok = trade.Sell(new_lot, _Symbol, entry, NormalizeDouble(sl, _Digits), NormalizeDouble(tp, _Digits), "Delphi2_Pyr");

   if (ok) {
      ArrayResize(g_pos, g_pos_count + 1);
      g_pos[g_pos_count].ticket = trade.ResultDeal();
      g_pos[g_pos_count].entry  = entry;
      g_pos[g_pos_count].sl_dist= sl_dist;
      g_pos[g_pos_count].init_lot = new_lot;
      g_pos[g_pos_count].be_done = false;
      g_pos[g_pos_count].trail_done = false;
      g_pos[g_pos_count].partial1_done = false;
      g_pos[g_pos_count].partial2_done = false;
      g_pos[g_pos_count].level  = g_pos_count + 1;
      g_pos[g_pos_count].type   = type;
      g_pos_count++;
      if (Debug) PrintFormat("[PYRAMID] level=%d lot=%.2f entry=%.2f R_main=%.2f", g_pos_count, new_lot, entry, r);
   }
}

//+------------------------------------------------------------------+
void OnTick() {
   g_tick_count++;
   double atr_arr[];
   if (CopyBuffer(atr_handle, 0, 0, 2, atr_arr) < 2) return;
   double atr_now = atr_arr[0];

   if (ShouldForceClose() && HasOpenPos()) {
      CloseAllMagic();
      return;
   }
   ManageExit(atr_now);

   // 持仓清空后重置 entry 上下文
   if (g_entry_price != 0 && !HasOpenPos()) {
      g_entry_price = 0;
      g_sl_dist = 0;
      g_be_done = false;
      g_trail_done = false;
      g_chandelier_high = 0;
      g_chandelier_low = 0;
   }

   if (!NewBar()) return;
   g_bar_count++;
   ResetDayCounter();

   if (!InSession())                          { if (Debug) Print("[REJ] session"); return; }

   // v5: HMM regime filter (bar[1] time → state)
   if (UseRegimeFilter) {
      datetime bar1_t = iTime(_Symbol, PERIOD_CURRENT, 1);
      if (!RegimeAllow(bar1_t)) {
         if (Debug) PrintFormat("[REJ] regime t=%s", TimeToString(bar1_t, TIME_DATE|TIME_SECONDS));
         return;
      }
   }

   // v4: 有仓位 → 尝试 pyramid 加仓 (在 HasOpenPos return 之前)
   if (UsePyramid && HasOpenPos()) {
      double atr_for_pyr[];
      if (CopyBuffer(atr_handle, 0, 1, 1, atr_for_pyr) >= 1) {
         TryPyramid(atr_for_pyr[0]);
      }
   }

   if (HasOpenPos())                          { if (Debug) Print("[REJ] has_pos"); return; }
   if (g_today_trades >= MaxTradesPerDay)     { if (Debug) Print("[REJ] day_max"); return; }
   if (g_last_entry_bar != 0) {
      int shift = iBarShift(_Symbol, PERIOD_CURRENT, g_last_entry_bar);
      if (shift < MinBarsBetween)             { if (Debug) Print("[REJ] cooldown"); return; }
   }

   // ATR z-score (用 bar[1] 数据避 lookahead)
   double atr_hist[];
   if (CopyBuffer(atr_handle, 0, 1, AtrLookback, atr_hist) < AtrLookback) { if (Debug) Print("[REJ] atr_buf"); return; }
   double sum = 0;
   for (int i = 0; i < AtrLookback; i++) sum += atr_hist[i];
   double mean = sum / AtrLookback;
   double sq = 0;
   for (int i = 0; i < AtrLookback; i++) sq += MathPow(atr_hist[i] - mean, 2);
   double std = MathSqrt(sq / AtrLookback);
   double atr_t1 = atr_hist[0];   // 最新已收盘 ATR
   double atr_z = (std > 0) ? (atr_t1 - mean) / std : 0;

   // ATR 下限过滤
   double median_atr = GetMedianAtr(AtrLookback);
   if (median_atr > 0 && atr_t1 < median_atr * AtrFloorMult) {
      if (Debug) PrintFormat("[REJ] atr_floor atr=%.2f median=%.2f", atr_t1, median_atr);
      return;
   }

   // 自适应周期
   int p = AdaptivePeriod(atr_z);

   // Donchian: bar[1] 的 close 突破过去 p 根 (bar[2..p+1]) 的 high/low
   // 不能包含 bar[1] 自己 (否则 high[1] >= close[1], buy_sig 永远 false)
   double high_buf[], low_buf[], close_buf[];
   if (CopyHigh(_Symbol, PERIOD_CURRENT, 2, p, high_buf) < p) { if (Debug) Print("[REJ] high_buf"); return; }
   if (CopyLow(_Symbol,  PERIOD_CURRENT, 2, p, low_buf)  < p) { if (Debug) Print("[REJ] low_buf"); return; }
   if (CopyClose(_Symbol, PERIOD_CURRENT, 1, 1, close_buf) < 1) { if (Debug) Print("[REJ] close_buf"); return; }

   double upper = high_buf[0], lower = low_buf[0];
   for (int i = 1; i < p; i++) {
      if (high_buf[i] > upper) upper = high_buf[i];
      if (low_buf[i] < lower) lower = low_buf[i];
   }

   double buf = UseBuffer ? BufferAtr * atr_t1 : 0;
   double cprev = close_buf[0];   // bar[1] close (CopyClose start=1, count=1)

   bool buy_sig  = (cprev > upper + buf);
   bool sell_sig = (cprev < lower - buf);
   if (!buy_sig && !sell_sig) {
      if (Debug) PrintFormat("[REJ] no_breakout p=%d upper=%.2f lower=%.2f close=%.2f atr=%.2f z=%.2f buf=%.2f",
                              p, upper, lower, cprev, atr_t1, atr_z, buf);
      return;
   }

   // === v3 Regime Filter ===
   if (UseADXFilter) {
      double adx_arr[];
      if (CopyBuffer(adx_handle, 0, 1, 1, adx_arr) < 1) { if (Debug) Print("[REJ] adx_buf"); return; }
      double adx_val = adx_arr[0];
      if (adx_val < ADXMinValue) {
         if (Debug) PrintFormat("[REJ] adx=%.2f<%.2f", adx_val, ADXMinValue);
         return;
      }
   }

   if (UseH4Trend) {
      double h4_ema_arr[], h4_close_arr[];
      if (CopyBuffer(h4_ema_handle, 0, 1, 1, h4_ema_arr) < 1) { if (Debug) Print("[REJ] h4_ema_buf"); return; }
      if (CopyClose(_Symbol, PERIOD_H4, 1, 1, h4_close_arr) < 1) { if (Debug) Print("[REJ] h4_close_buf"); return; }
      double h4_ema   = h4_ema_arr[0];
      double h4_close = h4_close_arr[0];
      bool   long_ok  = (h4_close > h4_ema);
      bool   short_ok = (h4_close < h4_ema);
      if (buy_sig  && !long_ok)  { if (Debug) PrintFormat("[REJ] h4_against_long close=%.2f ema=%.2f", h4_close, h4_ema); buy_sig = false; }
      if (sell_sig && !short_ok) { if (Debug) PrintFormat("[REJ] h4_against_short close=%.2f ema=%.2f", h4_close, h4_ema); sell_sig = false; }
      if (!buy_sig && !sell_sig) return;
   }

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if (buy_sig) {
      g_sig_buy++;
      double entry = ask;
      double sl = entry - SLAtrMult * atr_t1;
      double tp = entry + TPAtrMult * atr_t1;
      double sl_dist = entry - sl;
      double lot = CalcLot(sl_dist);
      bool ok = trade.Buy(lot, _Symbol, entry, NormalizeDouble(sl, _Digits), NormalizeDouble(tp, _Digits), CommentTag);
      if (ok) {
         g_send_ok++;
         g_today_trades++;
         g_last_entry_bar = iTime(_Symbol, PERIOD_CURRENT, 0);
         g_chandelier_high = entry;
         g_chandelier_low = 0;
         g_entry_price = entry;
         g_entry_sl0 = sl;
         g_sl_dist = sl_dist;
         g_be_done = false;
         g_trail_done = false;
         // v4 ctx 主仓 level=1
         ArrayResize(g_pos, 1);
         g_pos[0].ticket = trade.ResultOrder();
         g_pos[0].entry = entry;
         g_pos[0].sl_dist = sl_dist;
         g_pos[0].init_lot = lot;
         g_pos[0].be_done = false;
         g_pos[0].trail_done = false;
         g_pos[0].partial1_done = false;
         g_pos[0].partial2_done = false;
         g_pos[0].level = 1;
         g_pos[0].type = POSITION_TYPE_BUY;
         g_pos_count = 1;
         if (Debug) PrintFormat("[BUY] lot=%.2f entry=%.2f sl=%.2f tp=%.2f atr=%.2f", lot, entry, sl, tp, atr_t1);
      } else {
         g_send_fail++;
         PrintFormat("[SEND_FAIL] BUY lot=%.2f entry=%.2f sl=%.2f tp=%.2f ret=%d desc=%s", lot, entry, sl, tp, trade.ResultRetcode(), trade.ResultRetcodeDescription());
      }
   } else if (sell_sig) {
      g_sig_sell++;
      double entry = bid;
      double sl = entry + SLAtrMult * atr_t1;
      double tp = entry - TPAtrMult * atr_t1;
      double sl_dist = sl - entry;
      double lot = CalcLot(sl_dist);
      bool ok = trade.Sell(lot, _Symbol, entry, NormalizeDouble(sl, _Digits), NormalizeDouble(tp, _Digits), CommentTag);
      if (ok) {
         g_send_ok++;
         g_today_trades++;
         g_last_entry_bar = iTime(_Symbol, PERIOD_CURRENT, 0);
         g_chandelier_low = entry;
         g_chandelier_high = 0;
         g_entry_price = entry;
         g_entry_sl0 = sl;
         g_sl_dist = sl_dist;
         g_be_done = false;
         g_trail_done = false;
         // v4 ctx 主仓 level=1
         ArrayResize(g_pos, 1);
         g_pos[0].ticket = trade.ResultOrder();
         g_pos[0].entry = entry;
         g_pos[0].sl_dist = sl_dist;
         g_pos[0].init_lot = lot;
         g_pos[0].be_done = false;
         g_pos[0].trail_done = false;
         g_pos[0].partial1_done = false;
         g_pos[0].partial2_done = false;
         g_pos[0].level = 1;
         g_pos[0].type = POSITION_TYPE_SELL;
         g_pos_count = 1;
         if (Debug) PrintFormat("[SELL] lot=%.2f entry=%.2f sl=%.2f tp=%.2f atr=%.2f", lot, entry, sl, tp, atr_t1);
      } else {
         g_send_fail++;
         PrintFormat("[SEND_FAIL] SELL lot=%.2f entry=%.2f sl=%.2f tp=%.2f ret=%d desc=%s", lot, entry, sl, tp, trade.ResultRetcode(), trade.ResultRetcodeDescription());
      }
   }
}
//+------------------------------------------------------------------+
