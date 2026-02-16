//+------------------------------------------------------------------+
//|                        Claude_v600_Tester_PropPanel.mq5            |
//|                        Multi-Agent Trading System for MT5          |
//|                        Version 6.00                                |
//+------------------------------------------------------------------+
#property copyright "Claude v600"
#property version   "6.00"
#property description "Multi-Agent Trading System for MetaTrader 5"
#property description "10 agents: VWAP, SD, Structure, Momentum, Context,"
#property description "WPR, BetterVolume, TD_REI, PVSRA, FibPivot"
#property description "FVG_CAD5 Playbook v4 (Prop-style)"

// ==================== INCLUDES ====================
// Локальные модули (из одной папки)
#include "Claude_v600_pp_inputs.mqh"
#include "Claude_v600_pp_diag.mqh"
#include "Claude_v600_pp_color_schemes.mqh"
#include "Claude_v600_pp_context.mqh"
#include "Claude_v600_pp_sessions.mqh"
#include "Claude_v600_pp_market_levels.mqh"
#include "Claude_v600_pp_agents.mqh"
#include "Claude_v600_pp_agents_ext.mqh"
#include "Claude_v600_pp_fib_pivot.mqh"
#include "Claude_v600_pp_decision.mqh"
#include "Claude_v600_pp_setups.mqh"
#include "Claude_v600_pp_journal.mqh"
#include "Claude_v600_pp_news.mqh"
#include "Claude_v600_pp_learning.mqh"
#include "Claude_v600_pp_twap.mqh"
#include "Claude_v600_pp_ui_panel.mqh"

// Стандартная библиотека MQL5
#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/SymbolInfo.mqh>

// ==================== ГЛОБАЛЬНЫЕ ОБЪЕКТЫ ====================
CTrade         g_trade;
CPositionInfo  g_posInfo;
CSymbolInfo    g_symInfo;

// Глобальные данные агентов
AgentSignal    g_signals[MAX_AGENTS];
TradeDecision  g_decision;
MarketContext  g_ctx;
datetime       g_lastBar = 0;
int            g_dailyTradeCount = 0;
double         g_dailyPnL = 0;
datetime       g_lastDay = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                      |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("==========================================");
   Print("Claude_v600 PropPanel v6.00 Starting...");
   Print("Symbol: ", _Symbol, " Period: ", EnumToString(_Period));
   Print("==========================================");

   // 1. Цветовая схема
   InitColorScheme(ColorScheme);
   ApplySchemeToChart();

   // 2. Диагностика
   DIAG_Init();

   // 3. Контекст рынка
   if(!CTX_Init())
   {
      Print("[INIT] Context init FAILED!");
      return INIT_FAILED;
   }
   DIAG_Log("INIT", "Context OK");

   // 4. Сессионные уровни
   if(!SESS_Init())
   {
      Print("[INIT] Sessions init FAILED!");
      return INIT_FAILED;
   }
   DIAG_Log("INIT", "Sessions OK");

   // 5. Market Levels
   if(!MKTL_Init())
   {
      Print("[INIT] Market Levels init FAILED!");
      return INIT_FAILED;
   }
   DIAG_Log("INIT", "Market Levels OK");

   // 6. Агенты 1-5
   if(!AGT_Init())
   {
      Print("[INIT] Agents 1-5 init FAILED!");
      return INIT_FAILED;
   }
   DIAG_Log("INIT", "Agents 1-5 OK");

   // 7. Агенты 6-9
   if(!AGTX_Init())
   {
      Print("[INIT] Agents 6-9 init FAILED!");
      return INIT_FAILED;
   }
   DIAG_Log("INIT", "Agents 6-9 OK");

   // 8. Агент 10 Fib Pivot
   if(!FibPivot_Init())
   {
      Print("[INIT] FibPivot init FAILED!");
      return INIT_FAILED;
   }
   DIAG_Log("INIT", "FibPivot OK");

   // 9. Сетапы
   SETUP_Init();

   // 10. Журнал
   Journal_Init();
   DIAG_Log("INIT", "Journal: " + g_journalFile);

   // 11. Новости
   News_Init();
   DIAG_Log("INIT", "News OK");

   // 12. Q-Learning
   QL_Init();

   // 13. TWAP
   TWAP_Init();

   // 14. Панель
   PP_UICreate();
   DIAG_Log("INIT", "Panel OK");

   // 15. Таймер (обновление новостей раз в час)
   EventSetTimer(3600);

   // 16. Trade настройки
   g_trade.SetExpertMagicNumber(MAGIC_NUMBER);
   g_trade.SetDeviationInPoints(10);
   g_trade.SetTypeFilling(ORDER_FILLING_FOK);

   // Инициализация символа
   g_symInfo.Name(_Symbol);
   g_symInfo.Refresh();

   // Обнулить дневные счётчики
   g_dailyTradeCount = 0;
   g_dailyPnL = 0;
   g_lastDay = iTime(_Symbol, PERIOD_D1, 0);

   Print("==========================================");
   Print("Claude_v600 Initialization COMPLETE");
   Print("Agents: ", MAX_AGENTS, " | Threshold: ", EntryThreshold,
         " | MinAgree: ", MinAgentsAgree);
   Print("==========================================");

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                    |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("[DEINIT] Claude_v600 stopping. Reason: ", reason);

   // Панель
   PP_UIDestroy();

   // Таймер
   EventKillTimer();

   // Модули
   CTX_Deinit();
   SESS_Deinit();
   MKTL_Deinit();
   AGT_Deinit();
   AGTX_Deinit();
   FibPivot_Deinit();
   News_Deinit();
   QL_Deinit();
   DIAG_Deinit();

   Print("[DEINIT] Claude_v600 stopped.");
}

