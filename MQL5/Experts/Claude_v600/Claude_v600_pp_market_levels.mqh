#ifndef __CLAUDE_V600_PP_MARKET_LEVELS_MQH__
#define __CLAUDE_V600_PP_MARKET_LEVELS_MQH__
#property strict

// ==================== РЫНОЧНЫЕ УРОВНИ ====================
// ADR (Average Daily Range), круглые уровни, US Session H/L

struct ADRData
{
   double adr_day;         // Средний дневной рейндж
   double adr_week;        // Средний недельный ход
   double adr_month;       // Средний месячный ход
   double adr_day_core;    // Квантиль core (80%)
   double adr_day_tail;    // Квантиль tail (95%)
   double adr_high;        // Верхняя граница ADR от открытия
   double adr_low;         // Нижняя граница ADR от открытия
   double today_open;
   double us_high;
   double us_low;
   datetime us_start;
   datetime us_end;
};

ADRData g_adr;

//+------------------------------------------------------------------+
//| Инициализация рыночных уровней                                     |
//+------------------------------------------------------------------+
bool MKTL_Init()
{
   if(!EnableMarketLevels) return true;

   ZeroMemory(g_adr);
   MKTL_CalcADR();

   return true;
}

//+------------------------------------------------------------------+
//| Деинициализация                                                    |
//+------------------------------------------------------------------+
void MKTL_Deinit()
{
   MKTL_DeleteObjects();
}

//+------------------------------------------------------------------+
//| Рассчитать ADR                                                     |
//+------------------------------------------------------------------+
void MKTL_CalcADR()
{
   // Daily ADR
   double ranges[];
   ArrayResize(ranges, ADR_Days);

   for(int i = 1; i <= ADR_Days; i++)
   {
      double h = iHigh(_Symbol, PERIOD_D1, i);
      double l = iLow(_Symbol, PERIOD_D1, i);
      ranges[i - 1] = h - l;
   }

   // Среднее
   g_adr.adr_day = 0;
   for(int i = 0; i < ADR_Days; i++)
      g_adr.adr_day += ranges[i];
   g_adr.adr_day /= ADR_Days;

   // Квантили — сортируем и берём
   ArraySort(ranges);
   int idxCore = (int)(ADR_Days * QuantileCore);
   int idxTail = (int)(ADR_Days * QuantileTail);
   if(idxCore >= ADR_Days) idxCore = ADR_Days - 1;
   if(idxTail >= ADR_Days) idxTail = ADR_Days - 1;
   g_adr.adr_day_core = ranges[idxCore];
   g_adr.adr_day_tail = ranges[idxTail];

   // Weekly move
   g_adr.adr_week = 0;
   int wkCount = MathMin(ADR_Weeks, iBars(_Symbol, PERIOD_W1) - 1);
   for(int i = 1; i <= wkCount; i++)
      g_adr.adr_week += iHigh(_Symbol, PERIOD_W1, i) - iLow(_Symbol, PERIOD_W1, i);
   if(wkCount > 0) g_adr.adr_week /= wkCount;

   // Monthly move
   g_adr.adr_month = 0;
   int mnCount = MathMin(ADR_Months, iBars(_Symbol, PERIOD_MN1) - 1);
   for(int i = 1; i <= mnCount; i++)
      g_adr.adr_month += iHigh(_Symbol, PERIOD_MN1, i) - iLow(_Symbol, PERIOD_MN1, i);
   if(mnCount > 0) g_adr.adr_month /= mnCount;

   // Today's open
   g_adr.today_open = iOpen(_Symbol, PERIOD_D1, 0);

   // ADR boundaries
   g_adr.adr_high = g_adr.today_open + g_adr.adr_day / 2.0;
   g_adr.adr_low  = g_adr.today_open - g_adr.adr_day / 2.0;
}

//+------------------------------------------------------------------+
//| Рассчитать US Session H/L                                          |
//+------------------------------------------------------------------+
void MKTL_CalcUSSession()
{
   if(!DrawUS_Session) return;

   g_adr.us_high = 0;
   g_adr.us_low = DBL_MAX;

   // US Session hours in broker time
   // Chicago -> UTC: +CME_UTC_Offset, UTC -> Broker: +BrokerGMTOffsetHours
   int usStartBroker = (US_StartHourChicago - CME_UTC_Offset + BrokerGMTOffsetHours + 24) % 24;
   int usEndBroker   = (US_EndHourChicago - CME_UTC_Offset + BrokerGMTOffsetHours + 24) % 24;

   int barsToScan = MathMin(iBars(_Symbol, _Period), 500);
   double high[], low[];
   datetime time[];

   if(CopyHigh(_Symbol, _Period, 0, barsToScan, high) < barsToScan) return;
   if(CopyLow(_Symbol, _Period, 0, barsToScan, low) < barsToScan) return;
   if(CopyTime(_Symbol, _Period, 0, barsToScan, time) < barsToScan) return;

   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(time, true);

   datetime todayStart = iTime(_Symbol, PERIOD_D1, 0);

   for(int i = 0; i < barsToScan; i++)
   {
      if(time[i] < todayStart) break;

      MqlDateTime dt;
      TimeToStruct(time[i], dt);

      // Проверяем в рамках US сессии
      bool inUS = false;
      if(usStartBroker < usEndBroker)
         inUS = (dt.hour >= usStartBroker && dt.hour < usEndBroker);
      else
         inUS = (dt.hour >= usStartBroker || dt.hour < usEndBroker);

      if(inUS)
      {
         if(high[i] > g_adr.us_high) g_adr.us_high = high[i];
         if(low[i] < g_adr.us_low)   g_adr.us_low = low[i];
      }
   }

   if(g_adr.us_low == DBL_MAX) g_adr.us_low = 0;
}

