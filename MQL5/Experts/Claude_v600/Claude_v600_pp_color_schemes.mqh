#ifndef __CLAUDE_V600_PP_COLOR_SCHEMES_MQH__
#define __CLAUDE_V600_PP_COLOR_SCHEMES_MQH__
#property strict

// ==================== ЦВЕТОВЫЕ СХЕМЫ ====================
// 5 схем: Deep Ocean, Warm Sand, Night Violet, Cream Classic, Espresso
// 53+ цветовых полей включая Fib Pivot и News

struct ColorSchemeData
{
   // === Панель (11 полей) ===
   color panelBackground;
   color panelBorder;
   color textPrimary;
   color textSecondary;
   color textHighlight;
   color btnLongBg;
   color btnLongText;
   color btnShortBg;
   color btnShortText;
   color btnCloseBg;
   color btnCloseText;

   // === График (11 полей) ===
   color chartBackground;
   color chartForeground;
   color chartGrid;
   color chartBullCandle;
   color chartBearCandle;
   color chartBullOutline;
   color chartBearOutline;
   color chartLineAsk;
   color chartLineBid;
   color chartVolumeUp;
   color chartVolumeDown;

   // === Агенты (10 полей) ===
   color agentBarPositive;
   color agentBarNegative;
   color agentBarNeutral;
   color agentDecisionBuy;
   color agentDecisionSell;
   color agentDecisionNone;
   color agentTextScore;
   color agentTextName;
   color agentBarBg;
   color agentBorder;

   // === Better Volume (6 полей) ===
   color bvClimaxHigh;
   color bvClimaxLow;
   color bvHighChurn;
   color bvLowVolume;
   color bvClimaxChurn;
   color bvNeutral;

   // === PVSRA (4 поля) — стандарт, одинаковы для всех схем ===
   color pvsraBullClimax;
   color pvsraBearClimax;
   color pvsraBullRising;
   color pvsraBearRising;

   // === REI (3 поля) ===
   color reiOverbought;
   color reiOversold;
   color reiNeutral;

   // === WPR (2 поля) ===
   color wprOverbought;
   color wprOversold;

   // === Сетапы (3 поля) ===
   color setupA;
   color setupAPlus;
   color setupSkip;

   // === Новости (3 поля) ===
   color newsHigh;
   color newsMedium;
   color newsLow;

   // === Fib Pivot (9 полей) ===
   color pivotLine;
   color pivotR38;
   color pivotR61;
   color pivotR78;
   color pivotR100;
   color pivotR138;
   color pivotR161;
   color pivotR200;
   color pivotDaily;
};

ColorSchemeData g_scheme;

//+------------------------------------------------------------------+
//| Инициализация цветовой схемы                                       |
//+------------------------------------------------------------------+
void InitColorScheme(ENUM_COLOR_SCHEME scheme)
{
   // PVSRA — стандартные цвета (одинаковые для всех схем)
   g_scheme.pvsraBullClimax  = C'0,255,0';
   g_scheme.pvsraBearClimax  = C'255,0,0';
   g_scheme.pvsraBullRising  = C'0,128,0';
   g_scheme.pvsraBearRising  = C'128,0,0';

   switch(scheme)
   {
      case SCHEME_DEEP_OCEAN:    InitDeepOcean();    break;
      case SCHEME_WARM_SAND:     InitWarmSand();     break;
      case SCHEME_NIGHT_VIOLET:  InitNightViolet();  break;
      case SCHEME_CREAM_CLASSIC: InitCreamClassic(); break;
      case SCHEME_ESPRESSO:      InitEspresso();     break;
      default:                   InitNightViolet();  break;
   }
}