//+------------------------------------------------------------------+
//| Expert tick function                                                |
//+------------------------------------------------------------------+
void OnTick()
{
   // === КАЖДЫЙ ТИК: обновить P&L и панель цен ===
   PP_UIUpdatePrices();

   // TWAP обработка
   if(EnableTWAP)
      TWAP_OnTick(g_trade);

   // === РАЗ В БАР: основная логика ===
   datetime bt = iTime(_Symbol, _Period, 0);
   if(bt == g_lastBar) return;
   g_lastBar = bt;

   // Проверить новый день
   datetime curDay = iTime(_Symbol, PERIOD_D1, 0);
   if(curDay != g_lastDay)
   {
      g_dailyTradeCount = 0;
      g_dailyPnL = 0;
      g_lastDay = curDay;
   }

   // Дневной лимит сделок
   if(g_dailyTradeCount >= 5)
   {
      DIAG_Log("MAIN", "Daily trade limit reached (5)");
      return;
   }

   // Дневной стоп
   if(g_dailyPnL <= -3.0)
   {
      DIAG_Log("MAIN", "Daily stop reached (-3R)");
      return;
   }

   // 1. Обновить контекст
   CTX_Update(g_ctx);

   // 2. Обновить сессии
   SESS_Update(g_ctx);

   // 3. Обновить рыночные уровни
   MKTL_Update();

   // 4. Обновить новости
   if(EnableNewsCalendar)
   {
      News_UpdateContext(g_ctx);

      // Отрисовать линии новостей
      if(DrawNewsLines) News_DrawOnChart();

      // Обновить панель новостей
      if(ShowNewsOnPanel)
      {
         g_uiNewsCount = News_GetUpcoming(g_uiNewsTitle, g_uiNewsMinutes,
                                            g_uiNewsImpact, MAX_NEWS_DISPLAY);
         PP_UIUpdateNewsBlock();
      }
   }

   // 5. Запустить агентов (если система включена)
   if(EnableAgentSystem)
   {
      // Агенты 1-5
      AGT_RunAll(g_signals, g_ctx);

      // Агенты 6-9
      AGTX_RunAll(g_signals, g_ctx);

      // Агент 10: Fib Pivot
      FibPivot_RunAgent(g_signals, g_ctx);

      // 6. Принять решение
      DEC_MakeDecision(g_signals, MAX_AGENTS, g_ctx, g_decision);

      // 7. Детекция сетапов
      if(EnableSetupDetection)
         SETUP_Detect(g_signals, g_ctx);

      // 8. Обновить панель агентов
      if(ShowAgentPanel)
      {
         for(int i = 0; i < MAX_AGENTS; i++)
         {
            g_uiAgentNames[i]  = g_signals[i].name;
            g_uiAgentScores[i] = g_signals[i].score;
         }
         g_uiAgentCount       = MAX_AGENTS;
         g_uiDecShouldTrade   = g_decision.shouldTrade;
         g_uiDecDirection     = g_decision.direction;
         g_uiDecRiskMultiple  = g_decision.riskMultiple;
         g_uiDecWeightedScore = g_decision.weightedScore;

         // Setup текст
         g_uiSetupText = SETUP_GetCurrentName();
         g_uiSetupActive = SETUP_IsActive();

         // Pivot zone текст
         if(Agent_FibPivot_Enabled && ShowPivotZoneOnPanel)
         {
            g_uiPivotZoneText = "Pivot Zone: " +
               FibPivot_ZoneName(g_fib.w_zone, g_fib.w_bias) +
               " " + ((g_fib.w_bias > 0) ? "^" : "v") +
               " | Near: " + g_fib.nearest_level;
         }

         PP_UIUpdateAgentBlock();
      }

      // 9. Q-Learning
      if(EnableQLearning)
         QL_OnBar(g_ctx, g_decision);

      // 10. Журнал
      if(EnableJournal)
         Journal_LogSignal(g_signals, g_ctx, g_decision);

      // 11. Торговля
      if(g_decision.shouldTrade)
      {
         ExecuteTrade(g_decision);
      }
   }

   // Диагностика
   DIAG_OnBar();

   // Перерисовать график
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Timer function                                                      |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Обновить новости раз в час
   if(EnableNewsCalendar)
      News_Download();
}

