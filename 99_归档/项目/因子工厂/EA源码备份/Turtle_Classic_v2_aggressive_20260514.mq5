//+------------------------------------------------------------------+
//|                                          Turtle_Classic_v1.mq5    |
//|        经典 Turtle (Dennis & Eckhardt 1983) — XAUUSD H4           |
//|        System 1 (20-bar/10-bar) + System 2 (55-bar/20-bar)        |
//|        N-based pyramid (0.5N step, max 4 units) + 2N stop         |
//+------------------------------------------------------------------+
#property copyright "Joker Factor Factory v20260514"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>
CTrade trade;

input group "=== System Selection ==="
input int    SystemMode      = 1;       // 1=S1 (20/10), 2=S2 (55/20), 0=Both

input group "=== System 1 (短期) ==="
input int    S1Entry         = 20;
input int    S1Exit          = 10;
input bool   S1FilterPrev    = true;    // 前一笔 S1 突破若盈利, 跳过当前突破

input group "=== System 2 (长期) ==="
input int    S2Entry         = 55;
input int    S2Exit          = 20;

input group "=== N (Volatility) ==="
input int    NPeriod         = 20;
input double StopUnits       = 2.0;
input double PyramidStepN    = 0.3;     // 激进: 每 0.3N 加 (vs 经典 0.5N)

input group "=== Risk ==="
input double RiskPctPerUnit  = 0.5;     // 激进: 0.5%/unit × 6u = 3% 总曝
input int    MaxUnits        = 6;       // 激进: max 6 units (vs 经典 4)

input group "=== Chandelier Trail (锁大趋势利润) ==="
input bool   UseChandelier   = true;    // 利润 ≥ ActivateN 后启动 trail
input double ChandelierActivateN = 1.5; // 利润 ≥ 1.5N 启动
input double ChandelierDistN  = 2.0;    // trail = highest_close - 2N

input group "=== 时间 / 频率 ==="
input bool   UseSession      = false;
input int    SessionStartHour= 0;
input int    SessionEndHour  = 24;

input group "=== 反向 (实测 XAU M5 突破是负 alpha) ==="
input bool   InverseSignal   = false;
input double InverseTPUnits  = 2.0;

input group "=== HMM Regime Filter (复用 Delphi II 的 regime.csv) ==="
input bool   UseRegimeFilter = false;  // 默认关; Inverse 模式建议开 + InvertAllow=true
input bool   InvertRegimeAllow = false;  // true = 在 Delphi II skip 的 state (平静/下跌) 才入 = mean reversion 友好
input string RegimeCsvFile  = "regime.csv";

input group "=== 系统 ==="
input ulong  Magic           = 57210;
input string CommentTag      = "Turtle";
input bool   Debug           = false;

int atr_handle = INVALID_HANDLE;
datetime g_last_bar = 0;

// Chandelier trail state (按 type)
double g_chand_high_long = 0;
double g_chand_low_short = 0;

// HMM regime data (复用 Delphi II v5)
long g_regime_epoch[];
int  g_regime_allow[];
int  g_regime_n = 0;

// Position tracking
struct TurtleUnit {
   ulong   ticket;
   double  entry;
   double  N_at_entry;
   int     unit_idx;       // 1..MaxUnits
   long    type;           // POSITION_TYPE_BUY/SELL
   int     system;         // 1 or 2
};
TurtleUnit g_units[];
int g_units_n = 0;

// "上一笔 S1 突破是否盈利" 状态 (long / short 分开)
bool g_last_s1_long_won  = false;
bool g_last_s1_short_won = false;

// 统计
int g_bar_count = 0;
int g_sig_buy_s1 = 0, g_sig_sell_s1 = 0, g_sig_buy_s2 = 0, g_sig_sell_s2 = 0;
int g_pyramid_count = 0;
int g_send_ok = 0, g_send_fail = 0;

