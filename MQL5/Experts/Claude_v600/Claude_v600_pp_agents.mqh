#ifndef __CLAUDE_V600_PP_AGENTS_MQH__
#define __CLAUDE_V600_PP_AGENTS_MQH__
#property strict

// ==================== АГЕНТЫ 1-5 (ОРИГИНАЛЬНЫЕ) ====================
// [0] VWAP Pullback
// [1] Supply/Demand Deviation
// [2] Structure
// [3] Momentum
// [4] Context Filter (множитель, НЕ голосует)

// Хэндлы индикаторов для агентов
int g_hRSI_agt    = INVALID_HANDLE;
int g_hMA20_agt   = INVALID_HANDLE;
int g_hMA50_agt   = INVALID_HANDLE;
int g_hMACD_agt   = INVALID_HANDLE;

// Буферы
double g_bufRSI[];
double g_bufMA20[], g_bufMA50[];
double g_bufMACDMain[], g_bufMACDSignal[];

//+------------------------------------------------------------------+
//| Инициализация агентов 1-5                                          |
//+------------------------------------------------------------------+
bool AGT_Init()
{
   if(!EnableAgentSystem) return true;

   g_hRSI_agt  = iRSI(_Symbol, _Period, 14, PRICE_CLOSE);
   g_hMA20_agt = iMA(_Symbol, _Period, 20, 0, MODE_SMA, PRICE_CLOSE);
   g_hMA50_agt = iMA(_Symbol, _Period, 50, 0, MODE_SMA, PRICE_CLOSE);
   g_hMACD_agt = iMACD(_Symbol, _Period, 12, 26, 9, PRICE_CLOSE);

   if(g_hRSI_agt == INVALID_HANDLE || g_hMA20_agt == INVALID_HANDLE ||
      g_hMA50_agt == INVALID_HANDLE || g_hMACD_agt == INVALID_HANDLE)
   {
      Print("[AGT] Failed to create indicator handles! Error: ", GetLastError());
      return false;
   }

   ArraySetAsSeries(g_bufRSI, true);
   ArraySetAsSeries(g_bufMA20, true);
   ArraySetAsSeries(g_bufMA50, true);
   ArraySetAsSeries(g_bufMACDMain, true);
   ArraySetAsSeries(g_bufMACDSignal, true);

   return true;
}

//+------------------------------------------------------------------+
//| Деинициализация                                                    |
//+------------------------------------------------------------------+
void AGT_Deinit()
{
   if(g_hRSI_agt != INVALID_HANDLE)  IndicatorRelease(g_hRSI_agt);
   if(g_hMA20_agt != INVALID_HANDLE) IndicatorRelease(g_hMA20_agt);
   if(g_hMA50_agt != INVALID_HANDLE) IndicatorRelease(g_hMA50_agt);
   if(g_hMACD_agt != INVALID_HANDLE) IndicatorRelease(g_hMACD_agt);

   g_hRSI_agt  = INVALID_HANDLE;
   g_hMA20_agt = INVALID_HANDLE;
   g_hMA50_agt = INVALID_HANDLE;
   g_hMACD_agt = INVALID_HANDLE;
}

//+------------------------------------------------------------------+
//| Агент 0: VWAP Pullback                                            |
//| Оценивает отклонение цены от VWAP и возврат к нему                 |
//+------------------------------------------------------------------+
void AGT_VWAP_Pullback(AgentSignal &sig, MarketContext &ctx)
{
   sig.name = "VWAP PB";
   sig.enabled = Agent_VWAP_Enabled;
   sig.weight = 1.0;
   sig.confidence = 0.7;
   sig.score = 0;

   if(!sig.enabled) return;

   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // Используем MA20 как прокси для VWAP (если индикатор VWAP не подключён)
   if(CopyBuffer(g_hMA20_agt, 0, 0, 3, g_bufMA20) < 3) return;

   double vwap = g_bufMA20[0];
   double vwapPrev = g_bufMA20[1];
   double deviation = (price - vwap) / (_Point * 10.0);  // В пипсах

   // Pullback к VWAP
   if(MathAbs(deviation) < 5.0)
   {
      // У VWAP — нейтрально, ждём направление
      sig.score = 0;
      sig.confidence = 0.3;
   }
   else if(deviation > 5.0 && deviation < 30.0)
   {
      // Выше VWAP — ищем продолжение покупок если тренд вверх
      if(ctx.regime <= 1)
         sig.score = (int)(30 + deviation);  // Бычий
      else
         sig.score = -(int)(deviation * 0.5);  // Перекуплен
   }
   else if(deviation < -5.0 && deviation > -30.0)
   {
      // Ниже VWAP
      if(ctx.regime >= 4)
         sig.score = -(int)(30 + MathAbs(deviation));  // Медвежий
      else
         sig.score = (int)(MathAbs(deviation) * 0.5);  // Перепродан
   }
   else
   {
      // Экстремальное отклонение — контр-тренд
      sig.score = -(int)(deviation * 0.3);
      sig.confidence = 0.5;
   }

   // Ограничение
   sig.score = MathMax(-100, MathMin(100, sig.score));
}