//+------------------------------------------------------------------+
//| Chart event handler                                                 |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam,
                   const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      PP_UIHandleClick(sparam);
      ChartRedraw(0);
   }
}

//+------------------------------------------------------------------+
//| Исполнить торговлю                                                 |
//+------------------------------------------------------------------+
void ExecuteTrade(TradeDecision &dec)
{
   // Проверить дневной лимит
   if(g_dailyTradeCount >= 5)
   {
      DIAG_Log("TRADE", "Daily limit reached. Skip.");
      return;
   }

   // Расчёт лота
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * TotalRiskPct / 100.0;
   double slPips = SL_Pips4 * _Point;
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   if(slPips <= 0 || tickValue <= 0 || tickSize <= 0)
   {
      DIAG_LogLevel("TRADE", "Invalid SL/tick params", 2);
      return;
   }

   double lotCalc = riskAmount / (slPips / tickSize * tickValue);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lotCalc = MathFloor(lotCalc / lotStep) * lotStep;

   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   lotCalc = MathMax(minLot, MathMin(maxLot, lotCalc));

   // Цены
   g_symInfo.Refresh();
   double ask = g_symInfo.Ask();
   double bid = g_symInfo.Bid();

   double price, sl, tp;
   string comment = "CV6_" + dec.setupClass + "_" +
                     IntegerToString(dec.riskMultiple) + "R";

   if(dec.direction > 0)  // BUY
   {
      price = ask;
      sl = NormalizeDouble(price - slPips, _Digits);
      tp = NormalizeDouble(price + slPips * dec.riskMultiple, _Digits);

      // TWAP или прямой ордер
      if(EnableTWAP && TWAP_Slices > 1)
      {
         TWAP_Start(+1, lotCalc, sl, tp);
      }
      else
      {
         if(g_trade.Buy(lotCalc, _Symbol, price, sl, tp, comment))
         {
            string tradeId = IntegerToString(g_trade.ResultOrder());
            g_dailyTradeCount++;

            DIAG_LogTrade("BUY", _Symbol, lotCalc, price, sl, tp);

            if(EnableJournal)
               Journal_LogTrade(tradeId, "LONG", price, sl, tp, lotCalc, slPips);
         }
         else
         {
            DIAG_LogLevel("TRADE", "BUY failed: " + IntegerToString(GetLastError()), 2);
         }
      }
   }
   else if(dec.direction < 0)  // SELL
   {
      price = bid;
      sl = NormalizeDouble(price + slPips, _Digits);
      tp = NormalizeDouble(price - slPips * dec.riskMultiple, _Digits);

      if(EnableTWAP && TWAP_Slices > 1)
      {
         TWAP_Start(-1, lotCalc, sl, tp);
      }
      else
      {
         if(g_trade.Sell(lotCalc, _Symbol, price, sl, tp, comment))
         {
            string tradeId = IntegerToString(g_trade.ResultOrder());
            g_dailyTradeCount++;

            DIAG_LogTrade("SELL", _Symbol, lotCalc, price, sl, tp);

            if(EnableJournal)
               Journal_LogTrade(tradeId, "SHORT", price, sl, tp, lotCalc, slPips);
         }
         else
         {
            DIAG_LogLevel("TRADE", "SELL failed: " + IntegerToString(GetLastError()), 2);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Trade event handler (отслеживание закрытий)                        |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                         const MqlTradeRequest &request,
                         const MqlTradeResult &result)
{
   // Отслеживаем закрытие позиций для журнала и Q-Learning
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
   {
      ulong dealTicket = trans.deal;

      if(HistoryDealSelect(dealTicket))
      {
         long entry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);

         if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_INOUT)
         {
            double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
            double commission = HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
            double swap = HistoryDealGetDouble(dealTicket, DEAL_SWAP);
            double totalPnL = profit + commission + swap;

            // Рассчитать PnL в R
            double slPips = SL_Pips4 * _Point;
            double riskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * TotalRiskPct / 100.0;
            double pnlR = (riskAmount > 0) ? totalPnL / riskAmount : 0;

            g_dailyPnL += pnlR;

            // Журнал
            if(EnableJournal)
            {
               string tradeId = IntegerToString(trans.order);
               Journal_LogClose(tradeId, trans.price, totalPnL, pnlR, 0, "Market");
            }

            // Q-Learning
            if(EnableQLearning)
               QL_OnTradeClose(g_ctx, pnlR);

            DIAG_Log("TRADE", "Closed. PnL=$" + DoubleToString(totalPnL, 2) +
                     " (" + DoubleToString(pnlR, 2) + "R)");
         }
      }
   }
}
//+------------------------------------------------------------------+
