#ifndef __CLAUDE_V600_PP_CONTEXT_MQH__
#define __CLAUDE_V600_PP_CONTEXT_MQH__
#property strict

// ==================== КОНТЕКСТ РЫНКА ====================
// MarketContext — центральная структура данных

struct MarketContext
{
   // Базовые
   int    regime;            // 0=StrongUp,1=Up,2=RangeUp,3=RangeDown,4=Down,5=StrongDown
   int    session;           // SESSION_SYDNEY..SESSION_NY_LONDON
   int    day_type;          // 0=Trend, 1=Range, 2=Expansion
   double adx;
   double atr;
   double atr_ratio;         // ATR / среднее ATR
   double spread_pips;
   double price_vs_vwap;     // В пипсах, знаковое
   double adr_position;      // 0.0-1.0, где цена в дневном рейндже
   bool   is_kill_zone;
   int    hour_gmt;
   int    day_of_week;
   int    ema_position;      // +1=выше, -1=ниже, 0=на EMA
   double context_multiplier;// Итоговый множитель CtxFilter

   // Индикаторы (заполняются агентами)
   int    bv_type;           // BV_NEUTRAL..BV_CLIMAX_CHURN
   int    pvsra_type;        // PVSRA_NORMAL..PVSRA_BEAR_CLIMAX
   double rei_value;         // -100..+100
   double wpr1, wpr2, wpr3, wpr4;  // Значения WPR
   double volume_ratio;      // Текущий объём / средний

   // Уровни
   double pdh, pdl;          // Previous Day High/Low
   double asia_high, asia_low;
   double london_high, london_low;
   double midnight_open;
   double prev_ny_close;

   // Новости
   int    news_minutes_to;   // Минут до ближайшей High Impact
   int    news_impact;       // 0-3 ближайшей
   string news_title;        // Название ближайшей

   // Fib Pivot
   double pivot_weekly;
   int    pivot_zone;        // Зона 0-5
   int    pivot_bias;        // +1/-1
   double pivot_daily;
   int    pivot_daily_zone;
   double pivot_nearest_r;
   double pivot_nearest_s;
   string pivot_nearest_name;
   bool   pivot_confluence;
   double adr_used_pct;
};

// Глобальные хэндлы индикаторов для контекста
int g_hATR_ctx = INVALID_HANDLE;
int g_hADX_ctx = INVALID_HANDLE;
int g_hEMA_ctx = INVALID_HANDLE;

// Буферы
double g_bufATR[];
double g_bufADXMain[], g_bufADXPlus[], g_bufADXMinus[];
double g_bufEMA[];

// Средний ATR для ratio
double g_avgATR = 0;
int    g_atrSamples = 0;

//+------------------------------------------------------------------+
//| Получить период EMA в зависимости от таймфрейма                    |
//+------------------------------------------------------------------+
int GetEMAPeriod()
{
   int tfMin = PeriodSeconds(_Period) / 60;
   if(tfMin <= 1)  return 200;
   if(tfMin <= 5)  return 100;
   if(tfMin <= 15) return 50;
   if(tfMin <= 60) return 34;
   return 21;
}

//+------------------------------------------------------------------+
//| Получить минуты периода                                            |
//+------------------------------------------------------------------+
int GetPeriodMinutes()
{
   return PeriodSeconds(_Period) / 60;
}

//+------------------------------------------------------------------+
//| Инициализация контекста                                            |
//+------------------------------------------------------------------+
bool CTX_Init()
{
   if(!EnableContextAnalysis) return true;

   g_hATR_ctx = iATR(_Symbol, _Period, ATR_Period);
   g_hADX_ctx = iADX(_Symbol, _Period, ADX_Period);
   g_hEMA_ctx = iMA(_Symbol, _Period, GetEMAPeriod(), 0, MODE_EMA, PRICE_CLOSE);

   if(g_hATR_ctx == INVALID_HANDLE || g_hADX_ctx == INVALID_HANDLE ||
      g_hEMA_ctx == INVALID_HANDLE)
   {
      Print("[CTX] Failed to create indicator handles! Error: ", GetLastError());
      return false;
   }

   ArraySetAsSeries(g_bufATR, true);
   ArraySetAsSeries(g_bufADXMain, true);
   ArraySetAsSeries(g_bufADXPlus, true);
   ArraySetAsSeries(g_bufADXMinus, true);
   ArraySetAsSeries(g_bufEMA, true);

   g_avgATR = 0;
   g_atrSamples = 0;

   return true;
}

