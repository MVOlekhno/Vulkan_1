# ЗАДАЧА: Исправить runtime crash + 7 багов в Claude_v600

## Приоритет: от критичного к косметическому

---

## 🔴 БАГ 1 (КРИТИЧЕСКИЙ): array out of range — CRASH

**Файл**: `Claude_v600_pp_agents_ext.mqh`  
**Строка**: 319, столбец 43  
**Ошибка**: `array out of range in 'Claude_v600_pp_agents_ext.mqh' (319,43)`

### Корневая причина

В функции `AGTX_TDREI()` (строка 285) на строке 297:
```mql5
int barsNeeded = period + 6;  // НЕПРАВИЛЬНО: мало баров!
```

Цикл на строках 312-328 обращается к индексам `i+8`:
```mql5
for(int i = 0; i < period; i++)
{
    // строка 316: close[i+8]  ← максимальный индекс!
    high[i+2] >= close[i+7] || high[i+2] >= close[i+8]
```

Когда `i = period - 1`, максимальный индекс = `(period-1) + 8 = period + 7`.
Но массив содержит только `period + 6` элементов (индексы 0..period+5).

**Обращение к `close[period+7]`** выходит за границу массива на 2 элемента.

### Исправление

Строка 297 — изменить расчёт `barsNeeded`:

```mql5
// ❌ БЫЛО (строка 297):
int barsNeeded = period + 6;

// ✅ СТАЛО:
int barsNeeded = period + 9;  // i от 0 до period-1, максимум i+8, итого period-1+8+1 = period+8, с запасом +1
```

**Математика**: максимальный индекс = `(period-1) + 8 = period + 7`. Нужен массив размером `period + 8`. С запасом: `period + 9`.

---

## 🔴 БАГ 2 (ЛОГИЧЕСКИЙ): RSI дивергенция — сравнение с самим собой

**Файл**: `Claude_v600_pp_agents.mqh`  
**Строка**: 345

```mql5
// ❌ БЫЛО (строка 345):
if(high2[0] > high2[5] && g_bufRSI[0] < g_bufRSI[0])  // ВСЕГДА false!

// ✅ СТАЛО:
if(high2[0] > high2[5] && g_bufRSI[0] < g_bufRSI[5])  // Сравниваем текущий RSI с RSI 5 баров назад
```

Также нужно убедиться что `g_bufRSI` содержит минимум 6 элементов. Перед этим блоком (перед строкой 340) добавить проверку:

```mql5
// Дивергенция RSI vs цена
if(CopyBuffer(g_hRSI_agt, 0, 0, 10, g_bufRSI) < 10) { /* уже скопировано выше? */ }
```

Проверь, что перед строкой 340 в функции `AGT_Momentum()` уже был вызов `CopyBuffer(g_hRSI_agt, 0, 0, N, g_bufRSI)` с N >= 6. Если N < 6 — увеличь до 10.

---

## 🟡 БАГ 3 (ОТОБРАЖЕНИЕ): Имена агентов "Agent 0..9" вместо реальных имён

**Файл**: `Claude_v600_pp_ui_panel.mqh`  
**Строка**: 213

### Причина
При создании панели (строка 213) имена прописаны жёстко:
```mql5
PP_UICreateLabel(pfx + "_name", "Agent " + IntegerToString(i), ...);
```

Имена обновляются в `PP_UIUpdateAgentBlock()` (строка 384), НО эта функция вызывается только внутри блока `if(EnableAgentSystem)` в OnTick() (строка 257 главного EA), который срабатывает **РАЗ В БАР**. До первого нового бара панель показывает дефолтные имена.

### Исправление
Инициализировать имена агентов СРАЗУ в OnInit() главного EA (`Claude_v600_Tester_PropPanel.mq5`), после строки 134 (`PP_UICreate()`):

