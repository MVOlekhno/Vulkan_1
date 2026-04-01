//+------------------------------------------------------------------+
//|                                  Claude_v600_VolumeProfile.mq5     |
//|                        Volume Profile Indicator                    |
//|                        TPO / Volume at Price                       |
//+------------------------------------------------------------------+
#property copyright "Claude v600"
#property version   "6.00"
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   4

#property indicator_label1  "POC"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrRed
#property indicator_width1  2

#property indicator_label2  "VAH"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrangeRed
#property indicator_style2  STYLE_DASH
#property indicator_width2  1

#property indicator_label3  "VAL"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrOrangeRed
#property indicator_style3  STYLE_DASH
#property indicator_width3  1

#property indicator_label4  "VWAP"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrYellow
#property indicator_width4  1

// Параметры
input int     VP_Rows      = 50;     // Количество ценовых уровней
input double  VA_Percent   = 70.0;   // Value Area %
input int     LookbackBars = 0;      // 0 = сессия (с начала дня)

// Буферы
double POCBuffer[];
double VAHBuffer[];
double VALBuffer[];
double VWAPBuffer[];

// Профиль
double g_vpVolume[];      // Объём по уровням
double g_vpPriceMin = 0;
double g_vpPriceMax = 0;
double g_vpStep = 0;
datetime g_vpLastCalc = 0;

//+------------------------------------------------------------------+
//| Indicator initialization                                           |
//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, POCBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, VAHBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, VALBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, VWAPBuffer, INDICATOR_DATA);

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, 0);
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, 0);

   ArrayResize(g_vpVolume, VP_Rows);
   ArrayInitialize(g_vpVolume, 0);

   IndicatorSetString(INDICATOR_SHORTNAME, "VP (" + IntegerToString(VP_Rows) + ")");

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Рассчитать Volume Profile                                          |
//+------------------------------------------------------------------+
void CalcProfile(const double &high[], const double &low[],
                  const double &close[], const long &tick_volume[],
                  const datetime &time[], int startBar, int endBar)
{
   // Найти min/max
   g_vpPriceMin = DBL_MAX;
   g_vpPriceMax = 0;

   for(int i = startBar; i <= endBar; i++)
   {
      if(high[i] > g_vpPriceMax) g_vpPriceMax = high[i];
      if(low[i] < g_vpPriceMin)  g_vpPriceMin = low[i];
   }

   if(g_vpPriceMax <= g_vpPriceMin) return;

   g_vpStep = (g_vpPriceMax - g_vpPriceMin) / VP_Rows;
   if(g_vpStep <= 0) return;

   ArrayInitialize(g_vpVolume, 0);

   // Распределить объём по уровням
   for(int i = startBar; i <= endBar; i++)
   {
      double vol = (double)tick_volume[i];
      if(vol <= 0) vol = 1;

      // Определить диапазон уровней для этого бара
      int lowRow  = (int)((low[i] - g_vpPriceMin) / g_vpStep);
      int highRow = (int)((high[i] - g_vpPriceMin) / g_vpStep);

      lowRow  = MathMax(0, MathMin(VP_Rows - 1, lowRow));
      highRow = MathMax(0, MathMin(VP_Rows - 1, highRow));

      int rowCount = highRow - lowRow + 1;
      if(rowCount <= 0) rowCount = 1;

      double volPerRow = vol / rowCount;

      for(int r = lowRow; r <= highRow; r++)
         g_vpVolume[r] += volPerRow;
   }
}

//+------------------------------------------------------------------+
//| Найти POC (Point of Control)                                       |
//+------------------------------------------------------------------+
double FindPOC()
{
   double maxVol = 0;
   int maxRow = 0;

   for(int r = 0; r < VP_Rows; r++)
   {
      if(g_vpVolume[r] > maxVol)
      {
         maxVol = g_vpVolume[r];
         maxRow = r;
      }
   }

   return g_vpPriceMin + (maxRow + 0.5) * g_vpStep;
}

//+------------------------------------------------------------------+
//| Найти Value Area (VA_Percent % объёма вокруг POC)                  |
//+------------------------------------------------------------------+
void FindValueArea(double &vah, double &val)
{
   double totalVol = 0;
   for(int r = 0; r < VP_Rows; r++)
      totalVol += g_vpVolume[r];

   double targetVol = totalVol * VA_Percent / 100.0;

   // Найти POC row
   int pocRow = 0;
   double maxVol = 0;
   for(int r = 0; r < VP_Rows; r++)
   {
      if(g_vpVolume[r] > maxVol)
      {
         maxVol = g_vpVolume[r];
         pocRow = r;
      }
   }

   // Расширять от POC пока не наберём targetVol
   double accVol = g_vpVolume[pocRow];
   int upper = pocRow;
   int lower = pocRow;

   while(accVol < targetVol && (upper < VP_Rows - 1 || lower > 0))
   {
      double upVol = (upper < VP_Rows - 1) ? g_vpVolume[upper + 1] : 0;
      double dnVol = (lower > 0) ? g_vpVolume[lower - 1] : 0;

      if(upVol >= dnVol && upper < VP_Rows - 1)
      {
         upper++;
         accVol += g_vpVolume[upper];
      }
      else if(lower > 0)
      {
         lower--;
         accVol += g_vpVolume[lower];
      }
      else if(upper < VP_Rows - 1)
      {
         upper++;
         accVol += g_vpVolume[upper];
      }
      else
         break;
   }

   vah = g_vpPriceMin + (upper + 1) * g_vpStep;
   val = g_vpPriceMin + lower * g_vpStep;
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
   if(rates_total < 10) return 0;

   int start = (prev_calculated > 1) ? prev_calculated - 1 : 0;

   for(int i = start; i < rates_total; i++)
   {
      // Определить начало сессии
      int sessionStart = 0;

      if(LookbackBars > 0)
      {
         sessionStart = MathMax(0, i - LookbackBars);
      }
      else
      {
         // Начало текущего дня
         MqlDateTime dt;
         TimeToStruct(time[i], dt);

         for(int j = i; j >= 0; j--)
         {
            MqlDateTime dt2;
            TimeToStruct(time[j], dt2);
            if(dt2.day != dt.day || dt2.mon != dt.mon || dt2.year != dt.year)
            {
               sessionStart = j + 1;
               break;
            }
         }
      }

      // Пересчитать профиль
      CalcProfile(high, low, close, tick_volume, time, sessionStart, i);

      // POC
      POCBuffer[i] = FindPOC();

      // Value Area
      double vah, val;
      FindValueArea(vah, val);
      VAHBuffer[i] = vah;
      VALBuffer[i] = val;

      // VWAP (простой)
      double cumPV = 0, cumVol = 0;
      for(int j = sessionStart; j <= i; j++)
      {
         double tp = (high[j] + low[j] + close[j]) / 3.0;
         double vol = (double)tick_volume[j];
         if(vol <= 0) vol = 1;
         cumPV += tp * vol;
         cumVol += vol;
      }
      VWAPBuffer[i] = (cumVol > 0) ? cumPV / cumVol : close[i];
   }

   return rates_total;
}
//+------------------------------------------------------------------+
