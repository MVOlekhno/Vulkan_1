#ifndef __CLAUDE_V600_PP_INPUTS_MQH__
#define __CLAUDE_V600_PP_INPUTS_MQH__
#property strict

// ==================== ПЕРЕЧИСЛЕНИЯ ====================

enum ENUM_COLOR_SCHEME
{
   SCHEME_DEEP_OCEAN    = 0,   // Deep Ocean
   SCHEME_WARM_SAND     = 1,   // Warm Sand
   SCHEME_NIGHT_VIOLET  = 2,   // Night Violet
   SCHEME_CREAM_CLASSIC = 3,   // Cream Classic
   SCHEME_ESPRESSO      = 4    // Espresso
};

enum ENUM_PANEL_SCALE
{
   SCALE_80  = 0,  // 80%
   SCALE_90  = 1,  // 90%
   SCALE_100 = 2,  // 100%
   SCALE_110 = 3,  // 110%
   SCALE_120 = 4   // 120%
};

enum ENUM_VWAP_PERIOD
{
   VWAP_DAILY   = 0,  // Daily
   VWAP_WEEKLY  = 1,  // Weekly
   VWAP_MONTHLY = 2   // Monthly
};

enum ENUM_PIVOT_DRAW_MODE
{
   PIVOT_FULL_WEEK  = 0,  // Full week lines
   PIVOT_SHORT_SIDE = 1   // Short side lines (40 bars + labels)
};

enum ENUM_PIVOT_METHOD
{
   PIVOT_HLC  = 0,  // (H+L+C)/3
   PIVOT_HLCC = 1,  // (H+L+C+C)/4
   PIVOT_HLOC = 2   // (H+L+O+C)/4
};

// ==================== СЕКЦИИ ПАРАМЕТРОВ ====================

// Секция 1: Основные
input string  ___general___         = "=== Основные настройки ===";
input ENUM_COLOR_SCHEME ColorScheme = SCHEME_NIGHT_VIOLET;
input int     SL_Pips4              = 50;      // SL в pips4 (50 = 5.0 пипс)
input double  TotalRiskPct          = 3.01;    // Общий риск %
input ENUM_PANEL_SCALE PanelScale   = SCALE_100;

// Секция 2: Market Levels
input string  ___levels___          = "=== Market Levels ===";
input bool    EnableMarketLevels    = true;
input int     NearLevelPips4        = 50;
input int     ADR_Days              = 14;
input int     ADR_Weeks             = 52;
input int     ADR_Months            = 60;
input double  QuantileCore          = 0.8;
input double  QuantileTail          = 0.95;
input bool    DrawADR_Day           = true;
input bool    DrawMoves_Week        = true;
input bool    DrawMoves_Month       = true;
input bool    DrawUS_Session        = true;

// Секция 3: US Session
input int     US_StartHourChicago   = 8;
input int     US_EndHourChicago     = 17;
input color   US_HighColor          = clrDodgerBlue;
input color   US_LowColor           = clrDodgerBlue;
input int     CME_UTC_Offset        = -6;
input int     CME_Hour              = 17;
input bool    CME_DST_Auto          = true;
input int     BrokerGMTOffsetHours  = 2;

// Секция 4: Диагностика
input bool    EnableDiagnostics     = true;

// Секция 5: Сессионные уровни
input string  ___sessions___        = "=== Session Levels ===";
input bool    DrawSessionLevels     = true;
input bool    DrawAsiaHL            = true;
input bool    DrawLondonHL          = true;
input bool    DrawMidnightOpen      = true;
input bool    DrawPrevNYClose       = true;
input color   AsiaColor             = clrGold;
input color   LondonColor           = clrRoyalBlue;
input color   MidnightColor         = clrSilver;
input color   NYCloseColor          = clrMediumSpringGreen;
input bool    ShowExchangePanel     = true;
input bool    DrawDailyBalanceEMA   = true;
input color   DailyEMA_Color        = clrYellow;
input int     DailyEMA_Width        = 2;

// Секция 6: Context Analyzer
input string  ___context___         = "=== Context Analyzer ===";
input bool    EnableContextAnalysis = true;
input int     ADX_Period            = 14;
input int     ATR_Period            = 14;
input double  TrendThreshold        = 25.0;

// Секция 7: Multi-Agent System
input string  ___agents___          = "=== Multi-Agent System ===";
input bool    EnableAgentSystem     = true;
input bool    Agent_VWAP_Enabled    = true;
input bool    Agent_SD_Enabled      = true;
input bool    Agent_Structure_Enabled = true;
input bool    Agent_Momentum_Enabled  = true;
input bool    Agent_Context_Enabled   = true;
input int     EntryThreshold        = 70;     // Повышен с 55
input int     MinAgentsAgree        = 3;      // Повышен с 2