```mql5
// 14. Панель
PP_UICreate();
DIAG_Log("INIT", "Panel OK");

// Инициализировать имена агентов для панели
g_signals[0].name = "VWAP";
g_signals[1].name = "SD";
g_signals[2].name = "Structure";
g_signals[3].name = "Momentum";
g_signals[4].name = "CtxFilter";
g_signals[5].name = "WPR MTF";
g_signals[6].name = "BetterVol";
g_signals[7].name = "TD REI";
g_signals[8].name = "PVSRA";
g_signals[9].name = "FibPivot";

// Обновить панель сразу с именами
for(int i = 0; i < MAX_AGENTS; i++)
{
   g_uiAgentNames[i] = g_signals[i].name;
   g_uiAgentScores[i] = 0;
}
g_uiAgentCount = MAX_AGENTS;
PP_UIUpdateAgentBlock();
```

---

## 🟡 БАГ 4 (ОТОБРАЖЕНИЕ): Таймфрейм "PERIOD_H1" вместо "H1"

**Файл**: `Claude_v600_pp_ui_panel.mqh`  
**Строка**: 72

```mql5
// ❌ БЫЛО (строка 72):
_Symbol + "  " + EnumToString(_Period) + "     Claude_v600",

// ✅ СТАЛО:
string tfStr = EnumToString(_Period);
StringReplace(tfStr, "PERIOD_", "");
```

Затем в строке создания label:
```mql5
PP_UICreateLabel(PANEL_PREFIX + "title",
   CleanSymbol() + "  " + tfStr + "     Claude_v600",
   g_panelX + S(10), y, g_scheme.textHighlight, S(10));
```

**Примечание**: Функция `CleanSymbol()` определена в модуле журнала или контекста. Если она не видна в scope `pp_ui_panel.mqh` — добавь её туда или используй локальную версию.

---

## 🟡 БАГ 5 (ОТОБРАЖЕНИЕ): Суффикс брокера "+" не очищен

**Файл**: несколько файлов  

Символ показывается как `AUDUSD+` вместо `AUDUSD`. Журнал создаёт файл `Claude_Journal_AUDUSD+_H1.csv` — символ `+` в имени файла.

### Проверить функцию CleanSymbol()

Убедись что она корректно обрабатывает суффикс `+`. Если CleanSymbol() проверяет только длину > 6, то `AUDUSD+` = 7 символов, и первые 6 = `AUDUSD` — должно работать. 

**НО**: Если CleanSymbol() использует другую логику — добавь обработку `+`:
```mql5
// Убрать '+' в конце (типичный суффикс ECN брокеров)
int plusPos = StringFind(sym, "+");
if(plusPos > 0) sym = StringSubstr(sym, 0, plusPos);
```

CleanSymbol() должна использоваться:
1. В заголовке панели (строка 72 ui_panel)
2. В имени файла журнала
3. Везде где символ показывается пользователю

**НО НЕ** в торговых операциях (`g_trade.Buy`, `CopyBuffer`, `iATR` и т.д.) — брокер требует полное имя `AUDUSD+`.

---

## 🟡 БАГ 6 (ФУНКЦИОНАЛ): Кнопки торговли — заглушки вместо реальных ордеров

**Файл**: `Claude_v600_pp_ui_panel.mqh`  
**Строки**: 567-574, 599-602, 614-617, 627-629

Три функции содержат только `Print()` вместо реальных торговых операций:

### PP_UIExecuteTrade (строка 532):
```mql5
// ❌ БЫЛО (строки 567-574): только Print
Print("[UI] Trade request: ", ...);

// ✅ СТАЛО: реальный ордер через g_trade
string comment = "CV6_UI_" + IntegerToString(rMultiple) + "R";
if(direction > 0)
{
   if(!g_trade.Buy(lotCalc, _Symbol, price, sl, tp, comment))
      Print("[UI] BUY FAILED: ", GetLastError());
}
else
{
   if(!g_trade.Sell(lotCalc, _Symbol, price, sl, tp, comment))
      Print("[UI] SELL FAILED: ", GetLastError());
}
```

