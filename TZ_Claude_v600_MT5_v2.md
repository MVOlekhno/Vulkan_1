# ТЕХНИЧЕСКОЕ ЗАДАНИЕ v2
# Советник Claude_v600 для MetaTrader 5
# Полный порт Claude_v500 (MT4) → MQL5 + Агент 10 Fib Pivot
# Версия документа: 2.0 | Дата: 16.02.2026

---

## ОГЛАВЛЕНИЕ

```
1. Обзор проекта и архитектура
2. Ключевые отличия MQL4 → MQL5 (справочник)
3. Структура файлов (20 модулей)
4. Модуль 1: Входные параметры (pp_inputs)
5. Модуль 2: Цветовые схемы (pp_color_schemes)
6. Модуль 3: Диагностика (pp_diag)
7. Модуль 4: Контекст рынка (pp_context)
8. Модуль 5: Сессии (pp_sessions)
9. Модуль 6: Рыночные уровни (pp_market_levels)
10. Модуль 7: Панель UI (pp_ui_panel)
11. Модуль 8: Агенты 1-5 оригинальные (pp_agents)
12. Модуль 9: Агенты 6-9 расширенные (pp_agents_extended)
13. Модуль 10: Агент 10 — Weekly Fib Pivot (pp_fib_pivot) — НОВЫЙ
14. Модуль 11: Система решений (pp_decision) — 10 агентов
15. Модуль 12: Q-Learning (pp_learning)
16. Модуль 13: TWAP исполнение (pp_twap)
17. Модуль 14: Детекция сетапов (pp_setups)
18. Модуль 15: Журнал (pp_journal) — ИСПРАВЛЕННЫЙ
19. Модуль 16: Новостной календарь (pp_news) — НОВЫЙ
20. Модуль 17: Индикаторы (VWAP, AVWAP, VolumeProfile)
21. Главный EA файл
22. Порядок реализации
23. Верификация и тестирование
24. CHANGELOG v1 → v2
```

---

## 1. ОБЗОР ПРОЕКТА

### Что это

Советник Claude_v600 — это MQL5-версия многоагентной торговой системы.
10 агентов анализируют рынок, голосуют, и принимают решение о входе.
Профессиональный журнал записывает каждый бар для анализа сетапов.
Система детекции распознаёт 6 типов сетапов из Playbook v4.
Агент 10 (Weekly Fib Pivot) добавляет недельный масштаб анализа.

### Методология

FVG_CAD5 Playbook v4 (Prop-style):
  Контекст → Триггер → Подтверждение → Риск
  Грейдинг: S (skip) / A (0.25-0.75R) / A+ (0.75-1.5R)
  Частичные фиксации: 1R / 3R / 5R, перенос в BE после 1R
  Дневной стоп: -3R, лимит сделок: 3-5/день

### Отличия от MT4 версии (v500)

