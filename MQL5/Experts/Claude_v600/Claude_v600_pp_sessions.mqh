#ifndef __CLAUDE_V600_PP_SESSIONS_MQH__
#define __CLAUDE_V600_PP_SESSIONS_MQH__
#property strict

// ==================== СЕССИОННЫЕ УРОВНИ ====================
// Asia H/L, London H/L, Midnight Open, Prev NY Close
// Daily Balance EMA

// Структура сессионных уровней
struct SessionLevels
{
   double asia_high;
   double asia_low;
   double london_high;
   double london_low;
   double midnight_open;
   double prev_ny_close;
   datetime asia_start;
   datetime asia_end;
   datetime london_start;
   datetime london_end;
   bool   asia_complete;
   bool   london_complete;
};

SessionLevels g_sessLevels;
int    g_hDailyEMA = INVALID_HANDLE;
double g_bufDailyEMA[];
datetime g_sessLastDay = 0;

//+------------------------------------------------------------------+
//| Инициализация сессий                                               |
//+------------------------------------------------------------------+
bool SESS_Init()
{
   if(!DrawSessionLevels) return true;

   ZeroMemory(g_sessLevels);
   g_sessLevels.asia_high = 0;
   g_sessLevels.asia_low = DBL_MAX;
   g_sessLevels.london_high = 0;
   g_sessLevels.london_low = DBL_MAX;

   if(DrawDailyBalanceEMA)
   {
      g_hDailyEMA = iMA(_Symbol, PERIOD_D1, 20, 0, MODE_EMA, PRICE_CLOSE);
      if(g_hDailyEMA == INVALID_HANDLE)
      {
         Print("[SESS] Failed to create Daily EMA handle");
         return false;
      }
      ArraySetAsSeries(g_bufDailyEMA, true);
   }

   // Рассчитать текущие уровни
   SESS_CalcLevels();

   return true;
}

//+------------------------------------------------------------------+
//| Деинициализация сессий                                             |
//+------------------------------------------------------------------+
void SESS_Deinit()
{
   if(g_hDailyEMA != INVALID_HANDLE)
   {
      IndicatorRelease(g_hDailyEMA);
      g_hDailyEMA = INVALID_HANDLE;
   }

   SESS_DeleteObjects();
}

//+------------------------------------------------------------------+
//| Конвертировать GMT час в broker time                                |
//+------------------------------------------------------------------+
int SESS_GMTToBroker(int hourGMT)
{
   return (hourGMT + BrokerGMTOffsetHours) % 24;
}