//+------------------------------------------------------------------+
//| Deep Ocean                                                         |
//+------------------------------------------------------------------+
void InitDeepOcean()
{
   // Панель
   g_scheme.panelBackground = C'15,25,45';
   g_scheme.panelBorder     = C'40,60,90';
   g_scheme.textPrimary     = C'200,210,230';
   g_scheme.textSecondary   = C'120,140,170';
   g_scheme.textHighlight   = C'100,200,255';
   g_scheme.btnLongBg       = C'20,80,60';
   g_scheme.btnLongText     = C'100,255,180';
   g_scheme.btnShortBg      = C'80,20,60';
   g_scheme.btnShortText    = C'255,100,180';
   g_scheme.btnCloseBg      = C'80,30,30';
   g_scheme.btnCloseText    = C'255,120,120';

   // График
   g_scheme.chartBackground = C'10,18,35';
   g_scheme.chartForeground = C'120,140,170';
   g_scheme.chartGrid       = C'25,40,65';
   g_scheme.chartBullCandle = C'40,180,120';
   g_scheme.chartBearCandle = C'220,60,80';
   g_scheme.chartBullOutline= C'30,140,90';
   g_scheme.chartBearOutline= C'180,40,60';
   g_scheme.chartLineAsk    = C'100,200,255';
   g_scheme.chartLineBid    = C'255,100,100';
   g_scheme.chartVolumeUp   = C'40,180,120';
   g_scheme.chartVolumeDown = C'220,60,80';

   // Агенты
   g_scheme.agentBarPositive = C'40,180,120';
   g_scheme.agentBarNegative = C'220,60,80';
   g_scheme.agentBarNeutral  = C'80,100,130';
   g_scheme.agentDecisionBuy = C'40,220,140';
   g_scheme.agentDecisionSell= C'255,60,90';
   g_scheme.agentDecisionNone= C'120,140,170';
   g_scheme.agentTextScore   = C'200,210,230';
   g_scheme.agentTextName    = C'150,170,200';
   g_scheme.agentBarBg       = C'30,45,70';
   g_scheme.agentBorder      = C'40,60,90';

   // Better Volume
   g_scheme.bvClimaxHigh  = C'255,0,0';
   g_scheme.bvClimaxLow   = C'255,255,255';
   g_scheme.bvHighChurn   = C'255,0,255';
   g_scheme.bvLowVolume   = C'255,255,0';
   g_scheme.bvClimaxChurn = C'255,140,0';
   g_scheme.bvNeutral     = C'100,149,237';

   // REI
   g_scheme.reiOverbought = C'255,80,80';
   g_scheme.reiOversold   = C'80,255,80';
   g_scheme.reiNeutral    = C'120,140,170';

   // WPR
   g_scheme.wprOverbought = C'255,80,80';
   g_scheme.wprOversold   = C'80,255,80';

   // Сетапы
   g_scheme.setupA     = C'100,200,100';
   g_scheme.setupAPlus = C'255,215,0';
   g_scheme.setupSkip  = C'120,120,120';

   // Новости
   g_scheme.newsHigh   = C'212,60,60';
   g_scheme.newsMedium = C'212,160,60';
   g_scheme.newsLow    = C'180,180,100';

   // Fib Pivot
   g_scheme.pivotLine  = C'255,215,0';
   g_scheme.pivotR38   = C'180,100,200';
   g_scheme.pivotR61   = C'50,205,50';
   g_scheme.pivotR78   = C'220,60,60';
   g_scheme.pivotR100  = C'0,200,200';
   g_scheme.pivotR138  = C'230,160,50';
   g_scheme.pivotR161  = C'160,160,160';
   g_scheme.pivotR200  = C'140,130,80';
   g_scheme.pivotDaily = C'120,120,60';
}

