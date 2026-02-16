#ifndef __CLAUDE_V600_PP_FIB_PIVOT_MQH__
#define __CLAUDE_V600_PP_FIB_PIVOT_MQH__
#property strict

// ==================== АГЕНТ 10: WEEKLY FIB PIVOT ====================
// Источник: Davit's Pivot Trading (Forex Factory, 5000+ постов, 10+ лет)
// Формулы: ПОЛНОСТЬЮ ВСТРОЕННЫЕ (без iCustom)

struct FibPivotLevels
{
   // Недельные
   double w_pivot;
   double w_range;
   double w_R38, w_R61, w_R78, w_R100, w_R138, w_R161, w_R200;
   double w_S38, w_S61, w_S78, w_S100, w_S138, w_S161, w_S200;

   // Дневные (опционально)
   double d_pivot;
   double d_range;
   double d_R38, d_R61, d_R78, d_R100;
   double d_S38, d_S61, d_S78, d_S100;

   // Мета-данные
   int    w_zone;          // 0=у Pivot, 1=0-38, 2=38-61, 3=61-78, 4=78-100, 5=>100
   int    w_bias;          // +1=выше Pivot, -1=ниже Pivot
   double dist_to_nearest; // пипсы до ближайшего уровня
   string nearest_level;   // "R61", "S78" и т.д.
};

struct PivotContext
{
   int    w_zone;
   int    w_bias;
   int    d_zone;
   int    d_bias;
   bool   weekly_daily_agree;
   double adr_used_pct;
   bool   adr_exhausted;
   bool   above_asia_high;
   bool   below_asia_low;
   bool   above_london_high;
   bool   below_london_low;
   bool   fib_confluence;
   string confluence_desc;
};

struct FibTPTargets
{
   double target_2R;
   double target_3R;
   double target_5R;
   double target_7R;
   double target_13R;
   string target_names[5];
};

FibPivotLevels g_fib;
datetime g_fibLastWeek = 0;
datetime g_fibLastDay  = 0;

//+------------------------------------------------------------------+
//| Инициализация Fib Pivot                                            |
//+------------------------------------------------------------------+
bool FibPivot_Init()
{
   if(!Agent_FibPivot_Enabled) return true;

   ZeroMemory(g_fib);
   FibPivot_Calculate();

   return true;
}

//+------------------------------------------------------------------+
//| Деинициализация                                                    |
//+------------------------------------------------------------------+
void FibPivot_Deinit()
{
   FibPivot_DeleteObjects();
}