//+------------------------------------------------------------------+
int OnInit() {
   trade.SetExpertMagicNumber(Magic);
   trade.SetTypeFillingBySymbol(_Symbol);
   atr_handle = iATR(_Symbol, PERIOD_CURRENT, NPeriod);
   if (atr_handle == INVALID_HANDLE) return INIT_FAILED;
   PrintFormat("[INIT] OK symbol=%s digits=%d inverse=%d invTP=%.1f regime=%d invertAllow=%d",
      _Symbol, _Digits, InverseSignal, InverseTPUnits, UseRegimeFilter, InvertRegimeAllow);
   if (UseRegimeFilter) LoadRegimeCSV();
   return INIT_SUCCEEDED;
}

void LoadRegimeCSV() {
   int fh = FileOpen(RegimeCsvFile, FILE_READ|FILE_CSV|FILE_ANSI|FILE_COMMON, ',');
   if (fh == INVALID_HANDLE) {
      fh = FileOpen(RegimeCsvFile, FILE_READ|FILE_CSV|FILE_ANSI, ',');
      if (fh == INVALID_HANDLE) { PrintFormat("[REGIME] load fail err=%d", GetLastError()); return; }
   }
   ArrayResize(g_regime_epoch, 15000);
   ArrayResize(g_regime_allow, 15000);
   g_regime_n = 0;
   while (!FileIsEnding(fh)) {
      long ep = (long)FileReadNumber(fh);
      int st = (int)FileReadNumber(fh);
      int al = (int)FileReadNumber(fh);
      if (ep > 0 && g_regime_n < 15000) {
         g_regime_epoch[g_regime_n] = ep;
         g_regime_allow[g_regime_n] = al;
         g_regime_n++;
      }
   }
   FileClose(fh);
   ArrayResize(g_regime_epoch, g_regime_n);
   ArrayResize(g_regime_allow, g_regime_n);
   PrintFormat("[REGIME] loaded %d rows, invertAllow=%d", g_regime_n, InvertRegimeAllow);
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
   if (MathAbs(g_regime_epoch[lo] - ep) > 7200) return true;
   bool csv_allow = (g_regime_allow[lo] == 1);
   return InvertRegimeAllow ? !csv_allow : csv_allow;
}

void OnDeinit(const int reason) {
   PrintFormat("[STATS] bars=%d s1_buy=%d s1_sell=%d s2_buy=%d s2_sell=%d pyramids=%d send_ok=%d send_fail=%d",
      g_bar_count, g_sig_buy_s1, g_sig_sell_s1, g_sig_buy_s2, g_sig_sell_s2, g_pyramid_count, g_send_ok, g_send_fail);
   if (MQLInfoInteger(MQL_TESTER)) PrintMetrics();
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
   double sharpe = TesterStatistics(STAT_SHARPE_RATIO);
   PrintFormat("[METRIC] system=%d s1=%d/%d s2=%d/%d N=%d stop=%.1f pyr_step=%.2f max=%d risk=%.2f profit=%.2f mdd_pct=%.2f mdd_abs=%.2f pf=%.3f n=%d wr=%.1f sharpe=%.2f",
      SystemMode, S1Entry, S1Exit, S2Entry, S2Exit, NPeriod, StopUnits, PyramidStepN, MaxUnits, RiskPctPerUnit,
      profit, mdd_pct, mdd_abs, pf, trades, wr, sharpe);
}

//+------------------------------------------------------------------+
bool NewBar() {
   datetime t = iTime(_Symbol, PERIOD_CURRENT, 0);
   if (t == g_last_bar) return false;
   g_last_bar = t;
   return true;
}

bool InSession() {
   if (!UseSession) return true;
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   if (tm.day_of_week == 0 || tm.day_of_week == 6) return false;
   return (tm.hour >= SessionStartHour && tm.hour < SessionEndHour);
}

double GetN() {
   double buf[];
   if (CopyBuffer(atr_handle, 0, 1, 1, buf) < 1) return 0;
   return buf[0];
}