### PP_UIMoveToBreakeven (строка 580):
```mql5
// ❌ БЫЛО (строка 601): только Print
Print("[UI] Moving SL to BE: ticket=", ticket, " newSL=", newSL);

// ✅ СТАЛО: реальная модификация
if(!g_trade.PositionModify(ticket, newSL, currentTP))
   Print("[UI] BE FAILED: ticket=", ticket, " Error=", GetLastError());
else
   Print("[UI] BE OK: ticket=", ticket, " newSL=", newSL);
```

### PP_UICloseByType (строка 608):
```mql5
// ❌ БЫЛО (строка 616): только Print
Print("[UI] Close request: ticket=", ticket);

// ✅ СТАЛО:
if(!g_trade.PositionClose(ticket))
   Print("[UI] Close FAILED: ticket=", ticket, " Error=", GetLastError());
```

### PP_UICloseAll (строка 623):
```mql5
// ❌ БЫЛО (строка 629): только Print
Print("[UI] Close ALL request: ticket=", ticket);

// ✅ СТАЛО:
if(!g_trade.PositionClose(ticket))
   Print("[UI] Close ALL FAILED: ticket=", ticket, " Error=", GetLastError());
```

---

## 🟢 БАГ 7 (MINOR): Неиспользуемая переменная pricePrev2

**Файл**: `Claude_v600_pp_agents.mqh`  
**Строка**: 342

Это warning, не error. Переменная объявлена но не используется.  
Удалить объявление или закомментировать — это уберёт warning при компиляции.

---

## СВОДНАЯ ТАБЛИЦА ИЗМЕНЕНИЙ

```
Файл                              Строки    Тип        Описание
─────────────────────────────────────────────────────────────────────
pp_agents_ext.mqh                 297       CRASH      barsNeeded = period+6 → period+9
pp_agents.mqh                     345       LOGIC      g_bufRSI[0]<g_bufRSI[0] → [5]
pp_agents.mqh                     ~342      WARNING    удалить pricePrev2
pp_ui_panel.mqh                   72        DISPLAY    PERIOD_H1 → H1, + CleanSymbol()
pp_ui_panel.mqh                   213       DISPLAY    дефолт имена → обновляются в OnInit
pp_ui_panel.mqh                   567-574   FUNCTION   заглушка Print → g_trade.Buy/Sell
pp_ui_panel.mqh                   601       FUNCTION   заглушка Print → g_trade.PositionModify
pp_ui_panel.mqh                   616,629   FUNCTION   заглушка Print → g_trade.PositionClose
Tester_PropPanel.mq5              ~135      DISPLAY    инициализация имён агентов
pp_journal.mqh / CleanSymbol()    varies    DISPLAY    суффикс "+" в имени символа
```

---

## КОММИТ

```
fix: исправлен crash array out of range + 6 багов

КРИТИЧЕСКОЕ:
1. pp_agents_ext.mqh: AGTX_TDREI() — barsNeeded был period+6, но
   цикл обращается к индексу i+8 (нужно period+9). Crash на строке 319.

ЛОГИКА:
2. pp_agents.mqh: RSI дивергенция сравнивала g_bufRSI[0] < g_bufRSI[0]
   (всегда false). Исправлено на g_bufRSI[0] < g_bufRSI[5].

ОТОБРАЖЕНИЕ:
3. Имена агентов инициализируются в OnInit() — панель сразу показывает
   VWAP/SD/Structure/... вместо Agent 0/1/2/...
4. Таймфрейм отображается как "H1" вместо "PERIOD_H1"
5. CleanSymbol() убирает суффикс "+" брокера

ФУНКЦИОНАЛ:
6. Кнопки 2R-7R, BE, Close теперь выполняют реальные торговые
   операции через g_trade (Buy/Sell/PositionModify/PositionClose)
   вместо Print-заглушек.

MINOR:
7. Удалён неиспользуемый pricePrev2 (warning)
```