//+------------------------------------------------------------------+
//| Рассчитать Fib Pivot уровни                                        |
//+------------------------------------------------------------------+
void FibPivot_Calculate()
{
   // === НЕДЕЛЬНЫЕ ===
   double prevH = iHigh(_Symbol, PERIOD_W1, 1);
   double prevL = iLow(_Symbol, PERIOD_W1, 1);
   double prevC = iClose(_Symbol, PERIOD_W1, 1);
   double prevO = iOpen(_Symbol, PERIOD_W1, 1);

   if(prevH == 0 || prevL == 0) return;

   // Метод расчёта Pivot
   switch(PivotCalcMethod)
   {
      case PIVOT_HLC:  g_fib.w_pivot = (prevH + prevL + prevC) / 3.0; break;
      case PIVOT_HLCC: g_fib.w_pivot = (prevH + prevL + prevC + prevC) / 4.0; break;
      case PIVOT_HLOC: g_fib.w_pivot = (prevH + prevL + prevO + prevC) / 4.0; break;
   }

   g_fib.w_range = prevH - prevL;

   // Fibonacci уровни сопротивления
   g_fib.w_R38  = g_fib.w_pivot + g_fib.w_range * 0.382;
   g_fib.w_R61  = g_fib.w_pivot + g_fib.w_range * 0.618;
   g_fib.w_R78  = g_fib.w_pivot + g_fib.w_range * 0.786;
   g_fib.w_R100 = g_fib.w_pivot + g_fib.w_range * 1.000;
   g_fib.w_R138 = g_fib.w_pivot + g_fib.w_range * 1.382;
   g_fib.w_R161 = g_fib.w_pivot + g_fib.w_range * 1.618;
   g_fib.w_R200 = g_fib.w_pivot + g_fib.w_range * 2.000;

   // Fibonacci уровни поддержки
   g_fib.w_S38  = g_fib.w_pivot - g_fib.w_range * 0.382;
   g_fib.w_S61  = g_fib.w_pivot - g_fib.w_range * 0.618;
   g_fib.w_S78  = g_fib.w_pivot - g_fib.w_range * 0.786;
   g_fib.w_S100 = g_fib.w_pivot - g_fib.w_range * 1.000;
   g_fib.w_S138 = g_fib.w_pivot - g_fib.w_range * 1.382;
   g_fib.w_S161 = g_fib.w_pivot - g_fib.w_range * 1.618;
   g_fib.w_S200 = g_fib.w_pivot - g_fib.w_range * 2.000;

   // === ДНЕВНЫЕ ===
   if(EnableDailyPivot)
   {
      double dH = iHigh(_Symbol, PERIOD_D1, 1);
      double dL = iLow(_Symbol, PERIOD_D1, 1);
      double dC = iClose(_Symbol, PERIOD_D1, 1);

      if(dH > 0 && dL > 0)
      {
         g_fib.d_pivot = (dH + dL + dC) / 3.0;
         g_fib.d_range = dH - dL;

         g_fib.d_R38  = g_fib.d_pivot + g_fib.d_range * 0.382;
         g_fib.d_R61  = g_fib.d_pivot + g_fib.d_range * 0.618;
         g_fib.d_R78  = g_fib.d_pivot + g_fib.d_range * 0.786;
         g_fib.d_R100 = g_fib.d_pivot + g_fib.d_range * 1.000;

         g_fib.d_S38  = g_fib.d_pivot - g_fib.d_range * 0.382;
         g_fib.d_S61  = g_fib.d_pivot - g_fib.d_range * 0.618;
         g_fib.d_S78  = g_fib.d_pivot - g_fib.d_range * 0.786;
         g_fib.d_S100 = g_fib.d_pivot - g_fib.d_range * 1.000;
      }
   }

   // === ОПРЕДЕЛЕНИЕ ЗОНЫ И BIAS ===
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   g_fib.w_bias = (price > g_fib.w_pivot) ? +1 : -1;

   double distFromPivot = MathAbs(price - g_fib.w_pivot);
   double pctOfRange = (g_fib.w_range > 0) ? distFromPivot / g_fib.w_range : 0;

   if(pctOfRange < 0.10)      g_fib.w_zone = 0;  // У Pivot
   else if(pctOfRange < 0.382) g_fib.w_zone = 1;  // 0-38
   else if(pctOfRange < 0.618) g_fib.w_zone = 2;  // 38-61
   else if(pctOfRange < 0.786) g_fib.w_zone = 3;  // 61-78 ← ЗОНА ДАВИДА
   else if(pctOfRange < 1.000) g_fib.w_zone = 4;  // 78-100 ← ЗОНА КАРНИ
   else                        g_fib.w_zone = 5;  // >100

   // === БЛИЖАЙШИЙ УРОВЕНЬ ===
   FibPivot_FindNearest(price);
}

//+------------------------------------------------------------------+
//| Найти ближайший Fib уровень к текущей цене                         |
//+------------------------------------------------------------------+
void FibPivot_FindNearest(double price)
{
   double levels[] = {g_fib.w_pivot,
                       g_fib.w_R38, g_fib.w_R61, g_fib.w_R78, g_fib.w_R100,
                       g_fib.w_R138, g_fib.w_R161, g_fib.w_R200,
                       g_fib.w_S38, g_fib.w_S61, g_fib.w_S78, g_fib.w_S100,
                       g_fib.w_S138, g_fib.w_S161, g_fib.w_S200};
   string names[]  = {"WP",
                       "R38","R61","R78","R100","R138","R161","R200",
                       "S38","S61","S78","S100","S138","S161","S200"};

   double minDist = DBL_MAX;
   int minIdx = 0;

   for(int i = 0; i < ArraySize(levels); i++)
   {
      double dist = MathAbs(price - levels[i]);
      if(dist < minDist)
      {
         minDist = dist;
         minIdx = i;
      }
   }

   g_fib.dist_to_nearest = minDist / (_Point * 10.0);  // В пипсах
   g_fib.nearest_level = names[minIdx];
}

