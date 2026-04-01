#ifndef __CLAUDE_V600_PP_JOURNAL_MQH__
#define __CLAUDE_V600_PP_JOURNAL_MQH__
#property strict

// ==================== ПРОФЕССИОНАЛЬНЫЙ ЖУРНАЛ ====================
// Версия: JournalV2
// Разделитель: ;
// Суффиксы брокера отрезаются
// Новые поля: AsiaH/L, LondonH/L, MidnightOpen, PrevNYClose, News, Pivot

string g_journalFile = "";
bool   g_journalReady = false;

//+------------------------------------------------------------------+
//| Очистить суффикс брокера из имени символа                          |
//+------------------------------------------------------------------+
string CleanSymbol()
{
   string sym = _Symbol;

   // Убрать '+' в конце (типичный суффикс ECN брокеров)
   int plusPos = StringFind(sym, "+");
   if(plusPos > 0) sym = StringSubstr(sym, 0, plusPos);

   string suffixes[] = {"b", ".raw", ".ecn", ".pro", "_m",
                          "-ECN", ".std", ".r", ".e", ".p",
                          ".i", ".s", "_SB", ".stp", "m"};

   for(int i = 0; i < ArraySize(suffixes); i++)
   {
      int pos = StringLen(sym) - StringLen(suffixes[i]);
      if(pos > 3)  // Минимум 3 символа в имени
      {
         if(StringSubstr(sym, pos) == suffixes[i])
         {
            sym = StringSubstr(sym, 0, pos);
            break;
         }
      }
   }
   return sym;
}

//+------------------------------------------------------------------+
//| Получить имя файла журнала                                         |
//+------------------------------------------------------------------+
string GetJournalFileName()
{
   string sym = CleanSymbol();
   string tf = EnumToString(_Period);
   StringReplace(tf, "PERIOD_", "");

   return JournalPrefix + "_" + sym + "_" + tf + ".csv";
}

//+------------------------------------------------------------------+
//| Инициализация журнала                                              |
//+------------------------------------------------------------------+
void Journal_Init()
{
   if(!EnableJournal) return;

   g_journalFile = GetJournalFileName();

   if(FileIsExist(g_journalFile))
   {
      int h = FileOpen(g_journalFile, FILE_READ|FILE_TXT|FILE_ANSI);
      if(h != INVALID_HANDLE)
      {
         string marker = FileReadString(h);
         FileClose(h);
         if(StringFind(marker, "JournalV") >= 0)
         {
            Print("[JOURNAL] Continuing: ", g_journalFile);
            g_journalReady = true;
            return;
         }
         // Старый формат → бэкап
         string bak = g_journalFile + ".bak";
         if(FileIsExist(bak)) FileDelete(bak);
         FileMove(g_journalFile, 0, bak, 0);
      }
   }

   Journal_WriteHeader();
   g_journalReady = true;
}

