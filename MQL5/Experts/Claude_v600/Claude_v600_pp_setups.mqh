#ifndef __CLAUDE_V600_PP_SETUPS_MQH__
#define __CLAUDE_V600_PP_SETUPS_MQH__
#property strict

// ==================== ДЕТЕКЦИЯ СЕТАПОВ ====================
// 6 сетапов из Playbook v4 + Fib Pivot Reversal
// FVG_CAD5 Playbook v4

// Типы сетапов
#define SETUP_NONE              0
#define SETUP_FVG_CONTINUATION  1  // FVG Continuation
#define SETUP_FVG_REVERSAL      2  // FVG Reversal
#define SETUP_VWAP_BOUNCE       3  // VWAP Bounce
#define SETUP_RANGE_BREAK       4  // Range Breakout
#define SETUP_MOMENTUM_FADE     5  // Momentum Fade
#define SETUP_SD_BOUNCE         6  // Supply/Demand Bounce
#define SETUP_FIB_PIVOT_REV     7  // Fib Pivot Reversal (НОВЫЙ)

struct SetupInfo
{
   int    type;
   string name;
   string setupClass;    // "A", "A+", "S"
   double score;
   int    direction;      // +1=LONG, -1=SHORT
   int    barsToEntry;    // Сколько баров до входа (0=сейчас)
   string description;
};

SetupInfo g_currentSetup;
SetupInfo g_upcomingSetup;

//+------------------------------------------------------------------+
//| Инициализация                                                      |
//+------------------------------------------------------------------+
void SETUP_Init()
{
   ZeroMemory(g_currentSetup);
   ZeroMemory(g_upcomingSetup);
}