//+------------------------------------------------------------------+
//| Мульти-масштабный анализ                                           |
//+------------------------------------------------------------------+
void FibPivot_AnalyzeContext(MarketContext &ctx, PivotContext &pctx)
{
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // 1. Дневной bias
   if(EnableDailyPivot && g_fib.d_pivot > 0)
   {
      pctx.d_bias = (price > g_fib.d_pivot) ? +1 : -1;
      double dDist = MathAbs(price - g_fib.d_pivot);
      double dPct = (g_fib.d_range > 0) ? dDist / g_fib.d_range : 0;
      if(dPct < 0.382)      pctx.d_zone = 1;
      else if(dPct < 0.618) pctx.d_zone = 2;
      else if(dPct < 0.786) pctx.d_zone = 3;
      else if(dPct < 1.000) pctx.d_zone = 4;
      else                   pctx.d_zone = 5;
   }
   else
   {
      pctx.d_bias = 0;
      pctx.d_zone = 0;
   }

   // 2. Согласованность
   pctx.weekly_daily_agree = (g_fib.w_bias == pctx.d_bias);

   // 3. ADR исчерпание
   pctx.adr_used_pct = ctx.adr_used_pct;
   pctx.adr_exhausted = (pctx.adr_used_pct > 80.0);

   // 4. Положение vs сессии
   pctx.above_asia_high  = (price > ctx.asia_high && ctx.asia_high > 0);
   pctx.below_asia_low   = (price < ctx.asia_low && ctx.asia_low > 0);
   pctx.above_london_high = (price > ctx.london_high && ctx.london_high > 0);
   pctx.below_london_low  = (price < ctx.london_low && ctx.london_low > 0);

   // 5. Конфлюэнс: Fib уровень совпадает с сессионным?
   double tolerance = 5.0 * _Point * 10; // 5 пипсов
   pctx.fib_confluence = false;
   pctx.confluence_desc = "";

   double fibLevels[] = {g_fib.w_R38, g_fib.w_R61, g_fib.w_R78, g_fib.w_R100,
                          g_fib.w_S38, g_fib.w_S61, g_fib.w_S78, g_fib.w_S100};
   string fibNames[]  = {"W_R38","W_R61","W_R78","W_R100",
                          "W_S38","W_S61","W_S78","W_S100"};
   double sessLevels[] = {ctx.asia_high, ctx.asia_low, ctx.london_high,
                           ctx.london_low, ctx.pdh, ctx.pdl};
   string sessNames[]  = {"AsiaH","AsiaL","LondonH","LondonL","PDH","PDL"};

   for(int i = 0; i < 8; i++)
   {
      for(int j = 0; j < 6; j++)
      {
         if(sessLevels[j] > 0 && MathAbs(fibLevels[i] - sessLevels[j]) < tolerance)
         {
            pctx.fib_confluence = true;
            pctx.confluence_desc = fibNames[i] + " ~ " + sessNames[j];
            break;
         }
      }
      if(pctx.fib_confluence) break;
   }
}