//+------------------------------------------------------------------+
//| Warm Sand                                                          |
//+------------------------------------------------------------------+
void InitWarmSand()
{
   // Панель
   g_scheme.panelBackground = C'50,40,30';
   g_scheme.panelBorder     = C'90,75,55';
   g_scheme.textPrimary     = C'230,215,190';
   g_scheme.textSecondary   = C'170,150,120';
   g_scheme.textHighlight   = C'255,200,100';
   g_scheme.btnLongBg       = C'50,80,40';
   g_scheme.btnLongText     = C'150,230,130';
   g_scheme.btnShortBg      = C'90,40,40';
   g_scheme.btnShortText    = C'255,150,130';
   g_scheme.btnCloseBg      = C'90,40,30';
   g_scheme.btnCloseText    = C'255,140,100';

   // График
   g_scheme.chartBackground = C'40,33,25';
   g_scheme.chartForeground = C'170,150,120';
   g_scheme.chartGrid       = C'60,50,38';
   g_scheme.chartBullCandle = C'120,180,80';
   g_scheme.chartBearCandle = C'210,90,60';
   g_scheme.chartBullOutline= C'90,140,60';
   g_scheme.chartBearOutline= C'180,70,45';
   g_scheme.chartLineAsk    = C'255,200,100';
   g_scheme.chartLineBid    = C'255,120,80';
   g_scheme.chartVolumeUp   = C'120,180,80';
   g_scheme.chartVolumeDown = C'210,90,60';

   // Агенты
   g_scheme.agentBarPositive = C'120,180,80';
   g_scheme.agentBarNegative = C'210,90,60';
   g_scheme.agentBarNeutral  = C'130,115,90';
   g_scheme.agentDecisionBuy = C'140,210,100';
   g_scheme.agentDecisionSell= C'255,90,70';
   g_scheme.agentDecisionNone= C'170,150,120';
   g_scheme.agentTextScore   = C'230,215,190';
   g_scheme.agentTextName    = C'190,170,140';
   g_scheme.agentBarBg       = C'60,50,38';
   g_scheme.agentBorder      = C'90,75,55';

   // Better Volume
   g_scheme.bvClimaxHigh  = C'220,50,30';
   g_scheme.bvClimaxLow   = C'240,230,200';
   g_scheme.bvHighChurn   = C'220,80,180';
   g_scheme.bvLowVolume   = C'230,200,80';
   g_scheme.bvClimaxChurn = C'240,150,40';
   g_scheme.bvNeutral     = C'140,160,110';

   // REI
   g_scheme.reiOverbought = C'220,80,60';
   g_scheme.reiOversold   = C'100,200,80';
   g_scheme.reiNeutral    = C'170,150,120';

   // WPR
   g_scheme.wprOverbought = C'220,80,60';
   g_scheme.wprOversold   = C'100,200,80';

   // Сетапы
   g_scheme.setupA     = C'120,190,80';
   g_scheme.setupAPlus = C'255,200,50';
   g_scheme.setupSkip  = C'130,115,90';

   // Новости
   g_scheme.newsHigh   = C'220,60,40';
   g_scheme.newsMedium = C'220,160,50';
   g_scheme.newsLow    = C'190,180,100';

   // Fib Pivot
   g_scheme.pivotLine  = C'255,210,50';
   g_scheme.pivotR38   = C'190,110,180';
   g_scheme.pivotR61   = C'80,200,80';
   g_scheme.pivotR78   = C'220,60,50';
   g_scheme.pivotR100  = C'50,190,190';
   g_scheme.pivotR138  = C'230,160,50';
   g_scheme.pivotR161  = C'160,150,130';
   g_scheme.pivotR200  = C'140,130,90';
   g_scheme.pivotDaily = C'130,120,70';
}

