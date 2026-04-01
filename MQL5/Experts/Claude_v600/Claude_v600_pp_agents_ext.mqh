#ifndef __CLAUDE_V600_PP_AGENTS_EXT_MQH__
#define __CLAUDE_V600_PP_AGENTS_EXT_MQH__
#property strict

// ==================== АГЕНТЫ 6-9 (РАСШИРЕННЫЕ) ====================
// [5] WPR Multi-TF
// [6] Better Volume (встроенный)
// [7] TD REI (встроенный, формула ДеМарка)
// [8] PVSRA (встроенный)

// WPR хэндлы (4 периода)
int g_hWPR[4];

//+------------------------------------------------------------------+
//| Получить периоды WPR по таймфрейму                                 |
//+------------------------------------------------------------------+
void GetWPRPeriods(int &periods[])
{
   ArrayResize(periods, 4);
   int tfMin = PeriodSeconds(_Period) / 60;
   switch(tfMin)
   {
      case 1:  periods[0]=1440; periods[1]=480; periods[2]=240; periods[3]=60;  break;
      case 5:  periods[0]=288;  periods[1]=96;  periods[2]=48;  periods[3]=24;  break;
      case 15: periods[0]=96;   periods[1]=32;  periods[2]=16;  periods[3]=8;   break;
      case 60: periods[0]=24;   periods[1]=8;   periods[2]=4;   periods[3]=2;   break;
      default: periods[0]=288;  periods[1]=96;  periods[2]=48;  periods[3]=24;  break;
   }
}

//+------------------------------------------------------------------+
//| Инициализация WPR                                                  |
//+------------------------------------------------------------------+
bool AGTX_InitWPR()
{
   int periods[];
   GetWPRPeriods(periods);

   for(int i = 0; i < 4; i++)
   {
      g_hWPR[i] = iWPR(_Symbol, _Period, periods[i]);
      if(g_hWPR[i] == INVALID_HANDLE)
      {
         Print("[AGTX] WPR handle ", i, " failed! Period=", periods[i]);
         return false;
      }
   }
   return true;
}