//+------------------------------------------------------------------+
//| Scoring Агента 10 (генерация score)                                |
//+------------------------------------------------------------------+
int FibPivot_Score(MarketContext &ctx)
{
   PivotContext pctx;
   FibPivot_AnalyzeContext(ctx, pctx);

   int score = 0;
   int bias = g_fib.w_bias;

   // === ЗОНА 61-78 (основная торговая зона Давида) ===
   if(g_fib.w_zone == 3)
   {
      score = -bias * 55;  // Против bias = возврат к Pivot

      if(!pctx.weekly_daily_agree) score += (-bias) * 10;
      if(pctx.adr_exhausted) score += (-bias) * 10;
   }
   // === ЗОНА 78-100 (зона Карни) ===
   else if(g_fib.w_zone == 4)
   {
      score = -bias * 70;

      if(!pctx.weekly_daily_agree) score += (-bias) * 10;
      if(pctx.adr_exhausted) score += (-bias) * 10;

      if(bias > 0 && pctx.above_london_high) score -= 10;
      if(bias < 0 && pctx.below_london_low)  score += 10;
   }
   // === ЗОНА >100 (пробой — сильный тренд) ===
   else if(g_fib.w_zone == 5)
   {
      score = bias * 30;

      if(!pctx.adr_exhausted) score += bias * 10;
   }
   // === ЗОНА 38-61 (переходная) ===
   else if(g_fib.w_zone == 2)
   {
      score = -bias * 25;
   }
   // === ЗОНА 0-38 и у Pivot (нейтрально) ===
   else
   {
      score = 0;
   }

   // === БОНУС КОНФЛЮЭНС ===
   if(pctx.fib_confluence)
   {
      score = (int)(score * 1.3);  // +30%
   }

   return MathMax(-100, MathMin(100, score));
}

//+------------------------------------------------------------------+
//| Рассчитать TP targets (Fib уровни как цели)                        |
//+------------------------------------------------------------------+
void FibPivot_CalcTPTargets(int direction, double entryPrice, FibTPTargets &tp)
{
   ZeroMemory(tp);

   // Собираем все уровни
   double allLevels[15];
   string allNames[15];

   allLevels[0]  = g_fib.w_R38;  allNames[0]  = "R38";
   allLevels[1]  = g_fib.w_R61;  allNames[1]  = "R61";
   allLevels[2]  = g_fib.w_R78;  allNames[2]  = "R78";
   allLevels[3]  = g_fib.w_R100; allNames[3]  = "R100";
   allLevels[4]  = g_fib.w_R138; allNames[4]  = "R138";
   allLevels[5]  = g_fib.w_R161; allNames[5]  = "R161";
   allLevels[6]  = g_fib.w_R200; allNames[6]  = "R200";
   allLevels[7]  = g_fib.w_S38;  allNames[7]  = "S38";
   allLevels[8]  = g_fib.w_S61;  allNames[8]  = "S61";
   allLevels[9]  = g_fib.w_S78;  allNames[9]  = "S78";
   allLevels[10] = g_fib.w_S100; allNames[10] = "S100";
   allLevels[11] = g_fib.w_S138; allNames[11] = "S138";
   allLevels[12] = g_fib.w_S161; allNames[12] = "S161";
   allLevels[13] = g_fib.w_S200; allNames[13] = "S200";
   allLevels[14] = g_fib.w_pivot; allNames[14] = "WP";

   // Добавить дневные если есть
   if(EnableDailyPivot && g_fib.d_pivot > 0)
   {
      // Дневные уже учтены через TP
   }

   // Фильтруем и сортируем по направлению
   double targets[];
   string tNames[];
   int count = 0;

   for(int i = 0; i < 15; i++)
   {
      if(direction > 0 && allLevels[i] > entryPrice)  // LONG: уровни выше
      {
         ArrayResize(targets, count + 1);
         ArrayResize(tNames, count + 1);
         targets[count] = allLevels[i];
         tNames[count]  = allNames[i];
         count++;
      }
      else if(direction < 0 && allLevels[i] < entryPrice)  // SHORT: уровни ниже
      {
         ArrayResize(targets, count + 1);
         ArrayResize(tNames, count + 1);
         targets[count] = allLevels[i];
         tNames[count]  = allNames[i];
         count++;
      }
   }

   // Сортировка: LONG по возрастанию, SHORT по убыванию
   for(int i = 0; i < count - 1; i++)
   {
      for(int j = i + 1; j < count; j++)
      {
         bool swap = false;
         if(direction > 0 && targets[j] < targets[i]) swap = true;
         if(direction < 0 && targets[j] > targets[i]) swap = true;

         if(swap)
         {
            double tmpD = targets[i]; targets[i] = targets[j]; targets[j] = tmpD;
            string tmpS = tNames[i];  tNames[i] = tNames[j];   tNames[j] = tmpS;
         }
      }
   }

   // Заполнить targets
   if(count >= 1) { tp.target_2R = targets[0]; tp.target_names[0] = tNames[0]; }
   if(count >= 2) { tp.target_3R = targets[1]; tp.target_names[1] = tNames[1]; }
   if(count >= 3) { tp.target_5R = targets[2]; tp.target_names[2] = tNames[2]; }
   if(count >= 4) { tp.target_7R = targets[3]; tp.target_names[3] = tNames[3]; }
   if(count >= 5) { tp.target_13R = targets[4]; tp.target_names[4] = tNames[4]; }
}