//+------------------------------------------------------------------+
//| Night Violet                                                       |
//+------------------------------------------------------------------+
void InitNightViolet()
{
   // Панель
   g_scheme.panelBackground = C'25,15,40';
   g_scheme.panelBorder     = C'60,40,85';
   g_scheme.textPrimary     = C'210,200,230';
   g_scheme.textSecondary   = C'140,120,170';
   g_scheme.textHighlight   = C'180,130,255';
   g_scheme.btnLongBg       = C'25,70,50';
   g_scheme.btnLongText     = C'100,240,170';
   g_scheme.btnShortBg      = C'80,25,55';
   g_scheme.btnShortText    = C'255,100,170';
   g_scheme.btnCloseBg      = C'80,25,25';
   g_scheme.btnCloseText    = C'255,110,110';

   // График
   g_scheme.chartBackground = C'18,10,30';
   g_scheme.chartForeground = C'140,120,170';
   g_scheme.chartGrid       = C'35,25,55';
   g_scheme.chartBullCandle = C'60,200,140';
   g_scheme.chartBearCandle = C'230,70,100';
   g_scheme.chartBullOutline= C'40,160,110';
   g_scheme.chartBearOutline= C'200,50,80';
   g_scheme.chartLineAsk    = C'180,130,255';
   g_scheme.chartLineBid    = C'255,100,130';
   g_scheme.chartVolumeUp   = C'60,200,140';
   g_scheme.chartVolumeDown = C'230,70,100';

   // Агенты
   g_scheme.agentBarPositive = C'60,200,140';
   g_scheme.agentBarNegative = C'230,70,100';
   g_scheme.agentBarNeutral  = C'90,75,115';
   g_scheme.agentDecisionBuy = C'80,230,160';
   g_scheme.agentDecisionSell= C'255,70,110';
   g_scheme.agentDecisionNone= C'140,120,170';
   g_scheme.agentTextScore   = C'210,200,230';
   g_scheme.agentTextName    = C'170,155,200';
   g_scheme.agentBarBg       = C'35,25,55';
   g_scheme.agentBorder      = C'60,40,85';

   // Better Volume
   g_scheme.bvClimaxHigh  = C'255,30,60';
   g_scheme.bvClimaxLow   = C'230,220,255';
   g_scheme.bvHighChurn   = C'255,50,200';
   g_scheme.bvLowVolume   = C'240,220,80';
   g_scheme.bvClimaxChurn = C'255,140,30';
   g_scheme.bvNeutral     = C'130,110,180';

   // REI
   g_scheme.reiOverbought = C'255,70,90';
   g_scheme.reiOversold   = C'70,230,130';
   g_scheme.reiNeutral    = C'140,120,170';

   // WPR
   g_scheme.wprOverbought = C'255,70,90';
   g_scheme.wprOversold   = C'70,230,130';

   // Сетапы
   g_scheme.setupA     = C'100,210,120';
   g_scheme.setupAPlus = C'255,210,50';
   g_scheme.setupSkip  = C'90,75,115';

   // Новости
   g_scheme.newsHigh   = C'230,50,60';
   g_scheme.newsMedium = C'220,150,50';
   g_scheme.newsLow    = C'180,170,100';

   // Fib Pivot
   g_scheme.pivotLine  = C'255,215,0';
   g_scheme.pivotR38   = C'200,100,220';
   g_scheme.pivotR61   = C'50,220,50';
   g_scheme.pivotR78   = C'230,50,50';
   g_scheme.pivotR100  = C'0,210,210';
   g_scheme.pivotR138  = C'240,160,40';
   g_scheme.pivotR161  = C'150,140,170';
   g_scheme.pivotR200  = C'130,120,90';
   g_scheme.pivotDaily = C'110,100,70';
}

