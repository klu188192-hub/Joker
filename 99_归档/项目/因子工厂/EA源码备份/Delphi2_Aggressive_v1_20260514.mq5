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
input int    BaseDonchian   = 12;     // 基础通道周期 (Aggressive)
input int    AtrPeriod      = 14;
input int    AtrLookback    = 100;    // z-score 回看
input double AdaptK         = 0.30;   // 周期自适应系数 (ATRz高=周期更长抗假突破)
input double AtrFloorMult   = 0.50;   // ATR < median×K 拒绝 (太静)
input bool   UseBuffer      = true;
input double BufferAtr      = 0.10;   // 突破缓冲 = ATR × K

input group "=== SL / TP / Trail ==="
input double SLAtrMult      = 1.50;
input double TPAtrMult      = 3.00;   // 1:2 R/R
input bool   UseChandelier  = true;
input double TrailAtrMult   = 2.00;   // Chandelier 离极值距离
input double RiskPctEquity  = 1.00;

input group "=== 时间 / 频率 ==="
input bool   UseSession       = true;
input int    SessionStartHour = 8;    // GMT
input int    SessionEndHour   = 20;
input int    DayCloseHour     = 21;   // 强平
input int    MaxTradesPerDay  = 4;    // Aggressive 上限
input int    MinBarsBetween   = 2;

input group "=== 系统 ==="
input ulong  Magic            = 57201;
input string CommentTag       = "Delphi2_Agg";

int atr_handle = INVALID_HANDLE;
datetime g_last_bar = 0;
datetime g_last_entry_bar = 0;
int g_today_trades = 0;
datetime g_today_start = 0;
double g_chandelier_high = 0;
double g_chandelier_low = 0;

//+------------------------------------------------------------------+
int OnInit() {
   trade.SetExpertMagicNumber(Magic);
   trade.SetTypeFillingBySymbol(_Symbol);
   atr_handle = iATR(_Symbol, PERIOD_CURRENT, AtrPeriod);
   if (atr_handle == INVALID_HANDLE) return INIT_FAILED;
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
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

void ManageChandelier(double atr) {
   if (!UseChandelier) return;
   for (int i = 0; i < PositionsTotal(); i++) {
      ulong tk = PositionGetTicket(i);
      if (!PositionSelectByTicket(tk)) continue;
      if (PositionGetInteger(POSITION_MAGIC) != (long)Magic) continue;
      long type = PositionGetInteger(POSITION_TYPE);
      double tp = PositionGetDouble(POSITION_TP);
      double cur_sl = PositionGetDouble(POSITION_SL);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      if (type == POSITION_TYPE_BUY) {
         if (bid > g_chandelier_high) g_chandelier_high = bid;
         double new_sl = g_chandelier_high - TrailAtrMult * atr;
         if (new_sl > cur_sl && new_sl < bid) {
            trade.PositionModify(tk, NormalizeDouble(new_sl, _Digits), tp);
         }
      } else if (type == POSITION_TYPE_SELL) {
         if (g_chandelier_low == 0 || ask < g_chandelier_low) g_chandelier_low = ask;
         double new_sl = g_chandelier_low + TrailAtrMult * atr;
         if ((cur_sl == 0 || new_sl < cur_sl) && new_sl > ask) {
            trade.PositionModify(tk, NormalizeDouble(new_sl, _Digits), tp);
         }
      }
   }
}

//+------------------------------------------------------------------+
void OnTick() {
   double atr_arr[];
   if (CopyBuffer(atr_handle, 0, 0, 2, atr_arr) < 2) return;
   double atr_now = atr_arr[0];   // index 0 = current bar ATR, OK 用于 trail

   if (ShouldForceClose() && HasOpenPos()) {
      CloseAllMagic();
      return;
   }
   ManageChandelier(atr_now);

   if (!NewBar()) return;
   ResetDayCounter();

   if (!InSession()) return;
   if (HasOpenPos()) return;
   if (g_today_trades >= MaxTradesPerDay) return;
   if (g_last_entry_bar != 0) {
      int shift = iBarShift(_Symbol, PERIOD_CURRENT, g_last_entry_bar);
      if (shift < MinBarsBetween) return;
   }

   // ATR z-score (用 bar[1] 数据避 lookahead)
   double atr_hist[];
   if (CopyBuffer(atr_handle, 0, 1, AtrLookback, atr_hist) < AtrLookback) return;
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
   if (median_atr > 0 && atr_t1 < median_atr * AtrFloorMult) return;

   // 自适应周期
   int p = AdaptivePeriod(atr_z);

   // Donchian (用 bar[1..p])
   double high_buf[], low_buf[], close_buf[];
   if (CopyHigh(_Symbol, PERIOD_CURRENT, 1, p, high_buf) < p) return;
   if (CopyLow(_Symbol, PERIOD_CURRENT, 1, p, low_buf) < p) return;
   if (CopyClose(_Symbol, PERIOD_CURRENT, 1, 2, close_buf) < 2) return;

   double upper = high_buf[0], lower = low_buf[0];
   for (int i = 1; i < p; i++) {
      if (high_buf[i] > upper) upper = high_buf[i];
      if (low_buf[i] < lower) lower = low_buf[i];
   }

   double buf = UseBuffer ? BufferAtr * atr_t1 : 0;
   double cprev = close_buf[1];   // close[1] (CopyClose start=1 → arr[0]=bar[1], arr[1]=bar[2])
   // 修正: CopyClose 从 start_pos=1 拷 2 根 → arr[0]=bar[1] 最新已收盘, arr[1]=bar[2]
   cprev = close_buf[0];

   bool buy_sig  = (cprev > upper + buf);
   bool sell_sig = (cprev < lower - buf);
   if (!buy_sig && !sell_sig) return;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if (buy_sig) {
      double entry = ask;
      double sl = entry - SLAtrMult * atr_t1;
      double tp = entry + TPAtrMult * atr_t1;
      double sl_dist = entry - sl;
      double lot = CalcLot(sl_dist);
      if (trade.Buy(lot, _Symbol, entry, NormalizeDouble(sl, _Digits), NormalizeDouble(tp, _Digits), CommentTag)) {
         g_today_trades++;
         g_last_entry_bar = iTime(_Symbol, PERIOD_CURRENT, 0);
         g_chandelier_high = entry;
         g_chandelier_low = 0;
      }
   } else if (sell_sig) {
      double entry = bid;
      double sl = entry + SLAtrMult * atr_t1;
      double tp = entry - TPAtrMult * atr_t1;
      double sl_dist = sl - entry;
      double lot = CalcLot(sl_dist);
      if (trade.Sell(lot, _Symbol, entry, NormalizeDouble(sl, _Digits), NormalizeDouble(tp, _Digits), CommentTag)) {
         g_today_trades++;
         g_last_entry_bar = iTime(_Symbol, PERIOD_CURRENT, 0);
         g_chandelier_low = entry;
         g_chandelier_high = 0;
      }
   }
}
//+------------------------------------------------------------------+