//+------------------------------------------------------------------+
//| Деинициализация контекста                                          |
//+------------------------------------------------------------------+
void CTX_Deinit()
{
   if(g_hATR_ctx != INVALID_HANDLE) IndicatorRelease(g_hATR_ctx);
   if(g_hADX_ctx != INVALID_HANDLE) IndicatorRelease(g_hADX_ctx);
   if(g_hEMA_ctx != INVALID_HANDLE) IndicatorRelease(g_hEMA_ctx);

   g_hATR_ctx = INVALID_HANDLE;
   g_hADX_ctx = INVALID_HANDLE;
   g_hEMA_ctx = INVALID_HANDLE;
}

//+------------------------------------------------------------------+
//| Определить текущую сессию по GMT часу                               |
//+------------------------------------------------------------------+
int CTX_DetectSession(int hourGMT)
{
   // Sydney: 22-07 GMT
   // Tokyo: 00-09 GMT
   // London: 07-16 GMT
   // NY: 12-21 GMT

   bool sydney = (hourGMT >= 22 || hourGMT < 7);
   bool tokyo  = (hourGMT >= 0 && hourGMT < 9);
   bool london = (hourGMT >= 7 && hourGMT < 16);
   bool ny     = (hourGMT >= 12 && hourGMT < 21);

   if(london && ny) return SESSION_NY_LONDON;
   if(sydney && tokyo) return SESSION_SYDNEY_TOKYO;
   if(ny) return SESSION_NY;
   if(london) return SESSION_LONDON;
   if(tokyo) return SESSION_TOKYO;
   if(sydney) return SESSION_SYDNEY;

   return SESSION_SYDNEY; // По умолчанию
}

//+------------------------------------------------------------------+
//| Определить режим рынка                                             |
//+------------------------------------------------------------------+
int CTX_DetectRegime(double adx, double plusDI, double minusDI)
{
   // 0=StrongUp, 1=Up, 2=RangeUp, 3=RangeDown, 4=Down, 5=StrongDown
   bool trend = (adx > TrendThreshold);
   bool bullish = (plusDI > minusDI);

   if(trend)
   {
      if(bullish)
         return (adx > TrendThreshold * 1.5) ? 0 : 1;  // StrongUp / Up
      else
         return (adx > TrendThreshold * 1.5) ? 5 : 4;  // StrongDown / Down
   }
   else
   {
      return bullish ? 2 : 3;  // RangeUp / RangeDown
   }
}

//+------------------------------------------------------------------+
//| Определить тип дня                                                 |
//+------------------------------------------------------------------+
int CTX_DetectDayType(double atr, double avgATR)
{
   double ratio = (avgATR > 0) ? atr / avgATR : 1.0;

   if(ratio > 1.3)  return 2;  // Expansion
   if(ratio < 0.7)  return 1;  // Range
   return 0;                    // Trend
}

//+------------------------------------------------------------------+
//| Kill Zone проверка                                                 |
//+------------------------------------------------------------------+
bool CTX_IsKillZone(int hourGMT)
{
   // London Kill Zone: 07:00-10:00 GMT
   if(hourGMT >= 7 && hourGMT < 10) return true;

   // NY Kill Zone: 12:00-15:00 GMT
   if(hourGMT >= 12 && hourGMT < 15) return true;

   return false;
}