//+------------------------------------------------------------------+
//| Детекция FVG (Fair Value Gap)                                      |
//+------------------------------------------------------------------+
bool SETUP_DetectFVG(int &direction, double &gapSize)
{
   double high[], low[], open[], close[];
   if(CopyHigh(_Symbol, _Period, 0, 5, high) < 5) return false;
   if(CopyLow(_Symbol, _Period, 0, 5, low) < 5) return false;
   if(CopyOpen(_Symbol, _Period, 0, 5, open) < 5) return false;
   if(CopyClose(_Symbol, _Period, 0, 5, close) < 5) return false;

   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(close, true);

   // Bullish FVG: low[0] > high[2] (gap up)
   if(low[1] > high[3])
   {
      gapSize = low[1] - high[3];
      direction = +1;
      return true;
   }

   // Bearish FVG: high[0] < low[2] (gap down)
   if(high[1] < low[3])
   {
      gapSize = low[3] - high[1];
      direction = -1;
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Детекция Range Breakout                                            |
//+------------------------------------------------------------------+
bool SETUP_DetectRangeBreak(int &direction, MarketContext &ctx)
{
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // Пробой Asia Range
   if(ctx.asia_high > 0 && ctx.asia_low > 0)
   {
      double asiaRange = ctx.asia_high - ctx.asia_low;
      if(asiaRange > 0)
      {
         if(price > ctx.asia_high + asiaRange * 0.1)
         {
            direction = +1;
            return true;
         }
         if(price < ctx.asia_low - asiaRange * 0.1)
         {
            direction = -1;
            return true;
         }
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Детекция VWAP Bounce                                               |
//+------------------------------------------------------------------+
bool SETUP_DetectVWAPBounce(int &direction, MarketContext &ctx)
{
   // Цена вернулась к VWAP/MA20 и отскочила
   double close[];
   if(CopyClose(_Symbol, _Period, 0, 5, close) < 5) return false;
   ArraySetAsSeries(close, true);

   double price = close[0];
   double pricePrev = close[1];
   double pricePrev2 = close[2];

   // Простая логика: приближение и отскок от EMA
   double point10 = _Point * 10.0;

   if(ctx.ema_position == +1 && MathAbs(ctx.price_vs_vwap) < 5.0)
   {
      if(price > pricePrev && pricePrev < pricePrev2)
      {
         direction = +1;  // Отскок вверх от VWAP
         return true;
      }
   }
   if(ctx.ema_position == -1 && MathAbs(ctx.price_vs_vwap) < 5.0)
   {
      if(price < pricePrev && pricePrev > pricePrev2)
      {
         direction = -1;  // Отскок вниз от VWAP
         return true;
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Детекция Fib Pivot Reversal (НОВЫЙ)                                |
//+------------------------------------------------------------------+
bool SETUP_DetectFibPivotReversal(int &direction, MarketContext &ctx)
{
   if(!Agent_FibPivot_Enabled) return false;

   // Зона 61-100 + подтверждение от агентов
   if(ctx.pivot_zone >= 3 && ctx.pivot_zone <= 4)
   {
      direction = -ctx.pivot_bias;  // Контр-тренд
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Детекция Momentum Fade                                             |
//+------------------------------------------------------------------+
bool SETUP_DetectMomentumFade(int &direction, MarketContext &ctx)
{
   // RSI экстремум + разворотная свеча
   if(ctx.rei_value > 60)
   {
      direction = -1;  // Перекуплен — шорт
      return true;
   }
   if(ctx.rei_value < -60)
   {
      direction = +1;  // Перепродан — лонг
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Детекция Supply/Demand Bounce                                      |
//+------------------------------------------------------------------+
bool SETUP_DetectSDBounce(int &direction, MarketContext &ctx)
{
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point10 = _Point * 10.0;

   // Вблизи PDH/PDL
   if(ctx.pdh > 0 && MathAbs(price - ctx.pdl) / point10 < 8)
   {
      direction = +1;  // Bounce от поддержки
      return true;
   }
   if(ctx.pdl > 0 && MathAbs(price - ctx.pdh) / point10 < 8)
   {
      direction = -1;  // Bounce от сопротивления
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Основная функция детекции                                          |
//+------------------------------------------------------------------+
void SETUP_Detect(AgentSignal &signals[], MarketContext &ctx)
{
   if(!EnableSetupDetection) return;

   ZeroMemory(g_currentSetup);
   g_currentSetup.type = SETUP_NONE;

   int dir = 0;
   double gapSize = 0;

   // Приоритет детекции (от сильнейшего к слабейшему)

   // 1. Fib Pivot Reversal
   if(SETUP_DetectFibPivotReversal(dir, ctx))
   {
      g_currentSetup.type = SETUP_FIB_PIVOT_REV;
      g_currentSetup.name = "Fib Pivot Reversal";
      g_currentSetup.direction = dir;
      g_currentSetup.score = 80;
      g_currentSetup.barsToEntry = 0;

      // Грейдинг с учётом Fib TP
      FibTPTargets tp;
      double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      FibPivot_CalcTPTargets(dir, price, tp);

      if(tp.target_5R > 0)
         g_currentSetup.setupClass = "A+";
      else if(tp.target_2R > 0)
         g_currentSetup.setupClass = "A";
      else
         g_currentSetup.setupClass = "S";

      g_currentSetup.description = "Zone " + FibPivot_ZoneName(ctx.pivot_zone, ctx.pivot_bias);
   }
   // 2. FVG
   else if(SETUP_DetectFVG(dir, gapSize))
   {
      // Определить тип FVG
      bool isContinuation = (dir > 0 && ctx.regime <= 2) ||
                              (dir < 0 && ctx.regime >= 3);

      g_currentSetup.type = isContinuation ? SETUP_FVG_CONTINUATION : SETUP_FVG_REVERSAL;
      g_currentSetup.name = isContinuation ? "FVG Continuation" : "FVG Reversal";
      g_currentSetup.direction = dir;
      g_currentSetup.score = isContinuation ? 75 : 60;
      g_currentSetup.setupClass = (g_currentSetup.score >= 75) ? "A+" : "A";
      g_currentSetup.barsToEntry = 0;
      g_currentSetup.description = "Gap=" + DoubleToString(gapSize / (_Point * 10), 1) + "p";
   }
   // 3. Range Break
   else if(SETUP_DetectRangeBreak(dir, ctx))
   {
      g_currentSetup.type = SETUP_RANGE_BREAK;
      g_currentSetup.name = "Range Breakout";
      g_currentSetup.direction = dir;
      g_currentSetup.score = 65;
      g_currentSetup.setupClass = "A";
      g_currentSetup.barsToEntry = 0;
      g_currentSetup.description = "Asia break " + ((dir > 0) ? "UP" : "DOWN");
   }
   // 4. VWAP Bounce
   else if(SETUP_DetectVWAPBounce(dir, ctx))
   {
      g_currentSetup.type = SETUP_VWAP_BOUNCE;
      g_currentSetup.name = "VWAP Bounce";
      g_currentSetup.direction = dir;
      g_currentSetup.score = 60;
      g_currentSetup.setupClass = "A";
      g_currentSetup.barsToEntry = 0;
   }
   // 5. Momentum Fade
   else if(SETUP_DetectMomentumFade(dir, ctx))
   {
      g_currentSetup.type = SETUP_MOMENTUM_FADE;
      g_currentSetup.name = "Momentum Fade";
      g_currentSetup.direction = dir;
      g_currentSetup.score = 55;
      g_currentSetup.setupClass = "A";
      g_currentSetup.barsToEntry = 0;
   }
   // 6. S/D Bounce
   else if(SETUP_DetectSDBounce(dir, ctx))
   {
      g_currentSetup.type = SETUP_SD_BOUNCE;
      g_currentSetup.name = "SD Bounce";
      g_currentSetup.direction = dir;
      g_currentSetup.score = 55;
      g_currentSetup.setupClass = "A";
      g_currentSetup.barsToEntry = 0;
   }

   // Фильтр по минимальному score
   if(g_currentSetup.score < MinSetupScore)
   {
      g_currentSetup.type = SETUP_NONE;
      g_currentSetup.setupClass = "S";
   }
}

//+------------------------------------------------------------------+
//| Получить текущий сетап                                             |
//+------------------------------------------------------------------+
string SETUP_GetCurrentName()
{
   if(g_currentSetup.type == SETUP_NONE) return "None";
   return g_currentSetup.name + " (" + g_currentSetup.setupClass + ")";
}

bool SETUP_IsActive()
{
   return (g_currentSetup.type != SETUP_NONE);
}

#endif