//+------------------------------------------------------------------+
//| Запустить Агент 10                                                 |
//+------------------------------------------------------------------+
void FibPivot_RunAgent(AgentSignal &signals[], MarketContext &ctx)
{
   signals[9].name = "FibPivot";
   signals[9].enabled = Agent_FibPivot_Enabled;
   signals[9].weight = FibPivot_Weight;
   signals[9].confidence = 0.75;
   signals[9].score = 0;

   if(!Agent_FibPivot_Enabled) return;

   // Пересчёт при смене W1 бара
   datetime curWeek = iTime(_Symbol, PERIOD_W1, 0);
   if(curWeek != g_fibLastWeek)
   {
      FibPivot_Calculate();
      g_fibLastWeek = curWeek;
   }

   // Пересчёт дневных при смене D1 бара
   if(EnableDailyPivot)
   {
      datetime curDay = iTime(_Symbol, PERIOD_D1, 0);
      if(curDay != g_fibLastDay)
      {
         // Пересчитать только дневные
         double dH = iHigh(_Symbol, PERIOD_D1, 1);
         double dL = iLow(_Symbol, PERIOD_D1, 1);
         double dC = iClose(_Symbol, PERIOD_D1, 1);

         if(dH > 0 && dL > 0)
         {
            g_fib.d_pivot = (dH + dL + dC) / 3.0;
            g_fib.d_range = dH - dL;

            g_fib.d_R38  = g_fib.d_pivot + g_fib.d_range * 0.382;
            g_fib.d_R61  = g_fib.d_pivot + g_fib.d_range * 0.618;
            g_fib.d_R78  = g_fib.d_pivot + g_fib.d_range * 0.786;
            g_fib.d_R100 = g_fib.d_pivot + g_fib.d_range * 1.000;

            g_fib.d_S38  = g_fib.d_pivot - g_fib.d_range * 0.382;
            g_fib.d_S61  = g_fib.d_pivot - g_fib.d_range * 0.618;
            g_fib.d_S78  = g_fib.d_pivot - g_fib.d_range * 0.786;
            g_fib.d_S100 = g_fib.d_pivot - g_fib.d_range * 1.000;
         }
         g_fibLastDay = curDay;
      }
   }

   // Обновить зону и bias
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   g_fib.w_bias = (price > g_fib.w_pivot) ? +1 : -1;

   double distFromPivot = MathAbs(price - g_fib.w_pivot);
   double pctOfRange = (g_fib.w_range > 0) ? distFromPivot / g_fib.w_range : 0;

   if(pctOfRange < 0.10)      g_fib.w_zone = 0;
   else if(pctOfRange < 0.382) g_fib.w_zone = 1;
   else if(pctOfRange < 0.618) g_fib.w_zone = 2;
   else if(pctOfRange < 0.786) g_fib.w_zone = 3;
   else if(pctOfRange < 1.000) g_fib.w_zone = 4;
   else                        g_fib.w_zone = 5;

   FibPivot_FindNearest(price);

   // Заполнить контекст
   ctx.pivot_weekly      = g_fib.w_pivot;
   ctx.pivot_zone        = g_fib.w_zone;
   ctx.pivot_bias        = g_fib.w_bias;
   ctx.pivot_daily       = g_fib.d_pivot;
   ctx.pivot_daily_zone  = 0;
   ctx.pivot_nearest_name = g_fib.nearest_level;

   // Score
   signals[9].score = FibPivot_Score(ctx);

   // Визуализация
   if(DrawFibPivotLines)
   {
      if(PivotDrawMode == PIVOT_FULL_WEEK)
         FibPivot_DrawFullWeek();
      else
         FibPivot_DrawShortSide();
   }
}