//+------------------------------------------------------------------+
//| Агент 1: Supply/Demand Deviation                                   |
//| Оценивает уровни поддержки/сопротивления                           |
//+------------------------------------------------------------------+
void AGT_SD_Deviation(AgentSignal &sig, MarketContext &ctx)
{
   sig.name = "SD Dev";
   sig.enabled = Agent_SD_Enabled;
   sig.weight = 1.0;
   sig.confidence = 0.6;
   sig.score = 0;

   if(!sig.enabled) return;

   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point10 = _Point * 10.0;

   // Используем PDH/PDL + Session levels как зоны S/D
   double distPDH = (ctx.pdh > 0) ? (price - ctx.pdh) / point10 : 999;
   double distPDL = (ctx.pdl > 0) ? (price - ctx.pdl) / point10 : -999;

   // Вблизи PDH (сопротивление)
   if(MathAbs(distPDH) < 10)
   {
      if(distPDH > 0)
         sig.score = 30;   // Пробил сопротивление — бычий
      else
         sig.score = -40;  // Подошёл к сопротивлению — медвежий
      sig.confidence = 0.8;
   }
   // Вблизи PDL (поддержка)
   else if(MathAbs(distPDL) < 10)
   {
      if(distPDL < 0)
         sig.score = -30;  // Пробил поддержку — медвежий
      else
         sig.score = 40;   // Подошёл к поддержке — бычий
      sig.confidence = 0.8;
   }
   else
   {
      // Между уровнями — оценка по положению
      double range = ctx.pdh - ctx.pdl;
      if(range > 0)
      {
         double pos = (price - ctx.pdl) / range;  // 0..1
         sig.score = (int)((0.5 - pos) * 60);     // Ниже середины = бычий
      }
      sig.confidence = 0.5;
   }

   // Asia/London levels как дополнительные S/D
   if(ctx.asia_high > 0 && ctx.asia_low > 0)
   {
      double distAsiaH = (price - ctx.asia_high) / point10;
      double distAsiaL = (price - ctx.asia_low) / point10;

      if(MathAbs(distAsiaH) < 5)
         sig.score += (distAsiaH > 0) ? 10 : -10;
      if(MathAbs(distAsiaL) < 5)
         sig.score += (distAsiaL < 0) ? -10 : 10;
   }

   sig.score = MathMax(-100, MathMin(100, sig.score));
}

//+------------------------------------------------------------------+
//| Агент 2: Structure                                                 |
//| Оценивает рыночную структуру (HH/HL/LH/LL)                        |
//+------------------------------------------------------------------+
void AGT_Structure(AgentSignal &sig, MarketContext &ctx)
{
   sig.name = "Structure";
   sig.enabled = Agent_Structure_Enabled;
   sig.weight = 1.0;
   sig.confidence = 0.7;
   sig.score = 0;

   if(!sig.enabled) return;

   // Анализ последних swing points
   double high[], low[];
   int barsNeeded = 30;
   if(CopyHigh(_Symbol, _Period, 0, barsNeeded, high) < barsNeeded) return;
   if(CopyLow(_Symbol, _Period, 0, barsNeeded, low) < barsNeeded) return;

   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);

   // Найти последние 4 swing points
   double swingHighs[4], swingLows[4];
   int shCount = 0, slCount = 0;

   for(int i = 2; i < barsNeeded - 2 && (shCount < 4 || slCount < 4); i++)
   {
      // Swing High
      if(shCount < 4 && high[i] > high[i-1] && high[i] > high[i-2] &&
         high[i] > high[i+1] && high[i] > high[i+2])
      {
         swingHighs[shCount++] = high[i];
      }
      // Swing Low
      if(slCount < 4 && low[i] < low[i-1] && low[i] < low[i-2] &&
         low[i] < low[i+1] && low[i] < low[i+2])
      {
         swingLows[slCount++] = low[i];
      }
   }

   if(shCount >= 2 && slCount >= 2)
   {
      bool higherHighs = (swingHighs[0] > swingHighs[1]);
      bool higherLows  = (swingLows[0] > swingLows[1]);
      bool lowerHighs  = (swingHighs[0] < swingHighs[1]);
      bool lowerLows   = (swingLows[0] < swingLows[1]);

      if(higherHighs && higherLows)
      {
         sig.score = 60;    // Бычья структура (HH + HL)
         sig.confidence = 0.8;
      }
      else if(lowerHighs && lowerLows)
      {
         sig.score = -60;   // Медвежья структура (LH + LL)
         sig.confidence = 0.8;
      }
      else if(higherHighs && lowerLows)
      {
         sig.score = 10;    // Расширяющийся рейндж
         sig.confidence = 0.4;
      }
      else if(lowerHighs && higherLows)
      {
         sig.score = 0;     // Сжимающийся рейндж (triangle)
         sig.confidence = 0.3;
      }
   }

   // MA50 подтверждение
   if(CopyBuffer(g_hMA50_agt, 0, 0, 1, g_bufMA50) >= 1)
   {
      double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(price > g_bufMA50[0] && sig.score > 0)
         sig.score += 15;  // Подтверждение бычьей структуры
      else if(price < g_bufMA50[0] && sig.score < 0)
         sig.score -= 15;  // Подтверждение медвежьей структуры
   }

   sig.score = MathMax(-100, MathMin(100, sig.score));
}

