//+------------------------------------------------------------------+
//|                                          Claude_v600_VWAP.mq5      |
//|                        VWAP Indicator (Volume Weighted Avg Price)   |
//|                        Daily / Weekly / Monthly reset               |
//+------------------------------------------------------------------+
#property copyright "Claude v600"
#property version   "6.00"
#property indicator_chart_window
#property indicator_buffers 3
#property indicator_plots   3

#property indicator_label1  "VWAP"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrYellow
#property indicator_width1  2

#property indicator_label2  "Upper SD"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrDodgerBlue
#property indicator_style2  STYLE_DOT
#property indicator_width2  1

#property indicator_label3  "Lower SD"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrDodgerBlue
#property indicator_style3  STYLE_DOT
#property indicator_width3  1

// Параметры
enum ENUM_VWAP_RESET
{
   VWAP_RESET_DAILY   = 0,  // Daily
   VWAP_RESET_WEEKLY  = 1,  // Weekly
   VWAP_RESET_MONTHLY = 2   // Monthly
};

input ENUM_VWAP_RESET ResetPeriod = VWAP_RESET_DAILY;
input double SD_Multiplier = 1.0;

// Буферы
double VWAPBuffer[];
double SD1UpBuffer[];
double SD1DnBuffer[];

//+------------------------------------------------------------------+
//| Indicator initialization                                           |
//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, VWAPBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, SD1UpBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, SD1DnBuffer, INDICATOR_DATA);

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, 0);

   IndicatorSetString(INDICATOR_SHORTNAME, "VWAP (" +
      ((ResetPeriod == VWAP_RESET_DAILY) ? "D" :
       (ResetPeriod == VWAP_RESET_WEEKLY) ? "W" : "M") + ")");

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Проверить начало нового периода                                     |
//+------------------------------------------------------------------+
bool IsNewPeriod(const datetime &time[], int i)
{
   if(i == 0) return true;

   MqlDateTime dt1, dt2;
   TimeToStruct(time[i], dt1);
   TimeToStruct(time[i - 1], dt2);

   switch(ResetPeriod)
   {
      case VWAP_RESET_DAILY:
         return (dt1.day != dt2.day || dt1.mon != dt2.mon || dt1.year != dt2.year);
      case VWAP_RESET_WEEKLY:
         return (dt1.day_of_week < dt2.day_of_week ||
                  (time[i] - time[i-1]) > 3 * 86400);
      case VWAP_RESET_MONTHLY:
         return (dt1.mon != dt2.mon || dt1.year != dt2.year);
   }
   return false;
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
                const long &volume[],
                const int &spread[])
{
   if(rates_total < 2) return 0;

   int start = (prev_calculated > 1) ? prev_calculated - 1 : 0;

   // Используем static для сохранения между вызовами
   static double cumPV = 0;
   static double cumVol = 0;
   static double cumPV2 = 0;

   if(start == 0)
   {
      cumPV = 0;
      cumVol = 0;
      cumPV2 = 0;
   }

   for(int i = start; i < rates_total; i++)
   {
      // Проверить новый период
      if(IsNewPeriod(time, i))
      {
         cumPV = 0;
         cumVol = 0;
         cumPV2 = 0;
      }

      double typicalPrice = (high[i] + low[i] + close[i]) / 3.0;
      double vol = (double)tick_volume[i];

      if(vol <= 0) vol = 1;  // Защита от нулевого объёма

      cumPV  += typicalPrice * vol;
      cumVol += vol;
      cumPV2 += typicalPrice * typicalPrice * vol;

      if(cumVol > 0)
      {
         double vwap = cumPV / cumVol;
         VWAPBuffer[i] = vwap;

         // SD = sqrt(Σ((Price - VWAP)² × Volume) / Σ(Volume))
         double variance = (cumPV2 / cumVol) - (vwap * vwap);
         double sd = (variance > 0) ? MathSqrt(variance) : 0;

         SD1UpBuffer[i] = vwap + sd * SD_Multiplier;
         SD1DnBuffer[i] = vwap - sd * SD_Multiplier;
      }
      else
      {
         VWAPBuffer[i] = close[i];
         SD1UpBuffer[i] = close[i];
         SD1DnBuffer[i] = close[i];
      }
   }

   return rates_total;
}
//+------------------------------------------------------------------+