//+------------------------------------------------------------------+
//| Отображение: Full Week (линии на всю ширину текущей недели)        |
//+------------------------------------------------------------------+
void FibPivot_DrawFullWeek()
{
   datetime weekStart = iTime(_Symbol, PERIOD_W1, 0);
   datetime now = TimeCurrent();
   datetime lineEnd = now + PeriodSeconds(_Period) * 10;

   // Weekly Pivot
   FibPivot_DrawLevel("FP_W_Pivot", g_fib.w_pivot, g_scheme.pivotLine,
                       STYLE_DASH, 2, weekStart, lineEnd, "WP");

   // R levels
   FibPivot_DrawLevel("FP_W_R38",  g_fib.w_R38,  g_scheme.pivotR38,
                       STYLE_DOT, 1, weekStart, lineEnd, "R38");
   FibPivot_DrawLevel("FP_W_R61",  g_fib.w_R61,  g_scheme.pivotR61,
                       STYLE_SOLID, 1, weekStart, lineEnd, "R61");
   FibPivot_DrawLevel("FP_W_R78",  g_fib.w_R78,  g_scheme.pivotR78,
                       STYLE_SOLID, 1, weekStart, lineEnd, "R78");
   FibPivot_DrawLevel("FP_W_R100", g_fib.w_R100, g_scheme.pivotR100,
                       STYLE_SOLID, 2, weekStart, lineEnd, "R100");
   FibPivot_DrawLevel("FP_W_R138", g_fib.w_R138, g_scheme.pivotR138,
                       STYLE_DOT, 1, weekStart, lineEnd, "R138");
   FibPivot_DrawLevel("FP_W_R161", g_fib.w_R161, g_scheme.pivotR161,
                       STYLE_DOT, 1, weekStart, lineEnd, "R161");
   FibPivot_DrawLevel("FP_W_R200", g_fib.w_R200, g_scheme.pivotR200,
                       STYLE_DASHDOT, 1, weekStart, lineEnd, "R200");

   // S levels
   FibPivot_DrawLevel("FP_W_S38",  g_fib.w_S38,  g_scheme.pivotR38,
                       STYLE_DOT, 1, weekStart, lineEnd, "S38");
   FibPivot_DrawLevel("FP_W_S61",  g_fib.w_S61,  g_scheme.pivotR61,
                       STYLE_SOLID, 1, weekStart, lineEnd, "S61");
   FibPivot_DrawLevel("FP_W_S78",  g_fib.w_S78,  g_scheme.pivotR78,
                       STYLE_SOLID, 1, weekStart, lineEnd, "S78");
   FibPivot_DrawLevel("FP_W_S100", g_fib.w_S100, g_scheme.pivotR100,
                       STYLE_SOLID, 2, weekStart, lineEnd, "S100");
   FibPivot_DrawLevel("FP_W_S138", g_fib.w_S138, g_scheme.pivotR138,
                       STYLE_DOT, 1, weekStart, lineEnd, "S138");
   FibPivot_DrawLevel("FP_W_S161", g_fib.w_S161, g_scheme.pivotR161,
                       STYLE_DOT, 1, weekStart, lineEnd, "S161");
   FibPivot_DrawLevel("FP_W_S200", g_fib.w_S200, g_scheme.pivotR200,
                       STYLE_DASHDOT, 1, weekStart, lineEnd, "S200");

   // Daily Pivots
   if(EnableDailyPivot && g_fib.d_pivot > 0)
   {
      datetime dayStart = iTime(_Symbol, PERIOD_D1, 0);
      FibPivot_DrawLevel("FP_D_Pivot", g_fib.d_pivot, g_scheme.pivotDaily,
                          STYLE_DASHDOT, 1, dayStart, lineEnd, "DP");
      FibPivot_DrawLevel("FP_D_R61", g_fib.d_R61, g_scheme.pivotDaily,
                          STYLE_DOT, 1, dayStart, lineEnd, "D_R61");
      FibPivot_DrawLevel("FP_D_S61", g_fib.d_S61, g_scheme.pivotDaily,
                          STYLE_DOT, 1, dayStart, lineEnd, "D_S61");
   }
}