double GetUnitLot(double N) {
   if (N <= 0) return 0;
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   double risk_cash = eq * RiskPctPerUnit / 100.0;
   double sl_dist = StopUnits * N;
   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tick_val  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if (tick_size <= 0 || tick_val <= 0 || sl_dist <= 0) return 0.01;
   double lot = risk_cash / (sl_dist / tick_size * tick_val);
   double minlot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxlot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lot = MathFloor(lot / step) * step;
   if (lot < minlot) lot = minlot;
   if (lot > maxlot) lot = maxlot;
   return lot;
}

int CountUnits(long type) {
   int n = 0;
   for (int i = 0; i < g_units_n; i++) {
      if (g_units[i].type == type) n++;
   }
   return n;
}

double LastEntry(long type) {
   double e = (type == POSITION_TYPE_BUY) ? -1e9 : 1e9;
   for (int i = 0; i < g_units_n; i++) {
      if (g_units[i].type != type) continue;
      if (type == POSITION_TYPE_BUY && g_units[i].entry > e) e = g_units[i].entry;
      if (type == POSITION_TYPE_SELL && g_units[i].entry < e) e = g_units[i].entry;
   }
   return e;
}

double AvgN(long type) {
   double s = 0; int c = 0;
   for (int i = 0; i < g_units_n; i++) {
      if (g_units[i].type != type) continue;
      s += g_units[i].N_at_entry; c++;
   }
   return c > 0 ? s/c : 0;
}

void SyncUnits() {
   // 移除已平仓 units (ticket 在 PositionsTotal 找不到)
   for (int i = g_units_n - 1; i >= 0; i--) {
      bool found = false;
      for (int j = 0; j < PositionsTotal(); j++) {
         if (PositionGetTicket(j) == g_units[i].ticket) { found = true; break; }
      }
      if (!found) {
         for (int k = i; k < g_units_n - 1; k++) g_units[k] = g_units[k+1];
         g_units_n--;
      }
   }
}

void UpdateAllSL(long type, double new_sl) {
   for (int i = 0; i < PositionsTotal(); i++) {
      ulong tk = PositionGetTicket(i);
      if (!PositionSelectByTicket(tk)) continue;
      if (PositionGetInteger(POSITION_MAGIC) != (long)Magic) continue;
      if (PositionGetInteger(POSITION_TYPE) != type) continue;
      double cur_sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);
      if (type == POSITION_TYPE_BUY && new_sl > cur_sl) {
         trade.PositionModify(tk, NormalizeDouble(new_sl, _Digits), tp);
      } else if (type == POSITION_TYPE_SELL && (cur_sl == 0 || new_sl < cur_sl)) {
         trade.PositionModify(tk, NormalizeDouble(new_sl, _Digits), tp);
      }
   }
}

void CloseAllType(long type) {
   for (int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong tk = PositionGetTicket(i);
      if (!PositionSelectByTicket(tk)) continue;
      if (PositionGetInteger(POSITION_MAGIC) != (long)Magic) continue;
      if (PositionGetInteger(POSITION_TYPE) != type) continue;
      trade.PositionClose(tk);
   }
}