//+------------------------------------------------------------------+
//| Cream Classic                                                      |
//+------------------------------------------------------------------+
void InitCreamClassic()
{
   // Панель
   g_scheme.panelBackground = C'240,235,220';
   g_scheme.panelBorder     = C'190,180,160';
   g_scheme.textPrimary     = C'40,35,30';
   g_scheme.textSecondary   = C'100,90,75';
   g_scheme.textHighlight   = C'0,80,160';
   g_scheme.btnLongBg       = C'200,230,200';
   g_scheme.btnLongText     = C'0,100,50';
   g_scheme.btnShortBg      = C'235,200,200';
   g_scheme.btnShortText    = C'140,20,40';
   g_scheme.btnCloseBg      = C'220,190,180';
   g_scheme.btnCloseText    = C'150,40,30';

   // График
   g_scheme.chartBackground = C'250,245,235';
   g_scheme.chartForeground = C'80,70,55';
   g_scheme.chartGrid       = C'220,215,200';
   g_scheme.chartBullCandle = C'40,140,80';
   g_scheme.chartBearCandle = C'200,50,60';
   g_scheme.chartBullOutline= C'30,110,60';
   g_scheme.chartBearOutline= C'170,35,45';
   g_scheme.chartLineAsk    = C'0,80,160';
   g_scheme.chartLineBid    = C'200,50,50';
   g_scheme.chartVolumeUp   = C'40,140,80';
   g_scheme.chartVolumeDown = C'200,50,60';

   // Агенты
   g_scheme.agentBarPositive = C'40,140,80';
   g_scheme.agentBarNegative = C'200,50,60';
   g_scheme.agentBarNeutral  = C'170,165,150';
   g_scheme.agentDecisionBuy = C'30,150,80';
   g_scheme.agentDecisionSell= C'210,40,50';
   g_scheme.agentDecisionNone= C'100,90,75';
   g_scheme.agentTextScore   = C'40,35,30';
   g_scheme.agentTextName    = C'80,70,55';
   g_scheme.agentBarBg       = C'220,215,200';
   g_scheme.agentBorder      = C'190,180,160';

   // Better Volume
   g_scheme.bvClimaxHigh  = C'200,30,30';
   g_scheme.bvClimaxLow   = C'50,50,50';
   g_scheme.bvHighChurn   = C'180,30,140';
   g_scheme.bvLowVolume   = C'180,170,50';
   g_scheme.bvClimaxChurn = C'210,120,20';
   g_scheme.bvNeutral     = C'100,130,170';

   // REI
   g_scheme.reiOverbought = C'200,40,40';
   g_scheme.reiOversold   = C'30,150,60';
   g_scheme.reiNeutral    = C'100,90,75';

   // WPR
   g_scheme.wprOverbought = C'200,40,40';
   g_scheme.wprOversold   = C'30,150,60';

   // Сетапы
   g_scheme.setupA     = C'40,150,60';
   g_scheme.setupAPlus = C'200,160,0';
   g_scheme.setupSkip  = C'150,145,130';

   // Новости
   g_scheme.newsHigh   = C'200,40,40';
   g_scheme.newsMedium = C'200,140,30';
   g_scheme.newsLow    = C'160,160,80';

   // Fib Pivot
   g_scheme.pivotLine  = C'200,170,0';
   g_scheme.pivotR38   = C'140,60,160';
   g_scheme.pivotR61   = C'30,160,30';
   g_scheme.pivotR78   = C'200,40,40';
   g_scheme.pivotR100  = C'0,150,150';
   g_scheme.pivotR138  = C'200,130,20';
   g_scheme.pivotR161  = C'120,115,100';
   g_scheme.pivotR200  = C'110,105,80';
   g_scheme.pivotDaily = C'100,95,60';
}

//+------------------------------------------------------------------+
//| Espresso                                                           |
//+------------------------------------------------------------------+
void InitEspresso()
{
   // Панель
   g_scheme.panelBackground = C'35,25,20';
   g_scheme.panelBorder     = C'70,50,40';
   g_scheme.textPrimary     = C'220,200,180';
   g_scheme.textSecondary   = C'150,130,110';
   g_scheme.textHighlight   = C'220,170,100';
   g_scheme.btnLongBg       = C'40,70,35';
   g_scheme.btnLongText     = C'130,220,110';
   g_scheme.btnShortBg      = C'80,30,30';
   g_scheme.btnShortText    = C'240,120,100';
   g_scheme.btnCloseBg      = C'80,35,25';
   g_scheme.btnCloseText    = C'240,130,90';

   // График
   g_scheme.chartBackground = C'28,20,15';
   g_scheme.chartForeground = C'150,130,110';
   g_scheme.chartGrid       = C'45,35,28';
   g_scheme.chartBullCandle = C'80,180,90';
   g_scheme.chartBearCandle = C'220,70,60';
   g_scheme.chartBullOutline= C'60,140,70';
   g_scheme.chartBearOutline= C'190,50,45';
   g_scheme.chartLineAsk    = C'220,170,100';
   g_scheme.chartLineBid    = C'240,100,80';
   g_scheme.chartVolumeUp   = C'80,180,90';
   g_scheme.chartVolumeDown = C'220,70,60';

   // Агенты
   g_scheme.agentBarPositive = C'80,180,90';
   g_scheme.agentBarNegative = C'220,70,60';
   g_scheme.agentBarNeutral  = C'100,85,70';
   g_scheme.agentDecisionBuy = C'100,210,110';
   g_scheme.agentDecisionSell= C'250,70,60';
   g_scheme.agentDecisionNone= C'150,130,110';
   g_scheme.agentTextScore   = C'220,200,180';
   g_scheme.agentTextName    = C'180,160,140';
   g_scheme.agentBarBg       = C'45,35,28';
   g_scheme.agentBorder      = C'70,50,40';

   // Better Volume
   g_scheme.bvClimaxHigh  = C'230,40,30';
   g_scheme.bvClimaxLow   = C'230,215,190';
   g_scheme.bvHighChurn   = C'210,60,170';
   g_scheme.bvLowVolume   = C'220,200,70';
   g_scheme.bvClimaxChurn = C'230,140,30';
   g_scheme.bvNeutral     = C'120,140,110';

   // REI
   g_scheme.reiOverbought = C'230,60,50';
   g_scheme.reiOversold   = C'60,200,80';
   g_scheme.reiNeutral    = C'150,130,110';

   // WPR
   g_scheme.wprOverbought = C'230,60,50';
   g_scheme.wprOversold   = C'60,200,80';

   // Сетапы
   g_scheme.setupA     = C'80,190,80';
   g_scheme.setupAPlus = C'240,200,40';
   g_scheme.setupSkip  = C'100,85,70';

   // Новости
   g_scheme.newsHigh   = C'225,50,40';
   g_scheme.newsMedium = C'215,150,40';
   g_scheme.newsLow    = C'175,170,90';

   // Fib Pivot
   g_scheme.pivotLine  = C'240,200,50';
   g_scheme.pivotR38   = C'180,90,200';
   g_scheme.pivotR61   = C'50,200,50';
   g_scheme.pivotR78   = C'220,50,50';
   g_scheme.pivotR100  = C'0,190,190';
   g_scheme.pivotR138  = C'220,150,40';
   g_scheme.pivotR161  = C'140,130,110';
   g_scheme.pivotR200  = C'120,110,80';
   g_scheme.pivotDaily = C'110,100,60';
}