//+------------------------------------------------------------------+
//| Обновить контекст (вызывается раз в бар)                           |
//+------------------------------------------------------------------+
void CTX_Update(MarketContext &ctx)
{
   if(!EnableContextAnalysis) return;

   // Копируем данные индикаторов
   if(CopyBuffer(g_hATR_ctx, 0, 0, 1, g_bufATR) < 1) return;
   if(CopyBuffer(g_hADX_ctx, 0, 0, 1, g_bufADXMain) < 1) return;
   if(CopyBuffer(g_hADX_ctx, 1, 0, 1, g_bufADXPlus) < 1) return;
   if(CopyBuffer(g_hADX_ctx, 2, 0, 1, g_bufADXMinus) < 1) return;
   if(CopyBuffer(g_hEMA_ctx, 0, 0, 1, g_bufEMA) < 1) return;

   ctx.atr = g_bufATR[0];
   ctx.adx = g_bufADXMain[0];

   // Обновить среднее ATR
   g_atrSamples++;
   g_avgATR = g_avgATR + (ctx.atr - g_avgATR) / g_atrSamples;
   ctx.atr_ratio = (g_avgATR > 0) ? ctx.atr / g_avgATR : 1.0;

   // Спред
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   ctx.spread_pips = (ask - bid) / (point * 10.0);

   // GMT час
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   ctx.hour_gmt = (dt.hour - BrokerGMTOffsetHours + 24) % 24;
   ctx.day_of_week = dt.day_of_week;

   // Режим рынка
   ctx.regime = CTX_DetectRegime(ctx.adx, g_bufADXPlus[0], g_bufADXMinus[0]);

   // Сессия
   ctx.session = CTX_DetectSession(ctx.hour_gmt);

   // Тип дня
   ctx.day_type = CTX_DetectDayType(ctx.atr, g_avgATR);

   // Kill Zone
   ctx.is_kill_zone = CTX_IsKillZone(ctx.hour_gmt);

   // EMA позиция
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double emaVal = g_bufEMA[0];
   double emaTol = ctx.atr * 0.1; // 10% ATR толерантность

   if(price > emaVal + emaTol)
      ctx.ema_position = +1;
   else if(price < emaVal - emaTol)
      ctx.ema_position = -1;
   else
      ctx.ema_position = 0;

   // ADR позиция (0.0-1.0)
   double todayHigh = iHigh(_Symbol, PERIOD_D1, 0);
   double todayLow  = iLow(_Symbol, PERIOD_D1, 0);
   double todayRange = todayHigh - todayLow;
   if(todayRange > 0)
      ctx.adr_position = (price - todayLow) / todayRange;
   else
      ctx.adr_position = 0.5;

   // PDH/PDL
   ctx.pdh = iHigh(_Symbol, PERIOD_D1, 1);
   ctx.pdl = iLow(_Symbol, PERIOD_D1, 1);

   // ADR used pct
   double adr14 = 0;
   for(int i = 1; i <= ADR_Days; i++)
      adr14 += iHigh(_Symbol, PERIOD_D1, i) - iLow(_Symbol, PERIOD_D1, i);
   adr14 /= ADR_Days;
   ctx.adr_used_pct = (adr14 > 0) ? (todayRange / adr14) * 100.0 : 0;

   // Context multiplier (БАЗОВЫЙ = 1.0!)
   ctx.context_multiplier = CTX_CalcMultiplier(ctx);
}

//+------------------------------------------------------------------+
//| Рассчитать множитель контекста                                     |
//| КРИТИЧЕСКОЕ: базовый = 1.0 (НЕ ноль!)                             |
//+------------------------------------------------------------------+
double CTX_CalcMultiplier(MarketContext &ctx)
{
   double mult = 1.0;  // БАЗОВЫЙ = 1.0

   // Kill Zone бонус
   if(ctx.is_kill_zone)
      mult *= 1.3;     // +30% в Kill Zone
   else
      mult *= 0.7;     // -30% вне Kill Zone (НЕ ноль!)

   // Блокировка (только в экстремальных случаях)
   if(ctx.day_of_week == 5 && ctx.hour_gmt >= 15)
      mult = 0.0;      // Пятница после 15:00 UTC → СТОП

   if(ctx.spread_pips > ctx.atr * 3.0 && ctx.atr > 0)
      mult = 0.0;      // Спред > 3× ATR → СТОП

   // Новости (если модуль включён)
   if(EnableNewsCalendar && ctx.news_minutes_to >= 0)
   {
      if(ctx.news_impact >= 3 && ctx.news_minutes_to <= HighImpactBuffer_Min)
         mult = 0.0;   // Блок перед High Impact
      else if(ctx.news_impact >= 2 && ctx.news_minutes_to <= MedImpactBuffer_Min)
         mult *= 0.3;  // Сильное ослабление перед Medium
   }

   // Сессия — бонус за перекрытие
   if(ctx.session == SESSION_NY_LONDON)
      mult *= 1.2;

   return mult;
}

//+------------------------------------------------------------------+
//| Получить строковое имя режима                                      |
//+------------------------------------------------------------------+
string CTX_RegimeName(int regime)
{
   switch(regime)
   {
      case 0: return "StrongUp";
      case 1: return "Up";
      case 2: return "RangeUp";
      case 3: return "RangeDown";
      case 4: return "Down";
      case 5: return "StrongDown";
   }
   return "Unknown";
}

//+------------------------------------------------------------------+
//| Получить строковое имя сессии                                      |
//+------------------------------------------------------------------+
string CTX_SessionName(int session)
{
   switch(session)
   {
      case SESSION_SYDNEY:      return "Sydney";
      case SESSION_TOKYO:       return "Tokyo";
      case SESSION_LONDON:      return "London";
      case SESSION_NY:          return "NewYork";
      case SESSION_SYDNEY_TOKYO:return "Syd+Tok";
      case SESSION_LONDON_NY:   return "Lon+NY";
      case SESSION_NY_LONDON:   return "NY+Lon";
   }
   return "Unknown";
}

#endif