1. Нативный MQL5 код (НЕ транслитерация MQL4 → MQL5)
2. Использование CTrade, CPositionInfo, CSymbolInfo классов
3. OnCalculate() для индикаторов (НЕ start())
4. Нативные таймеры (OnTimer) вместо счётчиков тиков
5. Исправленный журнал (WeightedScore НЕ обнуляется)
6. Очистка суффиксов брокера в именах файлов
7. Добавлены уровни AsiaH/L, LondonH/L, MidnightOpen в журнал
8. Новый модуль новостного календаря (WebRequest)
9. Расширенная панель с блоком новостей
10. НОВЫЙ Агент 10: Weekly Fib Pivot (Davit's Pivot Trading / Forex Factory)
11. Система 10 агентов (5 оригинальных + 5 расширенных)
12. Fib Pivot уровни = цели для Take Profit (2R-13R)
13. Мульти-масштабный анализ: цена vs недельные Pivot + дневные Pivot + ADR + сессии

---

## 2. СПРАВОЧНИК: КЛЮЧЕВЫЕ ОТЛИЧИЯ MQL4 → MQL5

### Торговые операции

```
MQL4                              MQL5
─────────────────────────────────────────────────────────
OrderSend(...)                    CTrade trade;
                                  trade.Buy(lots, symbol, price, sl, tp);
                                  trade.Sell(lots, symbol, price, sl, tp);

OrderSelect(ticket)               CPositionInfo pos;
                                  pos.SelectByTicket(ticket);

OrderClose(ticket, lots, price)   trade.PositionClose(ticket);

OrderModify(ticket, ...)          trade.PositionModify(ticket, newSL, newTP);

OrdersTotal()                     PositionsTotal() — открытые позиции
                                  OrdersTotal() — отложенные ордера

OrderProfit()                     pos.Profit()
OrderOpenPrice()                  pos.PriceOpen()
OrderTicket()                     pos.Ticket()
OrderType()                       pos.PositionType() 
                                  (POSITION_TYPE_BUY/SELL)
```

### Индикаторы

```
MQL4                              MQL5
─────────────────────────────────────────────────────────
iMA(sym, tf, period, ...)        int handle = iMA(sym, tf, period, ...);
                                  double buf[];
                                  CopyBuffer(handle, 0, shift, count, buf);

iRSI(sym, tf, period, price, 0)  int handle = iRSI(sym, tf, period, price);
                                  CopyBuffer(handle, 0, 0, 1, buf);
                                  double value = buf[0];

iWPR(sym, tf, period, shift)     int handle = iWPR(sym, tf, period);
                                  CopyBuffer(handle, 0, shift, 1, buf);

iCustom(sym, tf, "name", ...)    int handle = iCustom(sym, tf, "name", ...);
                                  CopyBuffer(handle, buffer_idx, ...);

iATR(sym, tf, period, shift)     int handle = iATR(sym, tf, period);
                                  CopyBuffer(handle, 0, shift, 1, buf);

iADX(sym, tf, period, ...)       int handle = iADX(sym, tf, period);
                                  CopyBuffer(handle, 0, shift, 1, main);
                                  CopyBuffer(handle, 1, shift, 1, plusDI);
                                  CopyBuffer(handle, 2, shift, 1, minusDI);

Volume[i]                         MQL5: tick volume или real volume
                                  long vol[];
                                  CopyTickVolume(sym, tf, 0, count, vol);
```

### Доступ к ценам

```
MQL4                              MQL5
─────────────────────────────────────────────────────────
Open[i], High[i], Low[i],        double open[], high[], low[], close[];
Close[i], Time[i], Volume[i]     CopyOpen(sym, tf, 0, count, open);
                                  CopyHigh(sym, tf, 0, count, high);
                                  CopyLow(sym, tf, 0, count, low);
                                  CopyClose(sym, tf, 0, count, close);
                                  
                                  ВАЖНО: В MQL5 массивы по умолчанию
                                  индексируются как timeseries (0=текущий)
                                  ТОЛЬКО после ArraySetAsSeries(arr, true);

Bid / Ask                         SymbolInfoDouble(sym, SYMBOL_BID)
                                  SymbolInfoDouble(sym, SYMBOL_ASK)

Point                             SymbolInfoDouble(sym, SYMBOL_POINT)
                                  или _Point

Digits                            SymbolInfoInteger(sym, SYMBOL_DIGITS)
                                  или _Digits
```

### Графические объекты

```
MQL4                              MQL5 (почти идентично)
─────────────────────────────────────────────────────────
ObjectCreate(...)                 ObjectCreate(chartID, name, type, ...)
ObjectSetString(...)              ObjectSetString(chartID, name, prop, val)
ObjectSetInteger(...)             ObjectSetInteger(chartID, name, prop, val)
ObjectSetDouble(...)              ObjectSetDouble(chartID, name, prop, val)
ObjectDelete(...)                 ObjectDelete(chartID, name)

// Панель: ИДЕНТИЧНЫЙ подход через OBJ_RECTANGLE_LABEL,
// OBJ_LABEL, OBJ_EDIT, OBJ_BUTTON
```

### Файловые операции

```
MQL4                              MQL5 (идентично)
─────────────────────────────────────────────────────────
FileOpen(name, flags)             FileOpen(name, flags)
FileWrite(h, ...)                 FileWrite(h, ...)
FileClose(h)                      FileClose(h)
FileIsExist(name)                 FileIsExist(name)

// Директория: MQL5/Files/ (вместо MQL4/Files/)
// ИДЕНТИЧНАЯ логика
```

### Таймфреймы

```
MQL4                              MQL5
─────────────────────────────────────────────────────────
PERIOD_M1 = 1                     PERIOD_M1
PERIOD_M5 = 5                     PERIOD_M5
PERIOD_M15 = 15                   PERIOD_M15
Period() = число                  Period() = ENUM_TIMEFRAMES

// Конвертация:
int GetPeriodMinutes()
{
   return PeriodSeconds(Period()) / 60;
}
```

### WebRequest

```
MQL4                              MQL5 (идентично)
─────────────────────────────────────────────────────────
WebRequest("GET", url, ...)       WebRequest("GET", url, ...)

// ИДЕНТИЧНАЯ сигнатура в MQL5!
// Но в MQL5 есть дополнительно: UrlEncode
```

### События

```
MQL4                              MQL5
─────────────────────────────────────────────────────────
init() → OnInit()                 OnInit() ← то же
deinit() → OnDeinit()             OnDeinit() ← то же
start() (для индикаторов)         OnCalculate() ← ДРУГОЕ
OnTick() (для EA)                 OnTick() ← то же
                                  OnTimer() — нативные таймеры
                                  OnChartEvent() — события графика
```

---

## 3. СТРУКТУРА ФАЙЛОВ

```
Папка: MQL5/Experts/Claude_v600/

Файлы (18 штук):
┌────┬──────────────────────────────────┬─────────────────────────┐
│  # │ Файл                             │ Описание                │
├────┼──────────────────────────────────┼─────────────────────────┤
│  1 │ Claude_v600_pp_inputs.mqh        │ Входные параметры       │
│  2 │ Claude_v600_pp_diag.mqh          │ Диагностика             │
│  3 │ Claude_v600_pp_color_schemes.mqh │ 5 цветовых схем +30 полей│
│  4 │ Claude_v600_pp_context.mqh       │ Контекст рынка          │
│  5 │ Claude_v600_pp_sessions.mqh      │ Сессионные уровни       │
│  6 │ Claude_v600_pp_market_levels.mqh │ ADR, круглые уровни     │
│  7 │ Claude_v600_pp_ui_panel.mqh      │ Панель + блок агентов   │
│  8 │ Claude_v600_pp_agents.mqh        │ Агенты 1-5 оригинальные │
│  9 │ Claude_v600_pp_agents_ext.mqh    │ Агенты 6-9 (WPR,BV,REI,PVSRA)│
│ 10 │ Claude_v600_pp_fib_pivot.mqh    │ Агент 10: Weekly Fib Pivot   │
│ 11 │ Claude_v600_pp_decision.mqh      │ Система решений (10 агентов) │
│ 11 │ Claude_v600_pp_learning.mqh      │ Q-Learning              │
│ 12 │ Claude_v600_pp_twap.mqh          │ TWAP исполнение         │
│ 13 │ Claude_v600_pp_setups.mqh        │ 6 сетапов из Playbook v4│
│ 14 │ Claude_v600_pp_journal.mqh       │ Журнал (ИСПРАВЛЕННЫЙ)   │
│ 15 │ Claude_v600_pp_news.mqh          │ Новостной календарь     │
│ 16 │ Claude_v600_Tester_PropPanel.mq5 │ Главный EA              │
├────┼──────────────────────────────────┼─────────────────────────┤
│ 17 │ Claude_v600_VWAP.mq5            │ Индикатор VWAP          │
│ 18 │ Claude_v600_AVWAP.mq5           │ Индикатор AVWAP         │
│ 19 │ Claude_v600_VolumeProfile.mq5   │ Индикатор Volume Profile│
└────┴──────────────────────────────────┴─────────────────────────┘

Все .mqh в одной папке с EA (include через кавычки "файл.mqh").
Индикаторы .mq5 → MQL5/Indicators/
```

---

## 4. МОДУЛЬ: ВХОДНЫЕ ПАРАМЕТРЫ (pp_inputs.mqh)

```mql5
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
input int     EntryThreshold        = 70;     // Повышен с 55!
input int     MinAgentsAgree        = 3;      // Повышен с 2!

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
// Период подбирается автоматически по таймфрейму:
// M1=16, M5=12, M15=10, M30+=8
// Пороги: M1=±45, остальные=±60

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

// Секция 18: Weekly Fib Pivot (НОВОЕ)
input string  ___fibpivot___        = "=== Weekly Fib Pivot ===";
input bool    Agent_FibPivot_Enabled = true;
input double  FibPivot_Weight       = 1.0;
input bool    DrawFibPivotLines     = true;

enum ENUM_PIVOT_DRAW_MODE
{
   PIVOT_FULL_WEEK = 0,  // Full week lines (длина = бары текущей недели)
   PIVOT_SHORT_SIDE = 1  // Short side lines (40 баров сбоку + подписи)
};
input ENUM_PIVOT_DRAW_MODE PivotDrawMode = PIVOT_FULL_WEEK;

enum ENUM_PIVOT_METHOD
{
   PIVOT_HLC  = 0,  // (H+L+C)/3  — классический
   PIVOT_HLCC = 1,  // (H+L+C+C)/4
   PIVOT_HLOC = 2,  // (H+L+O+C)/4
};
input ENUM_PIVOT_METHOD PivotCalcMethod = PIVOT_HLC;

input bool    EnableDailyPivot       = true;   // Дополнительно дневные пивоты
input bool    ShowPivotZoneOnPanel   = true;

#endif
```

---

## 5. МОДУЛЬ: ЦВЕТОВЫЕ СХЕМЫ (pp_color_schemes.mqh)

Идентичная структура MT4 версии. Структура ColorScheme содержит:
- 11 полей панели (panelBackground, textPrimary, btnLongBg, ...)
- 11 полей графика (chartBackground, chartBullCandle, ...)
- 10 полей агентов (agentBarPositive, agentDecisionBuy, ...)
- 6 полей Better Volume (bvClimaxHigh, bvClimaxLow, ...)
- 4 поля PVSRA (pvsraBullClimax, pvsraBearClimax, ...)
- 3 поля REI (reiOverbought, reiOversold, reiNeutral)
- 2 поля WPR (wprOverbought, wprOversold)
- 3 поля сетапов (setupA, setupAPlus, setupSkip)
- 3 поля новостей (newsHigh, newsMedium, newsLow) ← НОВОЕ

**PVSRA цвета одинаковы во всех 5 схемах** (стандарт PVSRA).
Остальные гармонизированы с палитрой каждой схемы.

Конкретные значения цветов скопировать из MT4 версии 
(файл Claude_v500_pp_color_schemes.mqh) — они идентичны.

Добавить для новостей:
```mql5
// Deep Ocean
g_scheme.newsHigh   = C'212,60,60';    // Красный
g_scheme.newsMedium = C'212,160,60';   // Оранжевый
g_scheme.newsLow    = C'180,180,100';  // Жёлтый приглушённый

// И так далее для каждой схемы — адаптированные к палитре
```

---

## 6-9. МОДУЛИ: КОНТЕКСТ, СЕССИИ, УРОВНИ, ДИАГНОСТИКА

Логика ИДЕНТИЧНА MT4 версии, но с MQL5 синтаксисом:

### Ключевые изменения для MQL5:

```mql5
// Вместо iATR(Symbol(), Period(), 14, 0):
int g_hATR;
double g_bufATR[];

// В OnInit():
g_hATR = iATR(_Symbol, _Period, ATR_Period);

// В расчётах:
CopyBuffer(g_hATR, 0, 0, 1, g_bufATR);
double atr = g_bufATR[0];
```

```mql5
// Вместо iADX(Symbol(), Period(), 14, MODE_MAIN, 0):
int g_hADX;
double g_bufADXMain[], g_bufADXPlus[], g_bufADXMinus[];

g_hADX = iADX(_Symbol, _Period, ADX_Period);
CopyBuffer(g_hADX, 0, 0, 1, g_bufADXMain);
CopyBuffer(g_hADX, 1, 0, 1, g_bufADXPlus);
CopyBuffer(g_hADX, 2, 0, 1, g_bufADXMinus);
```

### MarketContext структура (расширенная, исправленная):

```mql5
struct MarketContext
{
   // Базовые
   int    regime;            // 0=StrongUp..5=StrongDown
   int    session;           // 0=Sydney..6=NYLondon
   int    day_type;          // 0=Trend,1=Range,2=Expansion
   double adx;
   double atr;
   double atr_ratio;         // ATR / среднее ATR
   double spread_pips;
   double price_vs_vwap;     // В пипсах, знаковое
   double adr_position;      // 0.0-1.0, где цена в дневном рейндже
   bool   is_kill_zone;
   int    hour_gmt;
   int    day_of_week;
   int    ema_position;      // +1=выше, -1=ниже, 0=на EMA
   double context_multiplier;// Итоговый множитель CtxFilter
   
   // Индикаторы (заполняются агентами)
   int    bv_type;           // 0=Neutral..5=ClimaxChurn
   int    pvsra_type;        // 0=Normal..4=BearClimax
   double rei_value;         // -100..+100
   double wpr1, wpr2, wpr3, wpr4;  // Значения WPR
   double volume_ratio;      // Текущий объём / средний
   
   // Уровни (ДОБАВЛЕНЫ — не было в MT4 журнале!)
   double pdh, pdl;          // Previous Day High/Low
   double asia_high, asia_low;
   double london_high, london_low;
   double midnight_open;
   double prev_ny_close;
   
   // Новости (НОВОЕ)
   int    news_minutes_to;   // Минут до ближайшей High Impact
   int    news_impact;       // 0-3 ближайшей
   string news_title;        // Название ближайшей
};
```

---

## 10. МОДУЛЬ: ПАНЕЛЬ UI (pp_ui_panel.mqh)

### КРИТИЧЕСКОЕ ИСПРАВЛЕНИЕ из MT4:

В MT4 была ошибка: PP_UIUpdateAgentBlock() принимала структуры 
AgentSignal и TradeDecision как параметры — это не работает между .mqh.

**Решение для MT5:** Использовать ГЛОБАЛЬНЫЕ переменные для передачи 
данных в панель (тот же подход что исправил ошибку в MT4):

```mql5
// Глобальные переменные для блока агентов (заполняются в EA)
string g_uiAgentNames[10];
int    g_uiAgentScores[10];
int    g_uiAgentCount = 0;
bool   g_uiDecShouldTrade = false;
int    g_uiDecDirection = 0;
int    g_uiDecRiskMultiple = 2;
double g_uiDecWeightedScore = 0;
string g_uiSetupText = "";
bool   g_uiSetupActive = false;

// Глобальные для блока новостей
string g_uiNewsTitle[3];     // До 3 ближайших
int    g_uiNewsMinutes[3];   // Минут до каждой
int    g_uiNewsImpact[3];    // Impact каждой
int    g_uiNewsCount = 0;

void PP_UIUpdateAgentBlock()    // БЕЗ параметров-структур!
void PP_UIUpdateNewsBlock()     // НОВОЕ
```

### Макет панели (полный):

```
┌────────────────────────────────────────────┐
│  GBPUSD  M5     Claude_v600_PropPanel      │
│  Balance: 10000$  Equity: 10050$           │
│  Leverage: 1:100  Margin: 51$              │
│  Free margin: 9949$  Level: 197%           │
├────────────────────────────────────────────┤
│  Time                                      │
│  Server: 22:50  HK: 04:50  London: 20:50  │
│  Local: 23:50   Chicago: 14:50  Tokyo: 05:50│
├────────────────────────────────────────────┤
│  Allowed lot: 0.60                         │
│  Profit on open positions                  │
│  long: +0.00$     short: +0.00$            │
├────────────────────────────────────────────┤
│  [2R] [5R]  [2R] [5R]                     │
│  [3R] [6R]  [3R] [6R]                     │
│  [4R] [7R]  [4R] [7R]                     │
│  (Long зелён.) (Short фиолет.)            │
├────────────────────────────────────────────┤
│  [BE2R][BE5R] [BE2R][BE5R]                │
│  [BE3R][BE6R] [BE3R][BE6R]                │
│  [BE4R][BE7R] [BE4R][BE7R]                │
├────────────────────────────────────────────┤
│  Metrics  Long/Short                       │
│  2R-7R profit $ и %                        │
├────────────────────────────────────────────┤
│  [Close ALL Long] [Close ALL Short]        │
│  [     Close ALL positions     ]           │
├────────────────────────────────────────────┤
│  ── Agent System ──────────── Score ──     │
│  VWAP PB  [████████░░░░░░░░]    +65        │
│  SD Dev   [██████░░░░░░░░░░]    +40        │
│  Structure[████████░░░░░░░░]    +55        │
│  Momentum [░░░░░░░░░░░░░░░░]    -10        │
│  CtxFilter ×1.3                            │
│  WPR MTF  [██████████░░░░░░]    +72        │
│  BetterVol[████░░░░░░░░░░░░]    +30        │
│  TD REI   [████████████░░░░]    +80        │
│  PVSRA    [██████░░░░░░░░░░]    +45        │
│                                            │
│  Decision: ▲ BUY 3R [195]                  │
│  Setup: FVG Continuation (A+)              │
├────────────────────────────────────────────┤
│  ── Новости ───────────────────────────    │
│  ⏱ 47m │ 🔴 GBP CPI y/y  F:3.0% P:3.4%  │
│  ⏱ 2h  │ 🟡 USD Durable   F:0.3% P:5.3%  │
│  ⏱ 8h  │ 🔴 USD FOMC Minutes              │
│  Статус: ⚠ CPI через 47 мин              │
└────────────────────────────────────────────┘

Высота панели: ~1700px (увеличена на +460 vs MT4 v4.10)
Обновление: раз в бар (НЕ каждый тик!)
```

---

## 11-12. АГЕНТЫ 1-9

### Агенты 1-5 (pp_agents.mqh) — оригинальные

Логика идентична MT4. MQL5 изменения:
- iMA/iRSI/iWPR → handle + CopyBuffer
- Создать все handles в OnInit(), хранить глобально
- ArraySetAsSeries(buf, true) для правильной индексации

### Агенты 6-9 (pp_agents_ext.mqh) — расширенные

#### Агент 6: WPR Multi-TF

```mql5
// MQL5: создать 4 handle
int g_hWPR[4];

void AGTX_InitWPR()
{
   int periods[4];
   GetWPRPeriods(periods);  // Автоподбор по ТФ
   for(int i = 0; i < 4; i++)
      g_hWPR[i] = iWPR(_Symbol, _Period, periods[i]);
}

void GetWPRPeriods(int &periods[])
{
   int tfMin = PeriodSeconds(_Period) / 60;
   switch(tfMin)
   {
      case 1:  periods[0]=1440; periods[1]=480; periods[2]=240; periods[3]=60; break;
      case 5:  periods[0]=288;  periods[1]=96;  periods[2]=48;  periods[3]=24; break;
      case 15: periods[0]=96;   periods[1]=32;  periods[2]=16;  periods[3]=8;  break;
      case 60: periods[0]=24;   periods[1]=8;   periods[2]=4;   periods[3]=2;  break;
      default: periods[0]=288;  periods[1]=96;  periods[2]=48;  periods[3]=24; break;
   }
}
```

#### Агент 7: Better Volume (ВСТРОЕННЫЙ)

```mql5
// Формулы (НЕ iCustom):
// Value2 = Volume[bar] × Range
// Value3 = Volume[bar] / Range (если Range != 0)
// Ищем max Value2 и max Value3 за LookBack баров
// Классификация: ClimaxHigh, ClimaxLow, HighChurn, LowVolume, ClimaxChurn, Neutral

// MQL5 отличие: Volume
long vol[];
CopyTickVolume(_Symbol, _Period, 0, BV_LookBack + 1, vol);
// ИЛИ для реального объёма (если доступен):
// CopyRealVolume(_Symbol, _Period, 0, count, vol);
```

#### Агент 8: TD_REI (ВСТРОЕННЫЙ, формула ДеМарка)

Формула ИДЕНТИЧНА MT4. Автоподбор периода:

```mql5
int GetREIPeriod()
{
   int tfMin = PeriodSeconds(_Period) / 60;
   if(tfMin <= 1) return 16;
   if(tfMin <= 5) return 12;
   if(tfMin <= 15) return 10;
   return 8;
}

double GetREIThreshold()
{
   int tfMin = PeriodSeconds(_Period) / 60;
   return (tfMin <= 1) ? 45.0 : 60.0;
}
```

#### Агент 9: PVSRA (ВСТРОЕННЫЙ)

Формула ИДЕНТИЧНА MT4. Те же формулы:
```
Climax = Vol >= 2.0 × avgVol ИЛИ V×Spread >= max(V×Spread, 10)
Rising = Vol >= 1.5 × avgVol
```

---

## 13. МОДУЛЬ: СИСТЕМА РЕШЕНИЙ (pp_decision.mqh)

### КРИТИЧЕСКОЕ ИСПРАВЛЕНИЕ: Context Filter НЕ обнуляет

В MT4 была проблема: CtxFilter = 0 → WeightedScore = 0 → никогда нет входов.

### Количество агентов: 10 (было 9 в v1)

```mql5
// signals[] теперь размер 10:
// [0] VWAP PB
// [1] SD Dev
// [2] Structure
// [3] Momentum
// [4] Ctx Filter (множитель, не голосует)
// [5] WPR MTF
// [6] Better Volume
// [7] TD REI
// [8] PVSRA
// [9] Fib Pivot  ← НОВЫЙ
```

---

## 12.5 МОДУЛЬ: АГЕНТ 10 — WEEKLY FIB PIVOT (pp_fib_pivot.mqh) — НОВЫЙ

### Источник: Davit's Pivot Trading (Forex Factory, 5000+ постов, 10+ лет)
### Формулы: ПОЛНОСТЬЮ ВСТРОЕННЫЕ (без iCustom)

### 12.5.1 ФИЛОСОФИЯ

```
Weekly Pivot = точка равновесия недели.
Цена ВЫШЕ Pivot → bias = BUY (покупатели контролируют).
Цена НИЖЕ Pivot → bias = SELL (продавцы контролируют).

Fibonacci зоны 61-100 = области где "свинги умирают".
  61%  = первая зона разворота
  78%  = "зона Карни" — последний шанс на разворот
  100% = полный рейндж предыдущей недели
  >100% = сильный тренд, поддержан фундаменталом

Дополнительно: дневные пивоты + ADR + сессионные уровни
дают мульти-масштабную карту "где цена и куда идёт".
```

### 12.5.2 ФОРМУЛЫ РАСЧЁТА

```mql5
// ============================================
// WEEKLY FIB PIVOT — полный расчёт
// ============================================

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

FibPivotLevels g_fib;

void FibPivot_Calculate()
{
   // === НЕДЕЛЬНЫЕ ===
   double prevH = iHigh(_Symbol, PERIOD_W1, 1);
   double prevL = iLow(_Symbol, PERIOD_W1, 1);
   double prevC = iClose(_Symbol, PERIOD_W1, 1);
   double prevO = iOpen(_Symbol, PERIOD_W1, 1);
   
   // Метод расчёта Pivot (настраиваемый)
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
   
   // === ДНЕВНЫЕ (если включены) ===
   if(EnableDailyPivot)
   {
      double dH = iHigh(_Symbol, PERIOD_D1, 1);
      double dL = iLow(_Symbol, PERIOD_D1, 1);
      double dC = iClose(_Symbol, PERIOD_D1, 1);
      
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
   else                        g_fib.w_zone = 5;  // >100 сильный тренд
   
   // === БЛИЖАЙШИЙ УРОВЕНЬ ===
   FibPivot_FindNearest(price);
}
```

### 12.5.3 МУЛЬТИ-МАСШТАБНЫЙ АНАЛИЗ

```mql5
// Агент 10 НЕ просто смотрит "цена у уровня".
// Он анализирует ПУТЬ цены к недельному пивоту через дневные уровни.

struct PivotContext
{
   // Положение цены в недельной структуре
   int    w_zone;           // Зона 0-5
   int    w_bias;           // +1/-1
   
   // Положение цены в дневной структуре
   int    d_zone;           // Зона 0-5 (дневная)
   int    d_bias;           // +1/-1 (дневная)
   
   // Совпадение недельного и дневного
   bool   weekly_daily_agree; // Оба bias совпадают?
   
   // Расстояние до ADR границ
   double adr_used_pct;     // Сколько % от ADR уже прошла цена сегодня
   bool   adr_exhausted;    // > 80% ADR использовано
   
   // Положение относительно сессий
   bool   above_asia_high;  // Цена выше Asia High
   bool   below_asia_low;   // Цена ниже Asia Low
   bool   above_london_high;
   bool   below_london_low;
   
   // Конфлюэнс: совпадение недельного Fib с сессионным уровнем
   bool   fib_confluence;   // Fib уровень ±5 пипсов от сессионного уровня
   string confluence_desc;  // "W_S61 ≈ Asia_Low" и т.д.
};

void FibPivot_AnalyzeContext(MarketContext &ctx, PivotContext &pctx)
{
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // 1. Дневной bias
   if(EnableDailyPivot)
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
   
   // 2. Согласованность
   pctx.weekly_daily_agree = (g_fib.w_bias == pctx.d_bias);
   
   // 3. ADR исчерпание
   double todayHigh = iHigh(_Symbol, PERIOD_D1, 0);
   double todayLow  = iLow(_Symbol, PERIOD_D1, 0);
   double todayRange = todayHigh - todayLow;
   double adr = ctx.atr * 1.0;  // ATR ≈ ADR (из контекста)
   pctx.adr_used_pct = (adr > 0) ? (todayRange / adr) * 100.0 : 0;
   pctx.adr_exhausted = (pctx.adr_used_pct > 80.0);
   
   // 4. Положение vs сессии
   pctx.above_asia_high  = (price > ctx.asia_high && ctx.asia_high > 0);
   pctx.below_asia_low   = (price < ctx.asia_low && ctx.asia_low > 0);
   pctx.above_london_high = (price > ctx.london_high && ctx.london_high > 0);
   pctx.below_london_low  = (price < ctx.london_low && ctx.london_low > 0);
   
   // 5. Конфлюэнс: Fib уровень совпадает с сессионным?
   double tolerance = 5.0 * _Point * 10; // 5 пипсов
   pctx.fib_confluence = false;
   
   // Проверить каждый Fib уровень vs AsiaH/L, LondonH/L, PDH/PDL
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
            pctx.confluence_desc = fibNames[i] + " ≈ " + sessNames[j];
            break;
         }
      }
      if(pctx.fib_confluence) break;
   }
}
```

### 12.5.4 SCORING (генерация score)

```mql5
int FibPivot_Score(MarketContext &ctx)
{
   PivotContext pctx;
   FibPivot_AnalyzeContext(ctx, pctx);
   
   int score = 0;
   int bias = g_fib.w_bias;  // +1 = выше Pivot (buy bias), -1 = ниже (sell bias)
   
   // === ЗОНА 61-78 (основная торговая зона Давида) ===
   if(g_fib.w_zone == 3)  // 61-78
   {
      // Цена в зоне 61-78 ВЫШЕ Pivot → ищем SHORT (контр-тренд к Pivot)
      // Цена в зоне 61-78 НИЖЕ Pivot → ищем LONG (контр-тренд к Pivot)
      score = -bias * 55;  // Против bias = возврат к Pivot
      
      // Бонус если дневной пивот подтверждает
      if(!pctx.weekly_daily_agree) score += (-bias) * 10;
      
      // Бонус если ADR исчерпан (цена "устала")
      if(pctx.adr_exhausted) score += (-bias) * 10;
   }
   
   // === ЗОНА 78-100 (зона Карни — последний шанс) ===
   else if(g_fib.w_zone == 4)  // 78-100
   {
      score = -bias * 70;  // Сильный контр-тренд сигнал
      
      if(!pctx.weekly_daily_agree) score += (-bias) * 10;
      if(pctx.adr_exhausted) score += (-bias) * 10;
      
      // Бонус если на сессионном уровне (Asia/London H/L)
      if(bias > 0 && pctx.above_london_high) score -= 10;  // Выше London High + зона 78
      if(bias < 0 && pctx.below_london_low)  score += 10;  // Ниже London Low + зона 78
   }
   
   // === ЗОНА >100 (пробой — сильный тренд) ===
   else if(g_fib.w_zone == 5)  // >100
   {
      // ВНИМАНИЕ: цена пробила 100% рейнджа прошлой недели
      // Это ТРЕНДОВОЕ движение — не контр-тренд!
      score = bias * 30;  // ПО ТРЕНДУ (слабый, осторожный)
      
      // Если ADR НЕ исчерпан → тренд может продолжиться
      if(!pctx.adr_exhausted) score += bias * 10;
   }
   
   // === ЗОНА 38-61 (переходная) ===
   else if(g_fib.w_zone == 2)  // 38-61
   {
      score = -bias * 25;  // Слабый контр-тренд
   }
   
   // === ЗОНА 0-38 и у Pivot (нейтрально) ===
   else
   {
      score = 0;  // У Pivot — нет направления
   }
   
   // === БОНУС КОНФЛЮЭНС ===
   if(pctx.fib_confluence)
   {
      // Fib уровень совпал с сессионным уровнем = очень сильный
      score = (int)(score * 1.3);  // +30% к score
   }
   
   return score;
}
```

### 12.5.5 РОЛЬ В TAKE PROFIT (цели 2R-13R)

```mql5
// Fib Pivot уровни используются как ЦЕЛИ для фиксации прибыли.
// Это НЕ часть scoring — это часть грейдинга и управления позицией.

struct FibTPTargets
{
   double target_2R;    // Ближайший Fib уровень по направлению сделки
   double target_3R;    // Следующий
   double target_5R;    // R/S 78 или 100
   double target_7R;    // R/S 100 или 138
   double target_13R;   // R/S 161 или 200
   string target_names[5]; // Названия уровней
};

void FibPivot_CalcTPTargets(int direction, double entryPrice, FibTPTargets &tp)
{
   // direction: +1 = LONG, -1 = SHORT
   // Находим Fib уровни ПО НАПРАВЛЕНИЮ сделки от точки входа
   
   double levels[];
   string names[];
   
   if(direction > 0)  // LONG → ищем R уровни выше цены
   {
      // Собираем все уровни выше entryPrice, сортируем по возрастанию
      // Ближайший = target_2R, следующий = target_3R, и т.д.
   }
   else  // SHORT → ищем S уровни ниже цены
   {
      // Собираем все уровни ниже entryPrice, сортируем по убыванию
   }
   
   // Также включить дневные Fib уровни в список целей
}

// Грейдинг с учётом Fib TP:
// Если target_5R существует и далеко → Grade A+ (потенциал 5R)
// Если только target_2R → Grade A (потенциал 2R)
// Если target = уже достигнут → Grade S (skip, потенциал исчерпан)
```

### 12.5.6 ВИЗУАЛИЗАЦИЯ НА ГРАФИКЕ

```mql5
// ДВА РЕЖИМА ОТОБРАЖЕНИЯ (настраивается через PivotDrawMode):

// === РЕЖИМ 1: FULL WEEK (линии на всю ширину текущей недели) ===
// Длина линий = от начала текущей недели (понедельник 00:00 broker)
// до текущего бара + 10 баров запас вправо.
// Подписи — справа от линии.

void FibPivot_DrawFullWeek()
{
   datetime weekStart = iTime(_Symbol, PERIOD_W1, 0);  // Начало текущей недели
   datetime now = TimeCurrent();
   datetime lineEnd = now + PeriodSeconds(_Period) * 10; // +10 баров вправо
   
   // Пример для Pivot линии:
   ObjectCreate(0, "FP_W_Pivot", OBJ_TREND, 0, weekStart, g_fib.w_pivot,
                lineEnd, g_fib.w_pivot);
   ObjectSetInteger(0, "FP_W_Pivot", OBJPROP_COLOR, g_scheme.pivotLine);
   ObjectSetInteger(0, "FP_W_Pivot", OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, "FP_W_Pivot", OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, "FP_W_Pivot", OBJPROP_RAY, false);
   
   // Подпись:
   ObjectCreate(0, "FP_W_Pivot_lbl", OBJ_TEXT, 0, lineEnd, g_fib.w_pivot);
   ObjectSetString(0, "FP_W_Pivot_lbl", OBJPROP_TEXT, 
      "WP " + DoubleToString(g_fib.w_pivot, _Digits));
   ObjectSetInteger(0, "FP_W_Pivot_lbl", OBJPROP_COLOR, g_scheme.pivotLine);
   ObjectSetInteger(0, "FP_W_Pivot_lbl", OBJPROP_FONTSIZE, 8);
   
   // Аналогично для R38, R61, R78, R100 и S38, S61, S78, S100
   // R138, R161, R200 — только если show_extended = true
   
   // Дневные пивоты: тонкие пунктирные линии
   // от начала текущего дня до конца дня
}

// === РЕЖИМ 2: SHORT SIDE (короткие линии сбоку с подписями) ===
// Линии шириной 40 баров справа от текущего бара.
// Обязательные подписи с названием и ценой.

void FibPivot_DrawShortSide()
{
   datetime barNow = iTime(_Symbol, _Period, 0);
   datetime lineStart = barNow;
   datetime lineEnd = barNow + PeriodSeconds(_Period) * 40; // 40 баров
   
   // Та же логика но короткие линии
   // Подписи: "R61 1.2785" "S78 1.2650" и т.д.
}
```

### 12.5.7 ЦВЕТОВАЯ СХЕМА (добавить в pp_color_schemes.mqh)

```mql5
// Добавить в структуру ColorScheme:
color pivotLine;       // Pivot линия (жёлтая по умолчанию)
color pivotR38;        // R/S 38
color pivotR61;        // R/S 61 — КЛЮЧЕВАЯ ЗОНА
color pivotR78;        // R/S 78 — ЗОНА КАРНИ
color pivotR100;       // R/S 100 — ПРОБОЙНЫЙ
color pivotR138;       // R/S 138 (расширенная)
color pivotR161;       // R/S 161 (расширенная)
color pivotR200;       // R/S 200 (расширенная)
color pivotDaily;      // Дневные пивоты (приглушённые)

// Deep Ocean:
g_scheme.pivotLine = C'255,215,0';     // Gold
g_scheme.pivotR38  = C'180,100,200';   // Soft Purple
g_scheme.pivotR61  = C'50,205,50';     // Lime Green — КЛЮЧЕВАЯ
g_scheme.pivotR78  = C'220,60,60';     // Red — КАРНИ
g_scheme.pivotR100 = C'0,200,200';     // Cyan — ПРОБОЙ
g_scheme.pivotR138 = C'230,160,50';    // Orange
g_scheme.pivotR161 = C'160,160,160';   // Gray
g_scheme.pivotR200 = C'140,130,80';    // Khaki
g_scheme.pivotDaily = C'120,120,60';   // Dim — менее заметные

// Для каждой из 5 цветовых схем — адаптировать к палитре
// Цвета Давида (из его индикатора) как ориентир:
//   Pivot=Yellow, R38/S38=Magenta, R61/S61=Lime,
//   R78/S78=Red, R100/S100=Cyan, R138/S138=Orange
```

### 12.5.8 ДАННЫЕ В МАРКЕТ КОНТЕКСТ И ЖУРНАЛ

```mql5
// Добавить в MarketContext:
double pivot_weekly;     // Значение Weekly Pivot
int    pivot_zone;       // Зона 0-5
int    pivot_bias;       // +1/-1
double pivot_daily;      // Значение Daily Pivot (если включён)
int    pivot_daily_zone; // Зона дневного пивота
double pivot_nearest_r;  // Ближайший R уровень (цена)
double pivot_nearest_s;  // Ближайший S уровень (цена)
string pivot_nearest_name; // "R61", "S78" и т.д.
bool   pivot_confluence; // Совпадение с сессионным уровнем
double adr_used_pct;     // % ADR использовано сегодня

// Добавить в журнал CSV (после NewsTitle):
// PivotW;PivotZone;PivotBias;PivotD;PivotDZone;PivotNearR;PivotNearS;
// PivotConfl;ADR_Used
```

### 12.5.9 ПАНЕЛЬ UI (добавить в блок агентов)

```
│  ── Agent System ──────────── Score ──     │
│  VWAP PB  [████████░░░░░░░░]    +65        │
│  ...                                       │
│  PVSRA    [██████░░░░░░░░░░]    +45        │
│  FibPivot [████████████░░░░]    +70        │  ← НОВЫЙ (10-я строка)
│                                            │
│  Decision: ▲ BUY 3R [529]                  │
│  Setup: FVG Continuation (A+)              │
│  Pivot Zone: S61-S78 ↑ | Target: R100     │  ← НОВАЯ СТРОКА
```

```mql5
// ПРАВИЛЬНАЯ логика Context Filter:

double CalcContextMultiplier(MarketContext &ctx)
{
   double mult = 1.0;  // БАЗОВЫЙ = 1.0 (нейтральный, НЕ ноль!)
   
   // Kill Zone бонус
   if(ctx.is_kill_zone) 
      mult *= 1.3;     // +30% в Kill Zone
   else
      mult *= 0.7;     // -30% вне Kill Zone (НЕ ноль!)
   
   // Блокировка (только в экстремальных случаях)
   if(ctx.day_of_week == 5 && ctx.hour_gmt >= 15)
      mult = 0.0;      // Пятница после 15:00 UTC → СТОП
      
   if(ctx.spread_pips > ctx.atr * 3.0)
      mult = 0.0;      // Спред > 3× ATR → СТОП
   
   // Новости (если модуль включён)
   if(EnableNewsCalendar && ctx.news_minutes_to >= 0)
   {
      if(ctx.news_impact >= 3 && ctx.news_minutes_to <= HighImpactBuffer_Min)
         mult = 0.0;   // Блок перед High Impact
      else if(ctx.news_impact >= 2 && ctx.news_minutes_to <= MedImpactBuffer_Min)
         mult *= 0.3;  // Сильное ослабление перед Medium
   }
   
   // Сессия — бонус за перекрытие
   if(ctx.session == SESSION_NY_LONDON)  // Лондон+НЙ перекрытие
      mult *= 1.2;
   
   return mult;
}

// WeightedScore считается ТАК:
double CalcWeightedScore(AgentSignal &signals[], int count, double ctxMult)
{
   double sum = 0;
   for(int i = 0; i < count; i++)
   {
      if(i == 4) continue;  // CtxFilter не голосует, он множитель
      sum += signals[i].score * signals[i].confidence;
   }
   return sum * ctxMult;  // Множитель НЕ ноль (кроме блокировки)
}
```

---

## 14. МОДУЛЬ: ЖУРНАЛ (pp_journal.mqh) — ИСПРАВЛЕННЫЙ

### Исправления относительно MT4 версии:

1. **Именование файла — очистка суффиксов брокера:**

```mql5
string CleanSymbol()
{
   string sym = _Symbol;
   
   // Список известных суффиксов
   string suffixes[] = {"b", ".raw", ".ecn", ".pro", "_m", 
                         "-ECN", ".std", ".r", ".e", ".p"};
   
   for(int i = 0; i < ArraySize(suffixes); i++)
   {
      int pos = StringLen(sym) - StringLen(suffixes[i]);
      if(pos > 3)  // Минимум 3 символа в имени (EUR)
      {
         if(StringSubstr(sym, pos) == suffixes[i])
         {
            sym = StringSubstr(sym, 0, pos);
            break;
         }
      }
   }
   return sym;
}

string GetJournalFileName()
{
   string sym = CleanSymbol();
   string tf = EnumToString(_Period);  // "PERIOD_M5" → нужно обрезать
   StringReplace(tf, "PERIOD_", "");   // → "M5"
   
   return JournalPrefix + "_" + sym + "_" + tf + ".csv";
   // Результат: Claude_Journal_GBPCAD_M5.csv
}
```

2. **Добавлены уровни в запись:**

```
Заголовок CSV (разделитель ;):

JournalV2;Symbol;TF;RecType;DateTime;BarTime;TradeID;Dir;
Sc_VWAP;Sc_SD;Sc_Str;Sc_Mom;Sc_CtxMult;Sc_WPR;Sc_BV;Sc_REI;Sc_PVSRA;
WtScore;Agree;ShouldTrade;RiskMult;LongV;ShortV;
Regime;Session;DayType;ADX;ATR;ATR_Ratio;SpreadPips;PriceVsVWAP;
ADR_Pos;IsKillZone;HourGMT;DoW;
BV_Type;PVSRA_Type;REI_Val;WPR1;WPR2;WPR3;WPR4;VolRatio;
PDH;PDL;AsiaH;AsiaL;LondonH;LondonL;MidnightOpen;PrevNYClose;
Setup;SClass;SBarsTo;
NewsMin;NewsImpact;NewsTitle;
EntryPx;SL;TP;Lots;RSize;
ClosePx;PnL_Money;PnL_R;DurBars;CloseReason;
Notes
```

Изменения vs MT4:
- Версия маркера: JournalV2 (вместо JournalV1)
- Разделитель: точка с запятой ";"
- ДОБАВЛЕНЫ: AsiaH, AsiaL, LondonH, LondonL, MidnightOpen, PrevNYClose
- ДОБАВЛЕНЫ: NewsMin, NewsImpact, NewsTitle
- CtxFilter записывается как множитель (Sc_CtxMult), НЕ как score
- WtScore теперь НЕ нулевой (исправлена формула агрегации)

3. **Продолжение файла при перезапуске:**

```mql5
void Journal_Init()
{
   if(!EnableJournal) return;
   g_journalFile = GetJournalFileName();
   
   if(FileIsExist(g_journalFile))
   {
      int h = FileOpen(g_journalFile, FILE_READ|FILE_CSV, ';');
      if(h != INVALID_HANDLE)
      {
         string marker = FileReadString(h);
         FileClose(h);
         if(StringFind(marker, "JournalV") >= 0)
         {
            Print("[JOURNAL] Продолжаю: ", g_journalFile);
            g_journalReady = true;
            return;
         }
         // Старый формат → бэкап
         string bak = g_journalFile + ".bak";
         FileMove(g_journalFile, 0, bak, 0);
      }
   }
   
   Journal_WriteHeader();
   g_journalReady = true;
}
```

---

## 15. МОДУЛЬ: НОВОСТНОЙ КАЛЕНДАРЬ (pp_news.mqh) — НОВЫЙ

```mql5
#define NEWS_URL "https://nfs.faireconomy.media/ff_calendar_thisweek.json"
#define NEWS_CACHE "ff_news_cache.json"
#define NEWS_UPDATE_SEC 3600  // Раз в час

struct NewsEvent
{
   string title;
   string country;
   datetime time;
   int    impact;       // 0=Holiday, 1=Low, 2=Medium, 3=High
   string forecast;
   string previous;
};

NewsEvent g_newsEvents[];
datetime  g_newsLastUpdate = 0;

bool News_Init()
{
   if(!EnableNewsCalendar) return true;
   return News_Download();
}

bool News_Download()
{
   if(TimeCurrent() - g_newsLastUpdate < NEWS_UPDATE_SEC)
      return true;
      
   char post[], result[];
   string headers = "User-Agent: Mozilla/5.0\r\n";
   string resultHeaders;
   
   int res = WebRequest("GET", NEWS_URL, headers, 5000, post, result, resultHeaders);
   
   if(res == 200)
   {
      string json = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
      // Сохранить кэш
      int h = FileOpen(NEWS_CACHE, FILE_WRITE|FILE_TXT|FILE_ANSI);
      if(h != INVALID_HANDLE) { FileWriteString(h, json); FileClose(h); }
      News_Parse(json);
      g_newsLastUpdate = TimeCurrent();
      return true;
   }
   
   Print("[NEWS] HTTP Error: ", res, ". Trying cache...");
   return News_ReadCache();
}

// Парсинг JSON (простой парсер)
// FF формат = массив JSON объектов
// Ищем "title":"...", "country":"...", "impact":"High", "date":"...", "time":"..."

void News_Parse(string json)
{
   ArrayResize(g_newsEvents, 0);
   // ... парсинг по маркерам (как в спецификации News_Calendar_Guide)
   // Фильтр: только валюты текущего символа или High Impact
}

int News_MinutesToNext(int minImpact = 3)
{
   datetime now = TimeCurrent();
   int closest = 99999;
   for(int i = 0; i < ArraySize(g_newsEvents); i++)
   {
      if(g_newsEvents[i].impact < minImpact) continue;
      int diff = (int)(g_newsEvents[i].time - now) / 60;
      if(diff >= -5 && diff < closest)
         closest = diff;
   }
   return closest;
}

void News_DrawOnChart()
{
   // Вертикальные линии: красная=High, оранжевая=Medium
   // Tooltip: Country + Title + Forecast/Previous
}
```

Требует настройку MT5:
```
Сервис → Настройки → Советники →
  ☑ Разрешить WebRequest для: https://nfs.faireconomy.media
```

---

## 16. ИНДИКАТОРЫ

### VWAP (Claude_v600_VWAP.mq5)

```mql5
// MQL5 индикатор: OnCalculate() вместо start()
#property indicator_chart_window
#property indicator_buffers 3
#property indicator_plots   3

double VWAPBuffer[];
double SD1UpBuffer[], SD1DnBuffer[];

int OnInit()
{
   SetIndexBuffer(0, VWAPBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, SD1UpBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, SD1DnBuffer, INDICATOR_DATA);
   
   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_LINE);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, clrYellow);
   // ...
   return INIT_SUCCEEDED;
}

int OnCalculate(const int rates_total, const int prev_calculated,
                const datetime &time[], const double &open[],
                const double &high[], const double &low[],
                const double &close[], const long &tick_volume[],
                const double &volume[], const int &spread[])
{
   // Расчёт VWAP: Σ(Price × Volume) / Σ(Volume)
   // Сброс по началу периода (Daily/Weekly/Monthly)
   // SD = sqrt(Σ((Price - VWAP)² × Volume) / Σ(Volume))
}
```

### VolumeProfile и AVWAP — аналогично, OnCalculate()

---

## 17. ГЛАВНЫЙ EA (Claude_v600_Tester_PropPanel.mq5)

```mql5
#property copyright "Claude v600"
#property version   "6.00"
#property description "Multi-Agent Trading System for MT5"

// Includes (в кавычках — из одной папки)
#include "Claude_v600_pp_inputs.mqh"
#include "Claude_v600_pp_diag.mqh"
#include "Claude_v600_pp_color_schemes.mqh"
#include "Claude_v600_pp_context.mqh"
#include "Claude_v600_pp_sessions.mqh"
#include "Claude_v600_pp_market_levels.mqh"
#include "Claude_v600_pp_agents.mqh"
#include "Claude_v600_pp_agents_ext.mqh"
#include "Claude_v600_pp_decision.mqh"
#include "Claude_v600_pp_ui_panel.mqh"
#include "Claude_v600_pp_learning.mqh"
#include "Claude_v600_pp_twap.mqh"
#include "Claude_v600_pp_setups.mqh"
#include "Claude_v600_pp_journal.mqh"
#include "Claude_v600_pp_news.mqh"

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/SymbolInfo.mqh>

CTrade         g_trade;
CPositionInfo  g_posInfo;
CSymbolInfo    g_symInfo;

// Глобальные хэндлы индикаторов
int g_hATR, g_hADX, g_hRSI, g_hEMA;
int g_hWPR[4];

// Глобальные данные агентов
AgentSignal g_signals[10];
TradeDecision g_decision;
MarketContext g_ctx;
datetime g_lastBar = 0;

int OnInit()
{
   // 1. Цветовая схема
   InitColorScheme(ColorScheme);
   ApplySchemeToChart();
   
   // 2. Создать хэндлы индикаторов
   g_hATR = iATR(_Symbol, _Period, ATR_Period);
   g_hADX = iADX(_Symbol, _Period, ADX_Period);
   g_hRSI = iRSI(_Symbol, _Period, 14, PRICE_CLOSE);
   g_hEMA = iMA(_Symbol, _Period, GetEMAPeriod(), 0, MODE_EMA, PRICE_CLOSE);
   
   if(Agent_WPR_Enabled) AGTX_InitWPR();
   
   // 3. Панель
   PP_UICreate();
   
   // 4. Журнал
   Journal_Init();
   
   // 5. Новости
   News_Init();
   
   // 6. Таймер (обновление новостей раз в час)
   EventSetTimer(3600);
   
   g_trade.SetExpertMagicNumber(600);
   
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   PP_UIDestroy();
   EventKillTimer();
   
   // Освободить хэндлы
   IndicatorRelease(g_hATR);
   IndicatorRelease(g_hADX);
   IndicatorRelease(g_hRSI);
   IndicatorRelease(g_hEMA);
   for(int i = 0; i < 4; i++)
      if(g_hWPR[i] != INVALID_HANDLE) IndicatorRelease(g_hWPR[i]);
}

void OnTick()
{
   // Обновление раз в бар
   datetime bt = iTime(_Symbol, _Period, 0);
   if(bt != g_lastBar)
   {
      g_lastBar = bt;
      
      // 1. Обновить контекст
      CTX_Update(g_ctx);
      
      // 2. Новости (проверить)
      if(EnableNewsCalendar)
      {
         g_ctx.news_minutes_to = News_MinutesToNext(3);
         // ... заполнить остальные поля
      }
      
      // 3. Запустить агентов
      if(EnableAgentSystem)
      {
         AGT_RunAll(g_signals, g_ctx);         // Агенты 1-5
         AGTX_RunAll(g_signals, g_ctx);        // Агенты 6-9
         FibPivot_RunAgent(g_signals, g_ctx);    // Агент 10 (Fib Pivot)
         DEC_MakeDecision(g_signals, 9, g_ctx, g_decision);
         
         // 4. Сетапы
         if(EnableSetupDetection)
            SETUP_Detect(g_signals, g_ctx);
         
         // 5. Обновить панель
         if(ShowAgentPanel)
         {
            // Заполнить глобальные UI переменные
            for(int i = 0; i < 9; i++)
            {
               g_uiAgentNames[i]  = g_signals[i].name;
               g_uiAgentScores[i] = g_signals[i].score;
            }
            g_uiAgentCount = 9;
            g_uiDecShouldTrade  = g_decision.shouldTrade;
            g_uiDecDirection    = g_decision.direction;
            g_uiDecRiskMultiple = g_decision.riskMultiple;
            g_uiDecWeightedScore = g_decision.weightedScore;
            
            PP_UIUpdateAgentBlock();
         }
         
         // 6. Журнал
         if(EnableJournal)
            Journal_LogSignal(g_signals, g_ctx, g_decision);
         
         // 7. Торговля
         if(g_decision.shouldTrade)
         {
            ExecuteTrade(g_decision);
            if(EnableJournal) Journal_LogTrade(g_decision);
         }
      }
   }
   
   // Обновить панель каждый тик (для P&L)
   PP_UIUpdatePrices();
}

void OnTimer()
{
   // Обновить новости раз в час
   if(EnableNewsCalendar)
      News_Download();
}

void OnChartEvent(const int id, const long &lparam,
                   const double &dparam, const string &sparam)
{
   // Обработка нажатий кнопок панели
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      PP_UIHandleClick(sparam);
   }
}
```

---

## 18. ПОРЯДОК РЕАЛИЗАЦИИ

```
Шаг  │ Файл                     │ Зависимости
─────┼──────────────────────────┼─────────────────────
  1  │ pp_inputs.mqh            │ —
  2  │ pp_diag.mqh              │ inputs
  3  │ pp_color_schemes.mqh     │ inputs (enum)
  4  │ pp_context.mqh           │ inputs
  5  │ pp_sessions.mqh          │ inputs
  6  │ pp_market_levels.mqh     │ inputs, sessions
  7  │ pp_agents.mqh            │ inputs, context
  8  │ pp_agents_ext.mqh        │ inputs, context, agents
  9  │ pp_fib_pivot.mqh         │ inputs, context, sessions, color_schemes
 10  │ pp_decision.mqh          │ agents, agents_ext, fib_pivot, context
 11  │ pp_setups.mqh            │ agents, context, decision, fib_pivot
 12  │ pp_journal.mqh           │ agents, context, decision, fib_pivot
 13  │ pp_news.mqh              │ inputs
 14  │ pp_learning.mqh          │ agents, decision
 15  │ pp_twap.mqh              │ decision
 16  │ pp_ui_panel.mqh          │ color_schemes, inputs
 17  │ Main EA .mq5             │ ВСЕ
 18  │ VWAP.mq5                 │ — (отдельный индикатор)
 19  │ AVWAP.mq5                │ — (отдельный индикатор)
 20  │ VolumeProfile.mq5        │ — (отдельный индикатор)
```

---

## 19. ВЕРИФИКАЦИЯ

```
Чек-лист после создания:

□ Каждый .mqh имеет #ifndef __CLAUDE_V600_...__ guard
□ Все #include через кавычки "файл.mqh"
□ Main EA компилируется с 0 errors в MetaEditor 5
□ Все 3 индикатора компилируются с 0 errors
□ Панель отображается (кнопки, метрики, биржи)
□ Блок агентов показывает 10 строк с полосками (было 9)
□ Блок новостей показывает ближайшие события
□ Журнал создаёт файл Claude_Journal_SYMBOL_TF.csv
□ WeightedScore ≠ 0 когда агенты дают сигналы
□ Context Filter НЕ обнуляет score (кроме блокировки)
□ Имя символа очищено от суффиксов брокера
□ Уровни AsiaH/L, LondonH/L в журнале заполнены
□ VWAP индикатор рисует линию на графике
□ Fib Pivot линии отображаются на графике (оба режима)
□ Подписи Fib Pivot уровней видны и читаемы
□ Цвета Fib Pivot соответствуют текущей цветовой схеме
□ Дневные пивоты отображаются (тонкие пунктирные)
□ PivotZone и PivotBias заполняются в журнале
□ Панель показывает строку "Pivot Zone: S61-S78"
□ Кнопки 2R-7R открывают сделки через CTrade
□ Кнопки BE переносят стоп через trade.PositionModify
□ Кнопки Close закрывают через trade.PositionClose

Тест в Strategy Tester:
  Режим: Визуальный (Visual mode)
  Символ: GBPUSD
  Период: M5
  Модель: Все тики
  EnableAgentSystem = true
  EntryThreshold = 70
  MinAgentsAgree = 3
  Agent_FibPivot_Enabled = true
  DrawFibPivotLines = true
```

---

## 20. КРИТИЧЕСКИЕ ПРАВИЛА

```
1. НАТИВНЫЙ MQL5 — не транслитерация MQL4. Использовать:
   CTrade, CPositionInfo, CSymbolInfo, OnCalculate,
   CopyBuffer, iTime, PositionsTotal, EventSetTimer

2. Все формулы BV/PVSRA/TD_REI/FIB_PIVOT — ВСТРОЕННЫЕ (без iCustom)

3. WPR — через iWPR() + CopyBuffer()

4. Все цвета — через g_scheme (НЕ хардкод), включая Fib Pivot

5. Хэндлы индикаторов — создать в OnInit(), 
   освободить в OnDeinit() через IndicatorRelease()

6. ArraySetAsSeries(buf, true) для всех ценовых массивов

7. CtxFilter БАЗОВЫЙ = 1.0 (не ноль!)
   Kill Zone = 1.3, Вне Kill Zone = 0.7
   Ноль ТОЛЬКО: пятница >15:00, спред >3×ATR, блок на новостях

8. Журнал: разделитель ";", JournalV2, суффиксы брокера отрезать
   Новые поля: PivotW, PivotZone, PivotBias, PivotD, PivotNearR, 
   PivotNearS, PivotConfl, ADR_Used

9. Обновление панели — раз в бар (НЕ каждый тик)
   Исключение: P&L — каждый тик

10. Все модули выключены по умолчанию КРОМЕ EnableJournal=true

11. НЕ использовать DLL — только WebRequest для новостей

12. Fib Pivot рассчитывается раз в неделю (OnInit + при смене W1 бара)
    Daily Pivot — раз в день (при смене D1 бара)
    НЕ пересчитывать каждый тик!

13. Агент 10 пишет signals[9] — массив теперь [0..9], 10 элементов
```

---

## 21. CHANGELOG v1 → v2

```
Версия 2.0 — Изменения:

НОВЫЕ МОДУЛИ:
  + Claude_v600_pp_fib_pivot.mqh — Агент 10: Weekly Fib Pivot
    Источник: Davit's Pivot Trading (Forex Factory, 10+ лет, 5000+ постов)
    Формулы полностью встроены (без iCustom)
    
РАСШИРЕНИЯ:
  + pp_inputs.mqh: Секция 18 — параметры Fib Pivot
    - Agent_FibPivot_Enabled, FibPivot_Weight
    - DrawFibPivotLines, PivotDrawMode (FULL_WEEK / SHORT_SIDE)
    - PivotCalcMethod (HLC / HLCC / HLOC)
    - EnableDailyPivot, ShowPivotZoneOnPanel
  
  + pp_color_schemes.mqh: 9 новых цветов для Fib Pivot
    - pivotLine, pivotR38, pivotR61, pivotR78, pivotR100
    - pivotR138, pivotR161, pivotR200, pivotDaily
    - Адаптировано для всех 5 цветовых схем
  
  + pp_context.mqh: 10 новых полей в MarketContext
    - pivot_weekly, pivot_zone, pivot_bias
    - pivot_daily, pivot_daily_zone
    - pivot_nearest_r, pivot_nearest_s, pivot_nearest_name
    - pivot_confluence, adr_used_pct
  
  + pp_journal.mqh: 9 новых колонок
    - PivotW, PivotZone, PivotBias, PivotD, PivotDZone
    - PivotNearR, PivotNearS, PivotConfl, ADR_Used
  
  + pp_ui_panel.mqh: 
    - 10-я строка в блоке агентов "FibPivot"
    - Новая строка "Pivot Zone: S61-S78 ↑ | Target: R100"
    - Высота панели +40px

  + pp_decision.mqh:
    - signals[] массив [10] вместо [9]
    - CalcWeightedScore обрабатывает 10 агентов
    - AgreeCount считает из 9 голосующих (Ctx Filter + Fib Pivot голосует)
  
  + pp_setups.mqh:
    - FibTP targets используются для грейдинга TP
    - Новый сетап "Fib Pivot Reversal" (зона 61-100 + подтверждение)
  
  + Main EA .mq5:
    - #include pp_fib_pivot.mqh
    - FibPivot_Calculate() в OnInit() и при смене W1/D1 бара
    - FibPivot_RunAgent() после AGTX_RunAll()
    - FibPivot_Draw() в визуализации
    - g_signals[10], g_uiAgentNames[10], g_uiAgentScores[10]

СТРУКТУРА ФАЙЛОВ: 20 модулей (было 19)
  17 .mqh + 1 .mq5 (EA) + 3 .mq5 (индикаторы) = 21 файл

КЛЮЧЕВЫЕ ОСОБЕННОСТИ АГЕНТА 10:
  - Недельный масштаб (ни один другой агент не даёт)
  - Fibonacci зоны (0.382, 0.618, 0.786, 1.000)
  - Мульти-масштабный анализ:
    Weekly Pivot → Daily Pivot → ADR → Session H/L
  - Конфлюэнс: Fib уровень ≈ сессионный уровень → score ×1.3
  - TP targets: уровни как цели для 2R-13R
  - Два режима отображения: Full Week / Short Side
  - Формула Давида: Pivot = (H+L+C)/3, Range = H-L
  - Зона 61-78: основная торговая зона
  - Зона 78: Scott Carney "последний шанс на разворот"
  - Зона >100: сильный тренд, торговать ПО тренду
```