//+------------------------------------------------------------------+
//| Рассчитать сессионные уровни                                       |
//+------------------------------------------------------------------+
void SESS_CalcLevels()
{
   // Asia Session: 00:00-09:00 GMT = BrokerGMTOffsetHours .. BrokerGMTOffsetHours+9
   // London Session: 07:00-16:00 GMT
   // NY Close: 21:00 GMT (прошлого дня)
   // Midnight Open: 00:00 GMT

   int asiaStartBroker  = SESS_GMTToBroker(0);
   int asiaEndBroker    = SESS_GMTToBroker(9);
   int londonStartBroker = SESS_GMTToBroker(7);
   int londonEndBroker  = SESS_GMTToBroker(16);
   int nyCloseBroker    = SESS_GMTToBroker(21);
   int midnightBroker   = SESS_GMTToBroker(0);

   // Получить сегодняшнюю дату
   MqlDateTime dtNow;
   TimeToStruct(TimeCurrent(), dtNow);

   // Сброс уровней если новый день
   datetime todayStart = StringToTime(IntegerToString(dtNow.year) + "." +
                                       IntegerToString(dtNow.mon) + "." +
                                       IntegerToString(dtNow.day));

   if(todayStart != g_sessLastDay)
   {
      g_sessLevels.asia_high = 0;
      g_sessLevels.asia_low = DBL_MAX;
      g_sessLevels.london_high = 0;
      g_sessLevels.london_low = DBL_MAX;
      g_sessLevels.asia_complete = false;
      g_sessLevels.london_complete = false;
      g_sessLastDay = todayStart;
   }

   // Сканируем бары текущего дня
   int totalBars = iBars(_Symbol, _Period);
   double high[], low[], open[], close[];
   datetime time[];

   int barsToScan = MathMin(totalBars, 500);
   if(CopyHigh(_Symbol, _Period, 0, barsToScan, high) < barsToScan) return;
   if(CopyLow(_Symbol, _Period, 0, barsToScan, low) < barsToScan) return;
   if(CopyOpen(_Symbol, _Period, 0, barsToScan, open) < barsToScan) return;
   if(CopyClose(_Symbol, _Period, 0, barsToScan, close) < barsToScan) return;
   if(CopyTime(_Symbol, _Period, 0, barsToScan, time) < barsToScan) return;

   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(time, true);

   g_sessLevels.asia_high = 0;
   g_sessLevels.asia_low = DBL_MAX;
   g_sessLevels.london_high = 0;
   g_sessLevels.london_low = DBL_MAX;
   g_sessLevels.midnight_open = 0;
   g_sessLevels.prev_ny_close = 0;

   for(int i = 0; i < barsToScan; i++)
   {
      MqlDateTime dt;
      TimeToStruct(time[i], dt);

      int barHourBroker = dt.hour;
      int barHourGMT = (barHourBroker - BrokerGMTOffsetHours + 24) % 24;

      // Сегодня ли этот бар?
      datetime barDay = StringToTime(IntegerToString(dt.year) + "." +
                                      IntegerToString(dt.mon) + "." +
                                      IntegerToString(dt.day));

      if(barDay == todayStart)
      {
         // Asia: 00:00-09:00 GMT
         if(DrawAsiaHL && barHourGMT >= 0 && barHourGMT < 9)
         {
            if(high[i] > g_sessLevels.asia_high) g_sessLevels.asia_high = high[i];
            if(low[i] < g_sessLevels.asia_low)   g_sessLevels.asia_low = low[i];
         }

         // London: 07:00-16:00 GMT
         if(DrawLondonHL && barHourGMT >= 7 && barHourGMT < 16)
         {
            if(high[i] > g_sessLevels.london_high) g_sessLevels.london_high = high[i];
            if(low[i] < g_sessLevels.london_low)   g_sessLevels.london_low = low[i];
         }

         // Midnight Open (00:00 GMT)
         if(DrawMidnightOpen && barHourGMT == 0 && g_sessLevels.midnight_open == 0)
         {
            g_sessLevels.midnight_open = open[i];
         }
      }

      // Prev NY Close (вчера 21:00 GMT)
      if(DrawPrevNYClose && barDay < todayStart && barHourGMT == 21 &&
         g_sessLevels.prev_ny_close == 0)
      {
         g_sessLevels.prev_ny_close = close[i];
      }
   }

   // Защита
   if(g_sessLevels.asia_low == DBL_MAX) g_sessLevels.asia_low = 0;
   if(g_sessLevels.london_low == DBL_MAX) g_sessLevels.london_low = 0;
}

//+------------------------------------------------------------------+
//| Обновить сессии (вызывается раз в бар)                             |
//+------------------------------------------------------------------+
void SESS_Update(MarketContext &ctx)
{
   if(!DrawSessionLevels) return;

   SESS_CalcLevels();

   // Заполнить контекст
   ctx.asia_high     = g_sessLevels.asia_high;
   ctx.asia_low      = g_sessLevels.asia_low;
   ctx.london_high   = g_sessLevels.london_high;
   ctx.london_low    = g_sessLevels.london_low;
   ctx.midnight_open = g_sessLevels.midnight_open;
   ctx.prev_ny_close = g_sessLevels.prev_ny_close;

   // Рисовать линии
   SESS_DrawLevels();

   // Daily Balance EMA
   if(DrawDailyBalanceEMA && g_hDailyEMA != INVALID_HANDLE)
   {
      if(CopyBuffer(g_hDailyEMA, 0, 0, 1, g_bufDailyEMA) >= 1)
         SESS_DrawDailyEMA(g_bufDailyEMA[0]);
   }
}