//+------------------------------------------------------------------+
//| Записать заголовок CSV                                             |
//+------------------------------------------------------------------+
void Journal_WriteHeader()
{
   int h = FileOpen(g_journalFile, FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(h == INVALID_HANDLE)
   {
      Print("[JOURNAL] Failed to create: ", g_journalFile, " Error: ", GetLastError());
      return;
   }

   string header = "JournalV2;Symbol;TF;RecType;DateTime;BarTime;TradeID;Dir;"
      "Sc_VWAP;Sc_SD;Sc_Str;Sc_Mom;Sc_CtxMult;"
      "Sc_WPR;Sc_BV;Sc_REI;Sc_PVSRA;Sc_FibPiv;"
      "WtScore;Agree;ShouldTrade;RiskMult;LongV;ShortV;"
      "Regime;Session;DayType;ADX;ATR;ATR_Ratio;"
      "SpreadPips;PriceVsVWAP;ADR_Pos;IsKillZone;HourGMT;DoW;"
      "BV_Type;PVSRA_Type;REI_Val;"
      "WPR1;WPR2;WPR3;WPR4;VolRatio;"
      "PDH;PDL;AsiaH;AsiaL;LondonH;LondonL;"
      "MidnightOpen;PrevNYClose;"
      "Setup;SClass;SBarsTo;"
      "NewsMin;NewsImpact;NewsTitle;"
      "PivotW;PivotZone;PivotBias;PivotD;PivotDZone;"
      "PivotNearR;PivotNearS;PivotConfl;ADR_Used;"
      "EntryPx;SL;TP;Lots;RSize;"
      "ClosePx;PnL_Money;PnL_R;DurBars;CloseReason;"
      "Notes";
   FileWriteString(h, header + "\n");

   FileClose(h);
   Print("[JOURNAL] Created: ", g_journalFile);
}

//+------------------------------------------------------------------+
//| Записать сигнал (каждый бар)                                       |
//+------------------------------------------------------------------+
void Journal_LogSignal(AgentSignal &signals[], MarketContext &ctx,
                        TradeDecision &dec)
{
   if(!EnableJournal || !g_journalReady) return;

   // Скипнутые сигналы пишем только если включено
   if(!dec.shouldTrade && !LogSkippedSignals) return;

   int h = FileOpen(g_journalFile, FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(h == INVALID_HANDLE) return;

   FileSeek(h, 0, SEEK_END);

   string recType = dec.shouldTrade ? "SIGNAL" : "SKIP";
   string dir = (dec.direction > 0) ? "LONG" : (dec.direction < 0) ? "SHORT" : "NONE";

   string line = "JournalV2;" +
      CleanSymbol() + ";" +
      GetTFString() + ";" +
      recType + ";" +
      TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES) + ";" +
      TimeToString(iTime(_Symbol, _Period, 0), TIME_DATE|TIME_MINUTES) + ";" +
      ";" +  // TradeID
      dir + ";" +
      // Scores
      IntegerToString(signals[0].score) + ";" +
      IntegerToString(signals[1].score) + ";" +
      IntegerToString(signals[2].score) + ";" +
      IntegerToString(signals[3].score) + ";" +
      DoubleToString(ctx.context_multiplier, 2) + ";" +
      IntegerToString(signals[5].score) + ";" +
      IntegerToString(signals[6].score) + ";" +
      IntegerToString(signals[7].score) + ";" +
      IntegerToString(signals[8].score) + ";" +
      IntegerToString(signals[9].score) + ";" +
      // Decision
      DoubleToString(dec.weightedScore, 1) + ";" +
      IntegerToString(dec.agreeCount) + ";" +
      (dec.shouldTrade ? "1" : "0") + ";" +
      IntegerToString(dec.riskMultiple) + ";" +
      IntegerToString(dec.longVotes) + ";" +
      IntegerToString(dec.shortVotes) + ";" +
      // Context
      IntegerToString(ctx.regime) + ";" +
      IntegerToString(ctx.session) + ";" +
      IntegerToString(ctx.day_type) + ";" +
      DoubleToString(ctx.adx, 1) + ";" +
      DoubleToString(ctx.atr, _Digits) + ";" +
      DoubleToString(ctx.atr_ratio, 2) + ";" +
      DoubleToString(ctx.spread_pips, 1) + ";" +
      DoubleToString(ctx.price_vs_vwap, 1) + ";" +
      DoubleToString(ctx.adr_position, 2) + ";" +
      (ctx.is_kill_zone ? "1" : "0") + ";" +
      IntegerToString(ctx.hour_gmt) + ";" +
      IntegerToString(ctx.day_of_week) + ";" +
      // Indicators
      IntegerToString(ctx.bv_type) + ";" +
      IntegerToString(ctx.pvsra_type) + ";" +
      DoubleToString(ctx.rei_value, 1) + ";" +
      DoubleToString(ctx.wpr1, 1) + ";" +
      DoubleToString(ctx.wpr2, 1) + ";" +
      DoubleToString(ctx.wpr3, 1) + ";" +
      DoubleToString(ctx.wpr4, 1) + ";" +
      DoubleToString(ctx.volume_ratio, 2) + ";" +
      // Levels
      DoubleToString(ctx.pdh, _Digits) + ";" +
      DoubleToString(ctx.pdl, _Digits) + ";" +
      DoubleToString(ctx.asia_high, _Digits) + ";" +
      DoubleToString(ctx.asia_low, _Digits) + ";" +
      DoubleToString(ctx.london_high, _Digits) + ";" +
      DoubleToString(ctx.london_low, _Digits) + ";" +
      DoubleToString(ctx.midnight_open, _Digits) + ";" +
      DoubleToString(ctx.prev_ny_close, _Digits) + ";" +
      // Setup
      g_currentSetup.name + ";" +
      g_currentSetup.setupClass + ";" +
      IntegerToString(g_currentSetup.barsToEntry) + ";" +
      // News
      IntegerToString(ctx.news_minutes_to) + ";" +
      IntegerToString(ctx.news_impact) + ";" +
      ctx.news_title + ";" +
      // Pivot
      DoubleToString(ctx.pivot_weekly, _Digits) + ";" +
      IntegerToString(ctx.pivot_zone) + ";" +
      IntegerToString(ctx.pivot_bias) + ";" +
      DoubleToString(ctx.pivot_daily, _Digits) + ";" +
      IntegerToString(ctx.pivot_daily_zone) + ";" +
      DoubleToString(ctx.pivot_nearest_r, _Digits) + ";" +
      DoubleToString(ctx.pivot_nearest_s, _Digits) + ";" +
      (ctx.pivot_confluence ? "1" : "0") + ";" +
      DoubleToString(ctx.adr_used_pct, 1) + ";" +
      // Trade fields (пусто для сигнала)
      ";;;;;" +
      ";;;;;" +
      "";  // Notes
   FileWriteString(h, line + "\n");

   FileClose(h);
}

//+------------------------------------------------------------------+
//| Записать сделку                                                    |
//+------------------------------------------------------------------+
void Journal_LogTrade(string tradeId, string dir,
                       double entryPx, double sl, double tp,
                       double lots, double rSize)
{
   if(!EnableJournal || !g_journalReady) return;

   int h = FileOpen(g_journalFile, FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(h == INVALID_HANDLE) return;

   FileSeek(h, 0, SEEK_END);

   // Empty fields for scores(10) + decision(6) + context(12) + indicators(8)
   // + levels(8) + setup(3) + news(3) + pivot(9) = 59 empty fields
   string emptyFields = ";;;;;;;;;;";  // 10 scores
   emptyFields += ";;;;;;";            // 6 decision
   emptyFields += ";;;;;;;;;;;;";      // 12 context
   emptyFields += ";;;;;;;;";          // 8 indicators
   emptyFields += ";;;;;;;;";          // 8 levels
   emptyFields += ";;;";              // 3 setup
   emptyFields += ";;;";              // 3 news
   emptyFields += ";;;;;;;;;";        // 9 pivot

   string line = "JournalV2;" +
      CleanSymbol() + ";" +
      GetTFString() + ";" +
      "ENTRY;" +
      TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES) + ";" +
      TimeToString(iTime(_Symbol, _Period, 0), TIME_DATE|TIME_MINUTES) + ";" +
      tradeId + ";" +
      dir + ";" +
      emptyFields +
      // Trade fields
      DoubleToString(entryPx, _Digits) + ";" +
      DoubleToString(sl, _Digits) + ";" +
      DoubleToString(tp, _Digits) + ";" +
      DoubleToString(lots, 2) + ";" +
      DoubleToString(rSize, _Digits) + ";" +
      // Close fields (empty)
      ";;;;;" +
      "";  // Notes
   FileWriteString(h, line + "\n");

   FileClose(h);
}

//+------------------------------------------------------------------+
//| Записать закрытие сделки                                           |
//+------------------------------------------------------------------+
void Journal_LogClose(string tradeId, double closePx, double pnlMoney,
                       double pnlR, int durBars, string closeReason)
{
   if(!EnableJournal || !g_journalReady) return;

   int h = FileOpen(g_journalFile, FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(h == INVALID_HANDLE) return;

   FileSeek(h, 0, SEEK_END);

   string dir = (pnlMoney >= 0) ? "LONG" : "SHORT";

   // Same empty fields structure as LogTrade
   string emptyFields = ";;;;;;;;;;";  // 10 scores
   emptyFields += ";;;;;;";            // 6 decision
   emptyFields += ";;;;;;;;;;;;";      // 12 context
   emptyFields += ";;;;;;;;";          // 8 indicators
   emptyFields += ";;;;;;;;";          // 8 levels
   emptyFields += ";;;";              // 3 setup
   emptyFields += ";;;";              // 3 news
   emptyFields += ";;;;;;;;;";        // 9 pivot

   string line = "JournalV2;" +
      CleanSymbol() + ";" +
      GetTFString() + ";" +
      "EXIT;" +
      TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES) + ";" +
      TimeToString(iTime(_Symbol, _Period, 0), TIME_DATE|TIME_MINUTES) + ";" +
      tradeId + ";" +
      dir + ";" +
      emptyFields +
      // Entry fields (empty)
      ";;;;;" +
      // Close fields
      DoubleToString(closePx, _Digits) + ";" +
      DoubleToString(pnlMoney, 2) + ";" +
      DoubleToString(pnlR, 2) + ";" +
      IntegerToString(durBars) + ";" +
      closeReason + ";" +
      "";  // Notes
   FileWriteString(h, line + "\n");

   FileClose(h);
}

//+------------------------------------------------------------------+
//| Получить строку таймфрейма                                         |
//+------------------------------------------------------------------+
string GetTFString()
{
   string tf = EnumToString(_Period);
   StringReplace(tf, "PERIOD_", "");
   return tf;
}

#endif