//+------------------------------------------------------------------+
//| Применить цветовую схему к графику                                 |
//+------------------------------------------------------------------+
void ApplySchemeToChart()
{
   long chartId = ChartID();

   ChartSetInteger(chartId, CHART_COLOR_BACKGROUND,  g_scheme.chartBackground);
   ChartSetInteger(chartId, CHART_COLOR_FOREGROUND,   g_scheme.chartForeground);
   ChartSetInteger(chartId, CHART_COLOR_GRID,         g_scheme.chartGrid);
   ChartSetInteger(chartId, CHART_COLOR_CANDLE_BULL,  g_scheme.chartBullCandle);
   ChartSetInteger(chartId, CHART_COLOR_CANDLE_BEAR,  g_scheme.chartBearCandle);
   ChartSetInteger(chartId, CHART_COLOR_CHART_UP,     g_scheme.chartBullOutline);
   ChartSetInteger(chartId, CHART_COLOR_CHART_DOWN,   g_scheme.chartBearOutline);
   ChartSetInteger(chartId, CHART_COLOR_ASK,          g_scheme.chartLineAsk);
   ChartSetInteger(chartId, CHART_COLOR_BID,          g_scheme.chartLineBid);
   ChartSetInteger(chartId, CHART_COLOR_VOLUME,       g_scheme.chartVolumeUp);
   ChartSetInteger(chartId, CHART_COLOR_CHART_LINE,   g_scheme.chartForeground);

   ChartRedraw(chartId);
}

//+------------------------------------------------------------------+
//| Получить цвет Fib уровня по имени                                  |
//+------------------------------------------------------------------+
color GetFibLevelColor(string levelName)
{
   if(levelName == "Pivot" || levelName == "WP")  return g_scheme.pivotLine;
   if(levelName == "R38"  || levelName == "S38")  return g_scheme.pivotR38;
   if(levelName == "R61"  || levelName == "S61")  return g_scheme.pivotR61;
   if(levelName == "R78"  || levelName == "S78")  return g_scheme.pivotR78;
   if(levelName == "R100" || levelName == "S100") return g_scheme.pivotR100;
   if(levelName == "R138" || levelName == "S138") return g_scheme.pivotR138;
   if(levelName == "R161" || levelName == "S161") return g_scheme.pivotR161;
   if(levelName == "R200" || levelName == "S200") return g_scheme.pivotR200;
   if(StringFind(levelName, "D_") == 0)           return g_scheme.pivotDaily;
   return g_scheme.pivotLine;
}

#endif