//+------------------------------------------------------------------+
//| Агент 3: Momentum                                                  |
//| RSI + MACD моментум                                                |
//+------------------------------------------------------------------+
void AGT_Momentum(AgentSignal &sig, MarketContext &ctx)
{
   sig.name = "Momentum";
   sig.enabled = Agent_Momentum_Enabled;
   sig.weight = 1.0;
   sig.confidence = 0.6;
   sig.score = 0;

   if(!sig.enabled) return;

   if(CopyBuffer(g_hRSI_agt, 0, 0, 10, g_bufRSI) < 10) return;
   if(CopyBuffer(g_hMACD_agt, 0, 0, 3, g_bufMACDMain) < 3) return;
   if(CopyBuffer(g_hMACD_agt, 1, 0, 3, g_bufMACDSignal) < 3) return;

   double rsi = g_bufRSI[0];
   double rsiPrev = g_bufRSI[1];
   double macdMain = g_bufMACDMain[0];
   double macdSignal = g_bufMACDSignal[0];
   double macdMainPrev = g_bufMACDMain[1];
   double macdSignalPrev = g_bufMACDSignal[1];

   int rsiScore = 0;
   int macdScore = 0;

   // RSI
   if(rsi > 70)
   {
      rsiScore = -30;          // Перекуплен
      if(rsi < rsiPrev) rsiScore = -50;  // Разворот вниз
   }
   else if(rsi < 30)
   {
      rsiScore = 30;           // Перепродан
      if(rsi > rsiPrev) rsiScore = 50;   // Разворот вверх
   }
   else if(rsi > 50)
   {
      rsiScore = (int)((rsi - 50) * 1.0);  // Умеренно бычий
   }
   else
   {
      rsiScore = (int)((rsi - 50) * 1.0);  // Умеренно медвежий
   }

   // MACD
   if(macdMain > macdSignal)
   {
      macdScore = 30;
      if(macdMainPrev <= macdSignalPrev)
         macdScore = 50;  // Свежий кроссовер вверх
   }
   else
   {
      macdScore = -30;
      if(macdMainPrev >= macdSignalPrev)
         macdScore = -50;  // Свежий кроссовер вниз
   }

   // Комбинация
   sig.score = (rsiScore + macdScore) / 2;

   // Дивергенция RSI vs цена
   double high2[];
   if(CopyHigh(_Symbol, _Period, 0, 10, high2) >= 10)
   {
      ArraySetAsSeries(high2, true);
      if(high2[0] > high2[5] && g_bufRSI[0] < g_bufRSI[5])
      {
         sig.score -= 20;  // Медвежья дивергенция
         sig.confidence = 0.8;
      }
   }

   sig.score = MathMax(-100, MathMin(100, sig.score));
}

//+------------------------------------------------------------------+
//| Агент 4: Context Filter (множитель, НЕ голосует)                   |
//+------------------------------------------------------------------+
void AGT_ContextFilter(AgentSignal &sig, MarketContext &ctx)
{
   sig.name = "CtxFilter";
   sig.enabled = Agent_Context_Enabled;
   sig.weight = 0.0;  // Не голосует!
   sig.confidence = 1.0;

   // Score = множитель * 100 (для отображения)
   sig.score = (int)(ctx.context_multiplier * 100);
}

//+------------------------------------------------------------------+
//| Запустить все агенты 1-5                                           |
//+------------------------------------------------------------------+
void AGT_RunAll(AgentSignal &signals[], MarketContext &ctx)
{
   if(!EnableAgentSystem) return;

   AGT_VWAP_Pullback(signals[0], ctx);
   AGT_SD_Deviation(signals[1], ctx);
   AGT_Structure(signals[2], ctx);
   AGT_Momentum(signals[3], ctx);
   AGT_ContextFilter(signals[4], ctx);
}

#endif