//+------------------------------------------------------------------+
//| Инициализация всех расширенных агентов                             |
//+------------------------------------------------------------------+
bool AGTX_Init()
{
   if(!EnableAgentSystem) return true;

   // WPR
   if(Agent_WPR_Enabled)
   {
      if(!AGTX_InitWPR()) return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Деинициализация                                                    |
//+------------------------------------------------------------------+
void AGTX_Deinit()
{
   for(int i = 0; i < 4; i++)
   {
      if(g_hWPR[i] != INVALID_HANDLE)
      {
         IndicatorRelease(g_hWPR[i]);
         g_hWPR[i] = INVALID_HANDLE;
      }
   }
}

//+------------------------------------------------------------------+
//| Агент 5: WPR Multi-TF                                             |
//+------------------------------------------------------------------+
void AGTX_WPR(AgentSignal &sig, MarketContext &ctx)
{
   sig.name = "WPR MTF";
   sig.enabled = Agent_WPR_Enabled;
   sig.weight = WPR_Weight;
   sig.confidence = 0.7;
   sig.score = 0;

   if(!sig.enabled) return;

   double wprValues[4];
   int bullCount = 0, bearCount = 0;
   double avgWPR = 0;

   for(int i = 0; i < 4; i++)
   {
      double buf[];
      ArraySetAsSeries(buf, true);
      if(CopyBuffer(g_hWPR[i], 0, 0, 1, buf) < 1)
      {
         wprValues[i] = -50;
         continue;
      }
      wprValues[i] = buf[0];
      avgWPR += buf[0];

      if(buf[0] < WPR_OversoldLevel)
         bullCount++;  // Перепродан = бычий сигнал
      else if(buf[0] > WPR_OverboughtLevel)
         bearCount++;  // Перекуплен = медвежий сигнал
   }
   avgWPR /= 4.0;

   // Сохранить в контекст
   ctx.wpr1 = wprValues[0];
   ctx.wpr2 = wprValues[1];
   ctx.wpr3 = wprValues[2];
   ctx.wpr4 = wprValues[3];

   // Scoring
   if(bullCount >= 3)
   {
      sig.score = 70 + (bullCount - 3) * 15;  // 70-85
      sig.confidence = 0.85;
   }
   else if(bearCount >= 3)
   {
      sig.score = -(70 + (bearCount - 3) * 15);
      sig.confidence = 0.85;
   }
   else if(bullCount == 2)
   {
      sig.score = 40;
      sig.confidence = 0.6;
   }
   else if(bearCount == 2)
   {
      sig.score = -40;
      sig.confidence = 0.6;
   }
   else
   {
      // Среднее WPR
      sig.score = -(int)(avgWPR + 50);  // -50 centre → 0; <-50 → positive
      sig.confidence = 0.4;
   }

   sig.score = MathMax(-100, MathMin(100, sig.score));
}

//+------------------------------------------------------------------+
//| Агент 6: Better Volume (встроенный)                                |
//| Value2 = Volume * Range, Value3 = Volume / Range                   |
//+------------------------------------------------------------------+
void AGTX_BetterVolume(AgentSignal &sig, MarketContext &ctx)
{
   sig.name = "BetterVol";
   sig.enabled = Agent_BV_Enabled;
   sig.weight = BV_Weight;
   sig.confidence = 0.6;
   sig.score = 0;

   if(!sig.enabled) return;

   int lookback = BV_LookBack + 1;

   long vol[];
   double high[], low[], open[], close[];

   if(CopyTickVolume(_Symbol, _Period, 0, lookback, vol) < lookback) return;
   if(CopyHigh(_Symbol, _Period, 0, lookback, high) < lookback) return;
   if(CopyLow(_Symbol, _Period, 0, lookback, low) < lookback) return;
   if(CopyOpen(_Symbol, _Period, 0, lookback, open) < lookback) return;
   if(CopyClose(_Symbol, _Period, 0, lookback, close) < lookback) return;

   ArraySetAsSeries(vol, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(close, true);

   // Текущий бар
   double range0 = high[0] - low[0];
   double value2_0 = (double)vol[0] * range0;
   double value3_0 = (range0 > 0) ? (double)vol[0] / range0 : 0;

   // Найти max за lookback
   double maxValue2 = 0, maxValue3 = 0;
   double avgVol = 0;

   for(int i = 1; i < lookback; i++)
   {
      double r = high[i] - low[i];
      double v2 = (double)vol[i] * r;
      double v3 = (r > 0) ? (double)vol[i] / r : 0;

      if(v2 > maxValue2) maxValue2 = v2;
      if(v3 > maxValue3) maxValue3 = v3;
      avgVol += (double)vol[i];
   }
   avgVol /= (lookback - 1);

   // Классификация
   int bvType = BV_NEUTRAL;
   bool isClimaxHigh = (value2_0 >= maxValue2 && range0 > 0);
   bool isClimaxLow  = (value3_0 >= maxValue3 && range0 > 0);
   bool isHighChurn  = isClimaxHigh && isClimaxLow;
   bool isLowVolume  = ((double)vol[0] < avgVol * 0.5);

   if(isHighChurn)
      bvType = BV_CLIMAX_CHURN;
   else if(isClimaxHigh && close[0] > open[0])
      bvType = BV_CLIMAX_HIGH;
   else if(isClimaxHigh && close[0] <= open[0])
      bvType = BV_CLIMAX_LOW;
   else if(isClimaxLow)
      bvType = BV_HIGH_CHURN;
   else if(isLowVolume)
      bvType = BV_LOW_VOLUME;

   ctx.bv_type = bvType;
   ctx.volume_ratio = (avgVol > 0) ? (double)vol[0] / avgVol : 1.0;

   // Scoring
   bool bullCandle = (close[0] > open[0]);
   switch(bvType)
   {
      case BV_CLIMAX_HIGH:
         sig.score = bullCandle ? 40 : -40;
         sig.confidence = 0.8;
         break;
      case BV_CLIMAX_LOW:
         sig.score = bullCandle ? -30 : 30;   // Контр-тренд (продавцы исчерпаны)
         sig.confidence = 0.7;
         break;
      case BV_HIGH_CHURN:
         sig.score = 0;  // Нерешительность
         sig.confidence = 0.3;
         break;
      case BV_LOW_VOLUME:
         sig.score = 0;  // Нет интереса
         sig.confidence = 0.2;
         break;
      case BV_CLIMAX_CHURN:
         sig.score = bullCandle ? -20 : 20;  // Разворот вероятен
         sig.confidence = 0.75;
         break;
      default:
         sig.score = 0;
         sig.confidence = 0.4;
         break;
   }

   sig.score = MathMax(-100, MathMin(100, sig.score));
}

//+------------------------------------------------------------------+
//| Получить период TD REI по таймфрейму                               |
//+------------------------------------------------------------------+
int GetREIPeriod()
{
   int tfMin = PeriodSeconds(_Period) / 60;
   if(tfMin <= 1) return 16;
   if(tfMin <= 5) return 12;
   if(tfMin <= 15) return 10;
   return 8;
}

//+------------------------------------------------------------------+
//| Получить порог TD REI по таймфрейму                                |
//+------------------------------------------------------------------+
double GetREIThreshold()
{
   int tfMin = PeriodSeconds(_Period) / 60;
   return (tfMin <= 1) ? 45.0 : 60.0;
}

//+------------------------------------------------------------------+
//| Агент 7: TD REI (встроенный, формула ДеМарка)                      |
//+------------------------------------------------------------------+
void AGTX_TDREI(AgentSignal &sig, MarketContext &ctx)
{
   sig.name = "TD REI";
   sig.enabled = Agent_REI_Enabled;
   sig.weight = REI_Weight;
   sig.confidence = 0.6;
   sig.score = 0;

   if(!sig.enabled) return;

   int period = GetREIPeriod();
   double threshold = GetREIThreshold();
   int barsNeeded = period + 9;  // max index = (period-1)+8, need period+8 minimum, +1 safety

   double high[], low[], close[];
   if(CopyHigh(_Symbol, _Period, 0, barsNeeded, high) < barsNeeded) return;
   if(CopyLow(_Symbol, _Period, 0, barsNeeded, low) < barsNeeded) return;
   if(CopyClose(_Symbol, _Period, 0, barsNeeded, close) < barsNeeded) return;

   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);

   // TD REI формула ДеМарка
   double numSum = 0;
   double denSum = 0;

   for(int i = 0; i < period; i++)
   {
      // Условие для High
      bool highCond = (high[i] >= low[i+5] || high[i] >= low[i+6] ||
                        high[i+2] >= close[i+7] || high[i+2] >= close[i+8]);
      // Условие для Low
      bool lowCond = (low[i] <= high[i+5] || low[i] <= high[i+6] ||
                       low[i+2] <= close[i+7] || low[i+2] <= close[i+8]);

      double dH = high[i] - high[i+2];
      double dL = low[i] - low[i+2];

      if(highCond || lowCond)
         numSum += dH + dL;

      denSum += MathAbs(dH) + MathAbs(dL);
   }

   double rei = (denSum != 0) ? (numSum / denSum) * 100.0 : 0;
   ctx.rei_value = rei;

   // Scoring
   if(rei > threshold)
   {
      sig.score = -(int)((rei - threshold) / (100.0 - threshold) * 80);  // Медвежий
      sig.confidence = 0.8;
   }
   else if(rei < -threshold)
   {
      sig.score = (int)((MathAbs(rei) - threshold) / (100.0 - threshold) * 80);  // Бычий
      sig.confidence = 0.8;
   }
   else
   {
      sig.score = -(int)(rei * 0.3);
      sig.confidence = 0.4;
   }

   sig.score = MathMax(-100, MathMin(100, sig.score));
}

//+------------------------------------------------------------------+
//| Агент 8: PVSRA (встроенный)                                        |
//| Climax = Vol >= 2.0 * avgVol ИЛИ V*Spread >= max(V*Spread, 10)    |
//| Rising = Vol >= 1.5 * avgVol                                       |
//+------------------------------------------------------------------+
void AGTX_PVSRA(AgentSignal &sig, MarketContext &ctx)
{
   sig.name = "PVSRA";
   sig.enabled = Agent_PVSRA_Enabled;
   sig.weight = PVSRA_Weight;
   sig.confidence = 0.6;
   sig.score = 0;

   if(!sig.enabled) return;

   int lookback = PVSRA_AvgPeriod + 1;

   long vol[];
   double high[], low[], open[], close[];

   if(CopyTickVolume(_Symbol, _Period, 0, lookback, vol) < lookback) return;
   if(CopyHigh(_Symbol, _Period, 0, lookback, high) < lookback) return;
   if(CopyLow(_Symbol, _Period, 0, lookback, low) < lookback) return;
   if(CopyOpen(_Symbol, _Period, 0, lookback, open) < lookback) return;
   if(CopyClose(_Symbol, _Period, 0, lookback, close) < lookback) return;

   ArraySetAsSeries(vol, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(close, true);

   // Среднее volume и max V*Spread
   double avgVol = 0;
   double maxVS = 0;

   for(int i = 1; i < lookback; i++)
   {
      avgVol += (double)vol[i];
      double vs = (double)vol[i] * (high[i] - low[i]);
      if(vs > maxVS) maxVS = vs;
   }
   avgVol /= (lookback - 1);

   // Текущий бар
   double curVol = (double)vol[0];
   double curSpread = high[0] - low[0];
   double curVS = curVol * curSpread;
   bool bullCandle = (close[0] > open[0]);

   // Классификация
   int pvsraType = PVSRA_NORMAL;

   bool isClimax = (curVol >= 2.0 * avgVol) || (curVS >= maxVS);
   bool isRising = (curVol >= 1.5 * avgVol);

   if(isClimax)
   {
      pvsraType = bullCandle ? PVSRA_BULL_CLIMAX : PVSRA_BEAR_CLIMAX;
   }
   else if(isRising)
   {
      pvsraType = bullCandle ? PVSRA_BULL_RISING : PVSRA_BEAR_RISING;
   }

   ctx.pvsra_type = pvsraType;

   // Scoring
   switch(pvsraType)
   {
      case PVSRA_BULL_CLIMAX:
         sig.score = -40;  // Climax = возможен разворот ВНИЗ
         sig.confidence = 0.8;
         break;
      case PVSRA_BEAR_CLIMAX:
         sig.score = 40;   // Climax = возможен разворот ВВЕРХ
         sig.confidence = 0.8;
         break;
      case PVSRA_BULL_RISING:
         sig.score = 30;   // Rising bull = подтверждение
         sig.confidence = 0.6;
         break;
      case PVSRA_BEAR_RISING:
         sig.score = -30;  // Rising bear = подтверждение
         sig.confidence = 0.6;
         break;
      default:
         sig.score = 0;
         sig.confidence = 0.3;
         break;
   }

   sig.score = MathMax(-100, MathMin(100, sig.score));
}

//+------------------------------------------------------------------+
//| Запустить все агенты 6-9                                           |
//+------------------------------------------------------------------+
void AGTX_RunAll(AgentSignal &signals[], MarketContext &ctx)
{
   if(!EnableAgentSystem) return;

   AGTX_WPR(signals[5], ctx);
   AGTX_BetterVolume(signals[6], ctx);
   AGTX_TDREI(signals[7], ctx);
   AGTX_PVSRA(signals[8], ctx);
}

#endif
