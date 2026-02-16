#ifndef __CLAUDE_V600_PP_TWAP_MQH__
#define __CLAUDE_V600_PP_TWAP_MQH__
#property strict

#include <Trade/Trade.mqh>

// ==================== TWAP ИСПОЛНЕНИЕ ====================
// Time-Weighted Average Price — слайсинг ордеров
// По умолчанию ВЫКЛЮЧЕН

struct TWAPOrder
{
   bool     active;
   int      direction;      // +1=BUY, -1=SELL
   double   totalLots;
   double   lotPerSlice;
   int      totalSlices;
   int      executedSlices;
   int      intervalSec;
   datetime nextSliceTime;
   double   sl;
   double   tp;
   double   avgPrice;
   double   cancelThreshold; // Пипсов — отмена если цена ушла
   double   startPrice;
};

TWAPOrder g_twap;

//+------------------------------------------------------------------+
//| Инициализация TWAP                                                 |
//+------------------------------------------------------------------+
void TWAP_Init()
{
   ZeroMemory(g_twap);
   g_twap.active = false;
}

//+------------------------------------------------------------------+
//| Начать TWAP исполнение                                             |
//+------------------------------------------------------------------+
bool TWAP_Start(int direction, double totalLots, double sl, double tp)
{
   if(!EnableTWAP || g_twap.active) return false;

   g_twap.active = true;
   g_twap.direction = direction;
   g_twap.totalLots = totalLots;
   g_twap.totalSlices = TWAP_Slices;
   g_twap.lotPerSlice = NormalizeDouble(totalLots / TWAP_Slices, 2);
   g_twap.executedSlices = 0;
   g_twap.intervalSec = TWAP_Interval;
   g_twap.nextSliceTime = TimeCurrent();  // Первый слайс сразу
   g_twap.sl = sl;
   g_twap.tp = tp;
   g_twap.cancelThreshold = TWAP_CancelThreshold;
   g_twap.startPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   g_twap.avgPrice = 0;

   // Убедиться что lotPerSlice >= минимальный лот
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   if(g_twap.lotPerSlice < minLot)
   {
      g_twap.lotPerSlice = minLot;
      g_twap.totalSlices = (int)MathFloor(totalLots / minLot);
      if(g_twap.totalSlices < 1) g_twap.totalSlices = 1;
   }

   Print("[TWAP] Started: ", (direction > 0) ? "BUY" : "SELL",
         " Total=", totalLots, " Slices=", g_twap.totalSlices,
         " Interval=", TWAP_Interval, "sec");

   return true;
}

//+------------------------------------------------------------------+
//| Обработка TWAP (вызывать каждый тик)                                |
//+------------------------------------------------------------------+
void TWAP_OnTick(CTrade &trade)
{
   if(!EnableTWAP || !g_twap.active) return;

   // Проверка отмены: цена ушла слишком далеко
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double drift = MathAbs(price - g_twap.startPrice) / (_Point * 10.0);

   if(drift > g_twap.cancelThreshold)
   {
      Print("[TWAP] Cancelled: price drifted ", DoubleToString(drift, 1), " pips");
      g_twap.active = false;
      return;
   }

   // Проверка времени
   if(TimeCurrent() < g_twap.nextSliceTime) return;

   // Исполнить следующий слайс
   if(g_twap.executedSlices < g_twap.totalSlices)
   {
      // Последний слайс — остаток лотов
      double lots = g_twap.lotPerSlice;
      if(g_twap.executedSlices == g_twap.totalSlices - 1)
      {
         lots = g_twap.totalLots - g_twap.lotPerSlice * g_twap.executedSlices;
         lots = NormalizeDouble(lots, 2);
      }

      double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      if(lots < minLot) lots = minLot;

      bool result = false;
      double execPrice = 0;

      if(g_twap.direction > 0)
      {
         execPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         result = trade.Buy(lots, _Symbol, execPrice,
                            g_twap.sl, g_twap.tp, "TWAP slice");
      }
      else
      {
         execPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         result = trade.Sell(lots, _Symbol, execPrice,
                             g_twap.sl, g_twap.tp, "TWAP slice");
      }

      if(result)
      {
         g_twap.executedSlices++;

         // Обновить средневзвешенную цену
         double prevTotal = g_twap.avgPrice * (g_twap.executedSlices - 1) * g_twap.lotPerSlice;
         double curTotal = prevTotal + execPrice * lots;
         double totalLots = g_twap.lotPerSlice * (g_twap.executedSlices - 1) + lots;
         g_twap.avgPrice = (totalLots > 0) ? curTotal / totalLots : execPrice;

         Print("[TWAP] Slice ", g_twap.executedSlices, "/", g_twap.totalSlices,
               " executed. Lots=", lots, " Price=", execPrice);

         g_twap.nextSliceTime = TimeCurrent() + g_twap.intervalSec;
      }
      else
      {
         Print("[TWAP] Slice failed! Error: ", GetLastError());
      }
   }

   // Проверка завершения
   if(g_twap.executedSlices >= g_twap.totalSlices)
   {
      Print("[TWAP] Completed. AvgPrice=", DoubleToString(g_twap.avgPrice, _Digits));
      g_twap.active = false;
   }
}

//+------------------------------------------------------------------+
//| Отменить TWAP                                                      |
//+------------------------------------------------------------------+
void TWAP_Cancel()
{
   if(g_twap.active)
   {
      Print("[TWAP] Manually cancelled. Executed ", g_twap.executedSlices,
            "/", g_twap.totalSlices, " slices.");
      g_twap.active = false;
   }
}

//+------------------------------------------------------------------+
//| TWAP активен?                                                      |
//+------------------------------------------------------------------+
bool TWAP_IsActive() { return g_twap.active; }

//+------------------------------------------------------------------+
//| Получить прогресс TWAP                                             |
//+------------------------------------------------------------------+
string TWAP_GetStatus()
{
   if(!g_twap.active) return "Inactive";

   return "TWAP " + IntegerToString(g_twap.executedSlices) + "/" +
          IntegerToString(g_twap.totalSlices) +
          " Avg=" + DoubleToString(g_twap.avgPrice, _Digits);
}

#endif