bool OpenUnit(long type, double N, int system_id) {
   if (CountUnits(type) >= MaxUnits) return false;
   double lot = GetUnitLot(N);
   if (lot <= 0) return false;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double entry = (type == POSITION_TYPE_BUY) ? ask : bid;
   double sl = (type == POSITION_TYPE_BUY) ? entry - StopUnits * N : entry + StopUnits * N;
   // Inverse 模式加 TP (mean reversion R:R 1:1 锁利), Trend 模式无 TP
   double tp = 0;
   if (InverseSignal && InverseTPUnits > 0) {
      tp = (type == POSITION_TYPE_BUY) ? entry + InverseTPUnits * N : entry - InverseTPUnits * N;
   }

   bool ok;
   if (type == POSITION_TYPE_BUY) ok = trade.Buy(lot, _Symbol, entry, NormalizeDouble(sl, _Digits), NormalizeDouble(tp, _Digits), CommentTag);
   else                           ok = trade.Sell(lot, _Symbol, entry, NormalizeDouble(sl, _Digits), NormalizeDouble(tp, _Digits), CommentTag);

   if (ok) {
      g_send_ok++;
      ArrayResize(g_units, g_units_n + 1);
      g_units[g_units_n].ticket = trade.ResultOrder();
      g_units[g_units_n].entry = entry;
      g_units[g_units_n].N_at_entry = N;
      g_units[g_units_n].unit_idx = CountUnits(type);  // 已加上自己 = idx
      g_units[g_units_n].type = type;
      g_units[g_units_n].system = system_id;
      g_units_n++;
      if (g_units[g_units_n-1].unit_idx > 1) g_pyramid_count++;
      // 加仓后所有 same-type SL 上移
      if (g_units[g_units_n-1].unit_idx > 1) {
         double new_sl = (type == POSITION_TYPE_BUY) ? entry - StopUnits * N : entry + StopUnits * N;
         UpdateAllSL(type, new_sl);
      }
      if (Debug) PrintFormat("[OPEN_%s] sys=%d unit=%d entry=%.2f N=%.2f lot=%.2f",
         type == POSITION_TYPE_BUY ? "BUY" : "SELL", system_id, g_units[g_units_n-1].unit_idx, entry, N, lot);
      return true;
   } else {
      g_send_fail++;
      if (Debug) PrintFormat("[SEND_FAIL] type=%d ret=%d", (int)type, trade.ResultRetcode());
      return false;
   }
}

//+------------------------------------------------------------------+
void ManageChandelier(double N) {
   if (!UseChandelier || N <= 0) return;
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   int n_buy = CountUnits(POSITION_TYPE_BUY);
   int n_sell = CountUnits(POSITION_TYPE_SELL);

   if (n_buy > 0) {
      double avg_entry = 0; int c = 0;
      for (int i = 0; i < g_units_n; i++) {
         if (g_units[i].type == POSITION_TYPE_BUY) { avg_entry += g_units[i].entry; c++; }
      }
      if (c > 0) avg_entry /= c;
      double profit_units = (bid - avg_entry) / N;
      if (profit_units >= ChandelierActivateN) {
         if (bid > g_chand_high_long) g_chand_high_long = bid;
         double new_sl = g_chand_high_long - ChandelierDistN * N;
         UpdateAllSL(POSITION_TYPE_BUY, new_sl);
      }
   } else {
      g_chand_high_long = 0;
   }

   if (n_sell > 0) {
      double avg_entry = 0; int c = 0;
      for (int i = 0; i < g_units_n; i++) {
         if (g_units[i].type == POSITION_TYPE_SELL) { avg_entry += g_units[i].entry; c++; }
      }
      if (c > 0) avg_entry /= c;
      double profit_units = (avg_entry - ask) / N;
      if (profit_units >= ChandelierActivateN) {
         if (g_chand_low_short == 0 || ask < g_chand_low_short) g_chand_low_short = ask;
         double new_sl = g_chand_low_short + ChandelierDistN * N;
         UpdateAllSL(POSITION_TYPE_SELL, new_sl);
      }
   } else {
      g_chand_low_short = 0;
   }
}