//+------------------------------------------------------------------+
//| Найти ближайший круглый уровень                                    |
//+------------------------------------------------------------------+
double MKTL_NearestRound(double price)
{
   double point10 = _Point * 10.0;
   int digits = _Digits;

   // Определить шаг круглого уровня (100 pips4 = 10 pips)
   double step;
   if(digits == 3 || digits == 5)
      step = 0.01;  // 100 pips4
   else if(digits == 2)
      step = 1.0;   // JPY пары
   else
      step = 0.01;

   double rounded = MathRound(price / step) * step;
   return NormalizeDouble(rounded, digits);
}

//+------------------------------------------------------------------+
//| Проверить: цена вблизи уровня?                                     |
//+------------------------------------------------------------------+
bool MKTL_IsNearLevel(double price, double level)
{
   double tolerance = NearLevelPips4 * _Point;
   return MathAbs(price - level) <= tolerance;
}

//+------------------------------------------------------------------+
//| Обновить рыночные уровни (раз в бар)                               |
//+------------------------------------------------------------------+
void MKTL_Update()
{
   if(!EnableMarketLevels) return;

   MKTL_CalcADR();
   MKTL_CalcUSSession();
   MKTL_DrawLevels();
}

//+------------------------------------------------------------------+
//| Рисовать уровни на графике                                         |
//+------------------------------------------------------------------+
void MKTL_DrawLevels()
{
   datetime t1 = iTime(_Symbol, PERIOD_D1, 0);
   datetime t2 = TimeCurrent() + PeriodSeconds(_Period) * 10;

   // ADR Day
   if(DrawADR_Day)
   {
      MKTL_DrawHLine("MKTL_ADR_H", g_adr.adr_high, clrCornflowerBlue, STYLE_DASH, 1, t1, t2);
      MKTL_DrawHLine("MKTL_ADR_L", g_adr.adr_low, clrCornflowerBlue, STYLE_DASH, 1, t1, t2);
      MKTL_DrawText("MKTL_ADR_H_lbl", "ADR H", g_adr.adr_high, clrCornflowerBlue, t2);
      MKTL_DrawText("MKTL_ADR_L_lbl", "ADR L", g_adr.adr_low, clrCornflowerBlue, t2);
   }

   // US Session
   if(DrawUS_Session && g_adr.us_high > 0)
   {
      MKTL_DrawHLine("MKTL_US_H", g_adr.us_high, US_HighColor, STYLE_DOT, 1, t1, t2);
      MKTL_DrawHLine("MKTL_US_L", g_adr.us_low, US_LowColor, STYLE_DOT, 1, t1, t2);
      MKTL_DrawText("MKTL_US_H_lbl", "US H", g_adr.us_high, US_HighColor, t2);
      MKTL_DrawText("MKTL_US_L_lbl", "US L", g_adr.us_low, US_LowColor, t2);
   }

   // Круглые уровни
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double step;
   if(_Digits == 3 || _Digits == 5)
      step = 0.01;
   else
      step = 1.0;

   double baseLevel = MathFloor(price / step) * step;
   for(int i = -2; i <= 2; i++)
   {
      double lvl = NormalizeDouble(baseLevel + i * step, _Digits);
      string name = "MKTL_RND_" + IntegerToString(i + 2);
      MKTL_DrawHLine(name, lvl, clrDimGray, STYLE_DOT, 1, t1, t2);
   }
}

//+------------------------------------------------------------------+
//| Вспомогательная: горизонтальная линия                               |
//+------------------------------------------------------------------+
void MKTL_DrawHLine(string name, double price, color clr, ENUM_LINE_STYLE style,
                     int width, datetime t1, datetime t2)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_TREND, 0, t1, price, t2, price);

   ObjectSetDouble(0, name, OBJPROP_PRICE, 0, price);
   ObjectSetDouble(0, name, OBJPROP_PRICE, 1, price);
   ObjectSetInteger(0, name, OBJPROP_TIME, 0, t1);
   ObjectSetInteger(0, name, OBJPROP_TIME, 1, t2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Вспомогательная: текстовая метка                                   |
//+------------------------------------------------------------------+
void MKTL_DrawText(string name, string text, double price, color clr, datetime t)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_TEXT, 0, t, price);

   ObjectSetDouble(0, name, OBJPROP_PRICE, price);
   ObjectSetInteger(0, name, OBJPROP_TIME, t);
   ObjectSetString(0, name, OBJPROP_TEXT, text + " " + DoubleToString(price, _Digits));
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 7);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Удалить все объекты                                                |
//+------------------------------------------------------------------+
void MKTL_DeleteObjects()
{
   string prefixes[] = {"MKTL_ADR_H", "MKTL_ADR_L", "MKTL_US_H", "MKTL_US_L",
                          "MKTL_ADR_H_lbl", "MKTL_ADR_L_lbl",
                          "MKTL_US_H_lbl", "MKTL_US_L_lbl"};

   for(int i = 0; i < ArraySize(prefixes); i++)
      ObjectDelete(0, prefixes[i]);

   for(int i = 0; i < 5; i++)
      ObjectDelete(0, "MKTL_RND_" + IntegerToString(i));
}

//+------------------------------------------------------------------+
//| Получить данные ADR                                                |
//+------------------------------------------------------------------+
double MKTL_GetADR()        { return g_adr.adr_day; }
double MKTL_GetADRHigh()    { return g_adr.adr_high; }
double MKTL_GetADRLow()     { return g_adr.adr_low; }
double MKTL_GetTodayOpen()  { return g_adr.today_open; }

#endif