//+------------------------------------------------------------------+
//| Рисовать сессионные уровни на графике                              |
//+------------------------------------------------------------------+
void SESS_DrawLevels()
{
   datetime t1 = iTime(_Symbol, PERIOD_D1, 0);
   datetime t2 = TimeCurrent() + PeriodSeconds(_Period) * 10;

   if(DrawAsiaHL && g_sessLevels.asia_high > 0)
   {
      SESS_DrawLine("SESS_AsiaH", g_sessLevels.asia_high, AsiaColor, STYLE_DOT, 1, t1, t2);
      SESS_DrawLine("SESS_AsiaL", g_sessLevels.asia_low, AsiaColor, STYLE_DOT, 1, t1, t2);
      SESS_DrawLabel("SESS_AsiaH_lbl", "Asia H", g_sessLevels.asia_high, AsiaColor, t2);
      SESS_DrawLabel("SESS_AsiaL_lbl", "Asia L", g_sessLevels.asia_low, AsiaColor, t2);
   }

   if(DrawLondonHL && g_sessLevels.london_high > 0)
   {
      SESS_DrawLine("SESS_LonH", g_sessLevels.london_high, LondonColor, STYLE_DOT, 1, t1, t2);
      SESS_DrawLine("SESS_LonL", g_sessLevels.london_low, LondonColor, STYLE_DOT, 1, t1, t2);
      SESS_DrawLabel("SESS_LonH_lbl", "London H", g_sessLevels.london_high, LondonColor, t2);
      SESS_DrawLabel("SESS_LonL_lbl", "London L", g_sessLevels.london_low, LondonColor, t2);
   }

   if(DrawMidnightOpen && g_sessLevels.midnight_open > 0)
   {
      SESS_DrawLine("SESS_MidO", g_sessLevels.midnight_open, MidnightColor, STYLE_DASHDOT, 1, t1, t2);
      SESS_DrawLabel("SESS_MidO_lbl", "MO", g_sessLevels.midnight_open, MidnightColor, t2);
   }

   if(DrawPrevNYClose && g_sessLevels.prev_ny_close > 0)
   {
      SESS_DrawLine("SESS_NYC", g_sessLevels.prev_ny_close, NYCloseColor, STYLE_DASHDOT, 1, t1, t2);
      SESS_DrawLabel("SESS_NYC_lbl", "NY Close", g_sessLevels.prev_ny_close, NYCloseColor, t2);
   }
}

//+------------------------------------------------------------------+
//| Вспомогательная: создать горизонтальную линию (OBJ_TREND)          |
//+------------------------------------------------------------------+
void SESS_DrawLine(string name, double price, color clr, ENUM_LINE_STYLE style,
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
//| Вспомогательная: подпись уровня                                    |
//+------------------------------------------------------------------+
void SESS_DrawLabel(string name, string text, double price, color clr, datetime t)
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
//| Рисовать Daily Balance EMA                                         |
//+------------------------------------------------------------------+
void SESS_DrawDailyEMA(double emaValue)
{
   string name = "SESS_DailyEMA";
   datetime t1 = iTime(_Symbol, PERIOD_D1, 0);
   datetime t2 = TimeCurrent() + PeriodSeconds(_Period) * 10;

   SESS_DrawLine(name, emaValue, DailyEMA_Color, STYLE_SOLID, DailyEMA_Width, t1, t2);
   SESS_DrawLabel(name + "_lbl", "DEMA", emaValue, DailyEMA_Color, t2);
}

//+------------------------------------------------------------------+
//| Удалить все объекты сессий                                         |
//+------------------------------------------------------------------+
void SESS_DeleteObjects()
{
   string prefixes[] = {"SESS_AsiaH", "SESS_AsiaL", "SESS_LonH", "SESS_LonL",
                          "SESS_MidO", "SESS_NYC", "SESS_DailyEMA",
                          "SESS_AsiaH_lbl", "SESS_AsiaL_lbl",
                          "SESS_LonH_lbl", "SESS_LonL_lbl",
                          "SESS_MidO_lbl", "SESS_NYC_lbl",
                          "SESS_DailyEMA_lbl"};

   for(int i = 0; i < ArraySize(prefixes); i++)
      ObjectDelete(0, prefixes[i]);
}

#endif