void OnTick() {
   // Chandelier trail 每 tick 更新 (利润达 N 后启动)
   double atr_buf[];
   if (CopyBuffer(atr_handle, 0, 0, 1, atr_buf) >= 1 && atr_buf[0] > 0) {
      ManageChandelier(atr_buf[0]);
   }

   if (!NewBar()) return;
   g_bar_count++;
   SyncUnits();

   if (!InSession()) return;

   double N = GetN();
   if (N <= 0) return;

   // === Pyramid check (existing position) ===
   if (g_units_n > 0) {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      // BUY pyramid: price > last_entry + 0.5N
      int n_buy = CountUnits(POSITION_TYPE_BUY);
      int n_sell = CountUnits(POSITION_TYPE_SELL);
      if (n_buy > 0 && n_buy < MaxUnits) {
         double last_buy = LastEntry(POSITION_TYPE_BUY);
         if (bid >= last_buy + PyramidStepN * N) {
            OpenUnit(POSITION_TYPE_BUY, N, 1);
         }
      }
      if (n_sell > 0 && n_sell < MaxUnits) {
         double last_sell = LastEntry(POSITION_TYPE_SELL);
         if (ask <= last_sell - PyramidStepN * N) {
            OpenUnit(POSITION_TYPE_SELL, N, 1);
         }
      }
   }

   // === Exit check ===
   // System 1 exit: 10-bar Donchian opposite
   // System 2 exit: 20-bar Donchian opposite
   // 我们简化: 用激活的 system 的 exit period (mixed if both)
   int exit_period = (SystemMode == 2) ? S2Exit : S1Exit;

   // Exit 用 bar[2..exit_period+1] (排除 bar[1] 自身, 跟 Entry Donchian 一致)
   double high_arr[], low_arr[];
   if (CopyHigh(_Symbol, PERIOD_CURRENT, 2, exit_period, high_arr) < exit_period) return;
   if (CopyLow(_Symbol, PERIOD_CURRENT, 2, exit_period, low_arr) < exit_period) return;
   double exit_low_for_long = low_arr[0];
   double exit_high_for_short = high_arr[0];
   for (int i = 1; i < exit_period; i++) {
      if (low_arr[i] < exit_low_for_long) exit_low_for_long = low_arr[i];
      if (high_arr[i] > exit_high_for_short) exit_high_for_short = high_arr[i];
   }
   double close_buf[];
   if (CopyClose(_Symbol, PERIOD_CURRENT, 1, 1, close_buf) < 1) return;
   double cprev = close_buf[0];

   // 平仓信号 (Trend vs Inverse 对称)
   bool exit_long, exit_short;
   if (InverseSignal) {
      // Inverse BUY = Fade BO lower, 平 = 价格回升突破 exit_high (mean reversion 成功)
      exit_long  = (cprev > exit_high_for_short);
      // Inverse SELL = Fade BO upper, 平 = 价格回落跌破 exit_low (mean reversion 成功)
      exit_short = (cprev < exit_low_for_long);
   } else {
      exit_long  = (cprev < exit_low_for_long);
      exit_short = (cprev > exit_high_for_short);
   }
   // 经典海龟 Entry Filter: 在平仓前记录这一笔是否盈利 (用 main unit P&L)
   if (CountUnits(POSITION_TYPE_BUY) > 0 && exit_long) {
      double total_pnl_long = 0;
      for (int p = 0; p < PositionsTotal(); p++) {
         ulong tk = PositionGetTicket(p);
         if (!PositionSelectByTicket(tk)) continue;
         if (PositionGetInteger(POSITION_MAGIC) != (long)Magic) continue;
         if (PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY) continue;
         total_pnl_long += PositionGetDouble(POSITION_PROFIT);
      }
      CloseAllType(POSITION_TYPE_BUY);
      // 只在 main unit (level 1) entry 计入 "上一笔 BO" 状态
      // 经典海龟: 这一笔 BO 盈利 → 下一笔 BO 跳过 (skip if won)
      g_last_s1_long_won = (total_pnl_long > 0);
      if (Debug) PrintFormat("[CLOSE_LONG] pnl=%.2f, next_BO_long=%s", total_pnl_long, g_last_s1_long_won ? "SKIP" : "TAKE");
      return;
   }
   if (CountUnits(POSITION_TYPE_SELL) > 0 && exit_short) {
      double total_pnl_short = 0;
      for (int p = 0; p < PositionsTotal(); p++) {
         ulong tk = PositionGetTicket(p);
         if (!PositionSelectByTicket(tk)) continue;
         if (PositionGetInteger(POSITION_MAGIC) != (long)Magic) continue;
         if (PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_SELL) continue;
         total_pnl_short += PositionGetDouble(POSITION_PROFIT);
      }
      CloseAllType(POSITION_TYPE_SELL);
      g_last_s1_short_won = (total_pnl_short > 0);
      if (Debug) PrintFormat("[CLOSE_SHORT] pnl=%.2f, next_BO_short=%s", total_pnl_short, g_last_s1_short_won ? "SKIP" : "TAKE");
      return;
   }

   // === Entry check (no existing position of same type) ===
   if (g_units_n > 0) return;

   // HMM regime filter (bar[1] time)
   if (UseRegimeFilter) {
      datetime bar1_t = iTime(_Symbol, PERIOD_CURRENT, 1);
      if (!RegimeAllow(bar1_t)) {
         if (Debug) Print("[REJ] regime");
         return;
      }
   }

   // S1 entry
   if (SystemMode == 1 || SystemMode == 0) {
      double h_s1[], l_s1[];
      if (CopyHigh(_Symbol, PERIOD_CURRENT, 2, S1Entry, h_s1) >= S1Entry &&
          CopyLow(_Symbol, PERIOD_CURRENT, 2, S1Entry, l_s1) >= S1Entry) {
         double upper = h_s1[0], lower = l_s1[0];
         for (int i = 1; i < S1Entry; i++) {
            if (h_s1[i] > upper) upper = h_s1[i];
            if (l_s1[i] < lower) lower = l_s1[i];
         }
         bool buy_s1 = (cprev > upper);
         bool sell_s1 = (cprev < lower);
         // FilterPrev: 跳过前一笔盈利的 S1 突破
         if (buy_s1 && S1FilterPrev && g_last_s1_long_won) {
            if (Debug) Print("[REJ] S1_long filter (prev won)");
            buy_s1 = false;
         }
         if (sell_s1 && S1FilterPrev && g_last_s1_short_won) {
            if (Debug) Print("[REJ] S1_short filter (prev won)");
            sell_s1 = false;
         }
         // Inverse swap (Fade BO)
         if (InverseSignal) { bool tmp = buy_s1; buy_s1 = sell_s1; sell_s1 = tmp; }
         if (buy_s1)  { g_sig_buy_s1++;  if (OpenUnit(POSITION_TYPE_BUY, N, 1))  return; }
         if (sell_s1) { g_sig_sell_s1++; if (OpenUnit(POSITION_TYPE_SELL, N, 1)) return; }
      }
   }

   // S2 entry (no filter)
   if (SystemMode == 2 || SystemMode == 0) {
      double h_s2[], l_s2[];
      if (CopyHigh(_Symbol, PERIOD_CURRENT, 2, S2Entry, h_s2) >= S2Entry &&
          CopyLow(_Symbol, PERIOD_CURRENT, 2, S2Entry, l_s2) >= S2Entry) {
         double upper2 = h_s2[0], lower2 = l_s2[0];
         for (int i = 1; i < S2Entry; i++) {
            if (h_s2[i] > upper2) upper2 = h_s2[i];
            if (l_s2[i] < lower2) lower2 = l_s2[i];
         }
         bool buy_s2 = (cprev > upper2);
         bool sell_s2 = (cprev < lower2);
         if (InverseSignal) { bool tmp2 = buy_s2; buy_s2 = sell_s2; sell_s2 = tmp2; }
         if (buy_s2)  { g_sig_buy_s2++;  if (OpenUnit(POSITION_TYPE_BUY, N, 2))  return; }
         if (sell_s2) { g_sig_sell_s2++; if (OpenUnit(POSITION_TYPE_SELL, N, 2)) return; }
      }
   }
}
//+------------------------------------------------------------------+