//+------------------------------------------------------------------+
//| Отображение: Short Side (40 баров справа)                          |
//+------------------------------------------------------------------+
void FibPivot_DrawShortSide()
{
   datetime barNow = iTime(_Symbol, _Period, 0);
   datetime lineStart = barNow;
   datetime lineEnd = barNow + PeriodSeconds(_Period) * 40;

   FibPivot_DrawLevel("FP_W_Pivot", g_fib.w_pivot, g_scheme.pivotLine,
                       STYLE_DASH, 2, lineStart, lineEnd, "WP");

   FibPivot_DrawLevel("FP_W_R38",  g_fib.w_R38,  g_scheme.pivotR38,
                       STYLE_DOT, 1, lineStart, lineEnd, "R38");
   FibPivot_DrawLevel("FP_W_R61",  g_fib.w_R61,  g_scheme.pivotR61,
                       STYLE_SOLID, 1, lineStart, lineEnd, "R61");
   FibPivot_DrawLevel("FP_W_R78",  g_fib.w_R78,  g_scheme.pivotR78,
                       STYLE_SOLID, 1, lineStart, lineEnd, "R78");
   FibPivot_DrawLevel("FP_W_R100", g_fib.w_R100, g_scheme.pivotR100,
                       STYLE_SOLID, 2, lineStart, lineEnd, "R100");

   FibPivot_DrawLevel("FP_W_S38",  g_fib.w_S38,  g_scheme.pivotR38,
                       STYLE_DOT, 1, lineStart, lineEnd, "S38");
   FibPivot_DrawLevel("FP_W_S61",  g_fib.w_S61,  g_scheme.pivotR61,
                       STYLE_SOLID, 1, lineStart, lineEnd, "S61");
   FibPivot_DrawLevel("FP_W_S78",  g_fib.w_S78,  g_scheme.pivotR78,
                       STYLE_SOLID, 1, lineStart, lineEnd, "S78");
   FibPivot_DrawLevel("FP_W_S100", g_fib.w_S100, g_scheme.pivotR100,
                       STYLE_SOLID, 2, lineStart, lineEnd, "S100");

   if(EnableDailyPivot && g_fib.d_pivot > 0)
   {
      FibPivot_DrawLevel("FP_D_Pivot", g_fib.d_pivot, g_scheme.pivotDaily,
                          STYLE_DASHDOT, 1, lineStart, lineEnd, "DP");
   }
}

//+------------------------------------------------------------------+
//| Вспомогательная: рисовать линию с подписью                         |
//+------------------------------------------------------------------+
void FibPivot_DrawLevel(string name, double price, color clr,
                         ENUM_LINE_STYLE style, int width,
                         datetime t1, datetime t2, string label)
{
   // Линия
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

   // Подпись
   string lblName = name + "_lbl";
   if(ObjectFind(0, lblName) < 0)
      ObjectCreate(0, lblName, OBJ_TEXT, 0, t2, price);

   ObjectSetDouble(0, lblName, OBJPROP_PRICE, price);
   ObjectSetInteger(0, lblName, OBJPROP_TIME, t2);
   ObjectSetString(0, lblName, OBJPROP_TEXT,
      label + " " + DoubleToString(price, _Digits));
   ObjectSetInteger(0, lblName, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, lblName, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, lblName, OBJPROP_ANCHOR, ANCHOR_LEFT);
   ObjectSetInteger(0, lblName, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Удалить все объекты Fib Pivot                                      |
//+------------------------------------------------------------------+
void FibPivot_DeleteObjects()
{
   int total = ObjectsTotal(0);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, "FP_") == 0)
         ObjectDelete(0, name);
   }
}

//+------------------------------------------------------------------+
//| Получить название зоны                                             |
//+------------------------------------------------------------------+
string FibPivot_ZoneName(int zone, int bias)
{
   string dir = (bias > 0) ? "R" : "S";
   switch(zone)
   {
      case 0: return "Pivot";
      case 1: return dir + "0-38";
      case 2: return dir + "38-61";
      case 3: return dir + "61-78";
      case 4: return dir + "78-100";
      case 5: return dir + ">100";
   }
   return "Unknown";
}

#endif
