#ifndef __CLAUDE_V600_PP_DIAG_MQH__
#define __CLAUDE_V600_PP_DIAG_MQH__
#property strict

// ==================== ДИАГНОСТИКА ====================
// Модуль диагностики и логирования для Claude_v600
// Выводит информацию в лог MetaTrader и в комментарии на графике

string g_diagMessages[];
int    g_diagCount = 0;
bool   g_diagEnabled = false;
datetime g_diagLastUpdate = 0;

//+------------------------------------------------------------------+
//| Инициализация диагностики                                         |
//+------------------------------------------------------------------+
void DIAG_Init()
{
   g_diagEnabled = EnableDiagnostics;
   g_diagCount = 0;
   ArrayResize(g_diagMessages, 0);

   if(g_diagEnabled)
   {
      Print("[DIAG] ==========================================");
      Print("[DIAG] Claude_v600 Diagnostics Initialized");
      Print("[DIAG] Symbol: ", _Symbol);
      Print("[DIAG] Period: ", EnumToString(_Period));
      Print("[DIAG] Broker: ", AccountInfoString(ACCOUNT_COMPANY));
      Print("[DIAG] Account: ", AccountInfoInteger(ACCOUNT_LOGIN));
      Print("[DIAG] Leverage: 1:", AccountInfoInteger(ACCOUNT_LEVERAGE));
      Print("[DIAG] ==========================================");
   }
}

//+------------------------------------------------------------------+
//| Деинициализация                                                    |
//+------------------------------------------------------------------+
void DIAG_Deinit()
{
   if(g_diagEnabled)
      Print("[DIAG] Claude_v600 Diagnostics Stopped");

   ArrayFree(g_diagMessages);
   g_diagCount = 0;
}

//+------------------------------------------------------------------+
//| Логирование сообщения                                              |
//+------------------------------------------------------------------+
void DIAG_Log(string module, string message)
{
   if(!g_diagEnabled) return;

   string fullMsg = "[" + module + "] " + message;
   Print("[DIAG] ", fullMsg);

   // Хранить последние 50 сообщений для панели
   g_diagCount++;
   int sz = ArraySize(g_diagMessages);
   if(sz >= 50)
   {
      // Сдвигаем массив
      for(int i = 0; i < sz - 1; i++)
         g_diagMessages[i] = g_diagMessages[i + 1];
      g_diagMessages[sz - 1] = fullMsg;
   }
   else
   {
      ArrayResize(g_diagMessages, sz + 1);
      g_diagMessages[sz] = fullMsg;
   }
}

//+------------------------------------------------------------------+
//| Логирование с уровнем важности                                     |
//+------------------------------------------------------------------+
void DIAG_LogLevel(string module, string message, int level)
{
   // level: 0=INFO, 1=WARNING, 2=ERROR, 3=CRITICAL
   if(!g_diagEnabled && level < 2) return; // Ошибки всегда логируем

   string prefix = "";
   switch(level)
   {
      case 0: prefix = "INFO: ";     break;
      case 1: prefix = "WARN: ";     break;
      case 2: prefix = "ERROR: ";    break;
      case 3: prefix = "CRITICAL: "; break;
   }

   string fullMsg = "[" + module + "] " + prefix + message;
   Print("[DIAG] ", fullMsg);

   if(level >= 2)
      Alert("[Claude_v600] ", fullMsg);
}

//+------------------------------------------------------------------+
//| Логирование инициализации хэндла индикатора                        |
//+------------------------------------------------------------------+
void DIAG_LogHandle(string name, int handle)
{
   if(!g_diagEnabled) return;

   if(handle == INVALID_HANDLE)
      DIAG_LogLevel("INIT", name + " handle FAILED: " + IntegerToString(GetLastError()), 2);
   else
      DIAG_Log("INIT", name + " handle OK: " + IntegerToString(handle));
}

//+------------------------------------------------------------------+
//| Логирование торговой операции                                      |
//+------------------------------------------------------------------+
void DIAG_LogTrade(string action, string symbol, double lots, double price,
                    double sl, double tp)
{
   if(!g_diagEnabled) return;

   string msg = action + " " + symbol
      + " lots=" + DoubleToString(lots, 2)
      + " price=" + DoubleToString(price, _Digits)
      + " SL=" + DoubleToString(sl, _Digits)
      + " TP=" + DoubleToString(tp, _Digits);

   DIAG_Log("TRADE", msg);
}

//+------------------------------------------------------------------+
//| Логирование сигналов агентов                                       |
//+------------------------------------------------------------------+
void DIAG_LogSignals(AgentSignal &signals[], int count)
{
   if(!g_diagEnabled) return;

   string msg = "Signals: ";
   for(int i = 0; i < count; i++)
   {
      if(!signals[i].enabled) continue;
      msg += signals[i].name + "=" + IntegerToString(signals[i].score) + " ";
   }
   DIAG_Log("AGENTS", msg);
}

//+------------------------------------------------------------------+
//| Вывод диагностики на график (последние N строк)                    |
//+------------------------------------------------------------------+
void DIAG_ShowOnChart(int maxLines = 10)
{
   if(!g_diagEnabled) return;

   int sz = ArraySize(g_diagMessages);
   int start = MathMax(0, sz - maxLines);

   string text = "=== Claude_v600 Diagnostics ===\n";
   for(int i = start; i < sz; i++)
      text += g_diagMessages[i] + "\n";

   Comment(text);
}

//+------------------------------------------------------------------+
//| Проверка состояния счёта                                           |
//+------------------------------------------------------------------+
void DIAG_CheckAccount()
{
   if(!g_diagEnabled) return;

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   double margin  = AccountInfoDouble(ACCOUNT_MARGIN);
   double freeM   = AccountInfoDouble(ACCOUNT_MARGIN_FREE);

   if(equity < balance * 0.9)
      DIAG_LogLevel("ACCOUNT", "Equity < 90% of Balance! DD=" +
         DoubleToString((1.0 - equity / balance) * 100, 1) + "%", 1);

   if(freeM < margin * 0.5)
      DIAG_LogLevel("ACCOUNT", "Free margin < 50% of margin!", 1);
}

//+------------------------------------------------------------------+
//| Таймер диагностики (вызывать каждый бар)                           |
//+------------------------------------------------------------------+
void DIAG_OnBar()
{
   if(!g_diagEnabled) return;

   DIAG_CheckAccount();
   g_diagLastUpdate = TimeCurrent();
}

#endif