// Секция 8: Q-Learning
input string  ___learning___        = "=== Q-Learning ===";
input bool    EnableQLearning       = false;   // Выключен по умолчанию
input double  LearningRate          = 0.1;
input double  ExplorationRate       = 0.1;
input string  QTableFile            = "q_table.csv";

// Секция 9: TWAP Execution
input string  ___twap___            = "=== TWAP Execution ===";
input bool    EnableTWAP            = false;   // Выключен по умолчанию
input int     TWAP_Slices           = 3;
input int     TWAP_Interval         = 60;
input double  TWAP_CancelThreshold  = 15.0;

// Секция 10: WPR Multi-TF Agent
input string  ___wpr___             = "=== WPR Multi-TF Agent ===";
input bool    Agent_WPR_Enabled     = true;
input double  WPR_OversoldLevel     = -80.0;
input double  WPR_OverboughtLevel   = -20.0;
input double  WPR_Weight            = 1.0;

// Секция 11: Better Volume Agent
input string  ___bv___              = "=== Better Volume Agent ===";
input bool    Agent_BV_Enabled      = true;
input int     BV_LookBack           = 20;
input double  BV_Weight             = 1.0;

// Секция 12: TD_REI Agent
input string  ___rei___             = "=== TD REI Agent ===";
input bool    Agent_REI_Enabled     = true;
input double  REI_Weight            = 1.0;

// Секция 13: PVSRA Agent
input string  ___pvsra___           = "=== PVSRA Agent ===";
input bool    Agent_PVSRA_Enabled   = true;
input int     PVSRA_AvgPeriod       = 10;
input double  PVSRA_Weight          = 1.0;

// Секция 14: Professional Journal
input string  ___journal___         = "=== Professional Journal ===";
input bool    EnableJournal         = true;
input string  JournalPrefix         = "Claude_Journal";
input bool    LogSkippedSignals     = true;

// Секция 15: Setup Detection
input string  ___setups___          = "=== Setup Detection ===";
input bool    EnableSetupDetection  = true;
input double  MinSetupScore         = 60.0;
input bool    ShowUpcomingSetup     = true;

// Секция 16: Agent Panel
input string  ___agentpanel___      = "=== Agent Panel ===";
input bool    ShowAgentPanel        = true;

// Секция 17: News Calendar
input string  ___news___            = "=== News Calendar ===";
input bool    EnableNewsCalendar    = true;
input bool    DrawNewsLines         = true;
input bool    ShowNewsOnPanel       = true;
input int     HighImpactBuffer_Min  = 15;
input int     MedImpactBuffer_Min   = 5;
input bool    BlockTradeOnHighNews  = true;

// Секция 18: Weekly Fib Pivot
input string  ___fibpivot___        = "=== Weekly Fib Pivot ===";
input bool    Agent_FibPivot_Enabled = true;
input double  FibPivot_Weight       = 1.0;
input bool    DrawFibPivotLines     = true;
input ENUM_PIVOT_DRAW_MODE PivotDrawMode = PIVOT_FULL_WEEK;
input ENUM_PIVOT_METHOD PivotCalcMethod  = PIVOT_HLC;
input bool    EnableDailyPivot       = true;
input bool    ShowPivotZoneOnPanel   = true;

// ==================== ВСПОМОГАТЕЛЬНЫЕ КОНСТАНТЫ ====================

#define MAGIC_NUMBER       600
#define MAX_AGENTS         10
#define MAX_NEWS_DISPLAY   3
#define PANEL_PREFIX       "CV6_"

// Сессии
#define SESSION_SYDNEY     0
#define SESSION_TOKYO      1
#define SESSION_LONDON     2
#define SESSION_NY         3
#define SESSION_SYDNEY_TOKYO 4
#define SESSION_LONDON_NY  5
#define SESSION_NY_LONDON  6

// BV типы
#define BV_NEUTRAL         0
#define BV_CLIMAX_HIGH     1
#define BV_CLIMAX_LOW      2
#define BV_HIGH_CHURN      3
#define BV_LOW_VOLUME      4
#define BV_CLIMAX_CHURN    5

// PVSRA типы
#define PVSRA_NORMAL       0
#define PVSRA_BULL_RISING  1
#define PVSRA_BEAR_RISING  2
#define PVSRA_BULL_CLIMAX  3
#define PVSRA_BEAR_CLIMAX  4

// ==================== ОБЩИЕ СТРУКТУРЫ ====================

struct AgentSignal
{
   string name;
   int    score;        // -100 .. +100
   double confidence;   // 0.0 .. 1.0
   double weight;       // Вес из настроек
   bool   enabled;
};

struct TradeDecision
{
   bool   shouldTrade;
   int    direction;     // +1=BUY, -1=SELL, 0=NONE
   int    riskMultiple;  // 2..7
   double weightedScore;
   int    agreeCount;
   int    longVotes;
   int    shortVotes;
   string setupName;
   string setupClass;    // "A", "A+", "S"
};

#endif
