//+------------------------------------------------------------------+
//|                                         Claude_v600_AVWAP.mq5      |
//|                        Anchored VWAP Indicator                     |
//|                        Anchored to a specific date/time             |
//+------------------------------------------------------------------+
#property copyright "Claude v600"
#property version   "6.00"
#property indicator_chart_window
#property indicator_buffers 3
#property indicator_plots   3

#property indicator_label1  "AVWAP"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrMagenta
#property indicator_width1  2

#property indicator_label2  "AVWAP +1SD"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrMagenta
#property indicator_style2  STYLE_DOT
#property indicator_width2  1

#property indicator_label3  "AVWAP -1SD"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrMagenta
#property indicator_style3  STYLE_DOT
#property indicator_width3  1

// Параметры
input datetime AnchorDate = D'2026.01.01 00:00';  // Точка привязки
input double   SD_Mult    = 1.0;                    // Множитель SD

// Буферы
double AVWAPBuffer[];
double SDUpBuffer[];
double SDDnBuffer[];

//+------------------------------------------------------------------+
//| Indicator initialization                                           |
//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, AVWAPBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, SDUpBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, SDDnBuffer, INDICATOR_DATA);

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, 0);

   IndicatorSetString(INDICATOR_SHORTNAME,
      "AVWAP (" + TimeToString(AnchorDate, TIME_DATE) + ")");

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Indicator calculation                                               |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const double &volume[],
                const int &spread[])
{
   if(rates_total < 2) return 0;

   // Найти индекс anchor bar
   int anchorIdx = -1;
   for(int i = 0; i < rates_total; i++)
   {
      if(time[i] >= AnchorDate)
      {
         anchorIdx = i;
         break;
      }
   }

   if(anchorIdx < 0) return rates_total;  // Anchor в будущем

   // Обнулить до anchor
   for(int i = 0; i < anchorIdx; i++)
   {
      AVWAPBuffer[i] = 0;
      SDUpBuffer[i] = 0;
      SDDnBuffer[i] = 0;
   }

   // Расчёт AVWAP от anchor
   double cumPV = 0;
   double cumVol = 0;
   double cumPV2 = 0;

   int start = (prev_calculated > anchorIdx + 1) ? prev_calculated - 1 : anchorIdx;

   // Если пересчёт — нужно накопить с начала
   if(start == anchorIdx)
   {
      cumPV = 0;
      cumVol = 0;
      cumPV2 = 0;
   }
   else
   {
      // Пересчитать кумулятивные от anchor
      cumPV = 0;
      cumVol = 0;
      cumPV2 = 0;
      for(int i = anchorIdx; i < start; i++)
      {
         double tp = (high[i] + low[i] + close[i]) / 3.0;
         double vol = (double)tick_volume[i];
         if(vol <= 0) vol = 1;
         cumPV += tp * vol;
         cumVol += vol;
         cumPV2 += tp * tp * vol;
      }
   }

   for(int i = start; i < rates_total; i++)
   {
      if(i < anchorIdx)
      {
         AVWAPBuffer[i] = 0;
         SDUpBuffer[i] = 0;
         SDDnBuffer[i] = 0;
         continue;
      }

      double typicalPrice = (high[i] + low[i] + close[i]) / 3.0;
      double vol = (double)tick_volume[i];
      if(vol <= 0) vol = 1;

      cumPV  += typicalPrice * vol;
      cumVol += vol;
      cumPV2 += typicalPrice * typicalPrice * vol;

      if(cumVol > 0)
      {
         double avwap = cumPV / cumVol;
         AVWAPBuffer[i] = avwap;

         double variance = (cumPV2 / cumVol) - (avwap * avwap);
         double sd = (variance > 0) ? MathSqrt(variance) : 0;

         SDUpBuffer[i] = avwap + sd * SD_Mult;
         SDDnBuffer[i] = avwap - sd * SD_Mult;
      }
      else
      {
         AVWAPBuffer[i] = close[i];
         SDUpBuffer[i] = close[i];
         SDDnBuffer[i] = close[i];
      }
   }

   return rates_total;
}
//+------------------------------------------------------------------+
