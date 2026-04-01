#ifndef __CLAUDE_V600_PP_UI_PANEL_MQH__
#define __CLAUDE_V600_PP_UI_PANEL_MQH__
#property strict

// ==================== ПАНЕЛЬ UI ====================
// Полная торговая панель с блоком агентов и новостей
// Обновление: раз в бар (P&L — каждый тик)

// Глобальные переменные для блока агентов (заполняются в EA)
string g_uiAgentNames[MAX_AGENTS];
int    g_uiAgentScores[MAX_AGENTS];
int    g_uiAgentCount = 0;
bool   g_uiDecShouldTrade = false;
int    g_uiDecDirection = 0;
int    g_uiDecRiskMultiple = 2;
double g_uiDecWeightedScore = 0;
string g_uiSetupText = "";
bool   g_uiSetupActive = false;
string g_uiPivotZoneText = "";

// Глобальные для блока новостей
string g_uiNewsTitle[MAX_NEWS_DISPLAY];
int    g_uiNewsMinutes[MAX_NEWS_DISPLAY];
int    g_uiNewsImpact[MAX_NEWS_DISPLAY];
int    g_uiNewsCount = 0;

// Панель параметры
int    g_panelX = 10;
int    g_panelY = 30;
int    g_panelW = 340;
int    g_panelH = 1700;
double g_scaleFactor = 1.0;

//+------------------------------------------------------------------+
//| Получить коэффициент масштаба                                      |
//+------------------------------------------------------------------+
double GetScaleFactor()
{
   switch(PanelScale)
   {
      case SCALE_80:  return 0.8;
      case SCALE_90:  return 0.9;
      case SCALE_100: return 1.0;
      case SCALE_110: return 1.1;
      case SCALE_120: return 1.2;
   }
   return 1.0;
}

//+------------------------------------------------------------------+
//| Масштабировать значение                                            |
//+------------------------------------------------------------------+
int S(int value) { return (int)(value * g_scaleFactor); }

//+------------------------------------------------------------------+
//| Создать панель                                                     |
//+------------------------------------------------------------------+
void PP_UICreate()
{
   g_scaleFactor = GetScaleFactor();
   g_panelW = S(340);

   int y = g_panelY;

   // Фон панели
   PP_UICreateRect(PANEL_PREFIX + "bg", g_panelX, g_panelY, g_panelW, S(g_panelH),
                    g_scheme.panelBackground, g_scheme.panelBorder);

   // === ЗАГОЛОВОК ===
   y += S(5);
   string tfStr = EnumToString(_Period);
   StringReplace(tfStr, "PERIOD_", "");
   PP_UICreateLabel(PANEL_PREFIX + "title",
      CleanSymbol() + "  " + tfStr + "     Claude_v600",
      g_panelX + S(10), y, g_scheme.textHighlight, S(10));

   // === БАЛАНС ===
   y += S(22);
   PP_UICreateLabel(PANEL_PREFIX + "balance", "Balance: --- Equity: ---",
      g_panelX + S(10), y, g_scheme.textPrimary, S(9));

   y += S(16);
   PP_UICreateLabel(PANEL_PREFIX + "margin", "Leverage: --- Margin: ---",
      g_panelX + S(10), y, g_scheme.textSecondary, S(8));

   y += S(16);
   PP_UICreateLabel(PANEL_PREFIX + "freemargin", "Free margin: --- Level: ---",
      g_panelX + S(10), y, g_scheme.textSecondary, S(8));

   // Разделитель
   y += S(20);
   PP_UICreateLine(PANEL_PREFIX + "sep1", g_panelX + S(5), y, g_panelW - S(10));

   // === ВРЕМЯ ===
   y += S(5);
   PP_UICreateLabel(PANEL_PREFIX + "time1", "Server: --:-- | Local: --:--",
      g_panelX + S(10), y, g_scheme.textPrimary, S(8));

   y += S(14);
   PP_UICreateLabel(PANEL_PREFIX + "time2", "London: --:-- | Chicago: --:-- | Tokyo: --:--",
      g_panelX + S(10), y, g_scheme.textSecondary, S(7));

   // Разделитель
   y += S(18);
   PP_UICreateLine(PANEL_PREFIX + "sep2", g_panelX + S(5), y, g_panelW - S(10));

   // === ЛОТЫ И P&L ===
   y += S(5);
   PP_UICreateLabel(PANEL_PREFIX + "lots", "Allowed lot: ---",
      g_panelX + S(10), y, g_scheme.textPrimary, S(9));

   y += S(16);
   PP_UICreateLabel(PANEL_PREFIX + "pnl", "Long: $0.00  Short: $0.00",
      g_panelX + S(10), y, g_scheme.textSecondary, S(8));

   // Разделитель
   y += S(20);
   PP_UICreateLine(PANEL_PREFIX + "sep3", g_panelX + S(5), y, g_panelW - S(10));

   // === КНОПКИ ТОРГОВЛИ 2R-7R ===
   y += S(5);
   string rLabels[] = {"2R","3R","4R","5R","6R","7R"};

   for(int r = 0; r < 6; r++)
   {
      int row = r / 2;
      int col = r % 2;

      // Long кнопки (зелёные)
      int bx = g_panelX + S(10) + col * S(55);
      int by = y + row * S(26);
      PP_UICreateButton(PANEL_PREFIX + "btnL" + rLabels[r],
         rLabels[r], bx, by, S(50), S(22),
         g_scheme.btnLongBg, g_scheme.btnLongText);

      // Short кнопки (фиолетовые)
      bx = g_panelX + S(180) + col * S(55);
      PP_UICreateButton(PANEL_PREFIX + "btnS" + rLabels[r],
         rLabels[r], bx, by, S(50), S(22),
         g_scheme.btnShortBg, g_scheme.btnShortText);
   }

   y += S(82);

   // === КНОПКИ BE ===
   PP_UICreateLine(PANEL_PREFIX + "sep4", g_panelX + S(5), y, g_panelW - S(10));
   y += S(5);

   for(int r = 0; r < 6; r++)
   {
      int row = r / 2;
      int col = r % 2;

      int bx = g_panelX + S(10) + col * S(55);
      int by = y + row * S(26);
      PP_UICreateButton(PANEL_PREFIX + "btnBEL" + rLabels[r],
         "BE" + rLabels[r], bx, by, S(50), S(22),
         g_scheme.panelBorder, g_scheme.btnLongText);

      bx = g_panelX + S(180) + col * S(55);
      PP_UICreateButton(PANEL_PREFIX + "btnBES" + rLabels[r],
         "BE" + rLabels[r], bx, by, S(50), S(22),
         g_scheme.panelBorder, g_scheme.btnShortText);
   }

   y += S(82);

   // === МЕТРИКИ ===
   PP_UICreateLine(PANEL_PREFIX + "sep5", g_panelX + S(5), y, g_panelW - S(10));
   y += S(5);
   PP_UICreateLabel(PANEL_PREFIX + "metrics", "Metrics Long/Short",
      g_panelX + S(10), y, g_scheme.textPrimary, S(8));

   y += S(16);
   for(int r = 0; r < 6; r++)
   {
      PP_UICreateLabel(PANEL_PREFIX + "met" + rLabels[r],
         rLabels[r] + ": $0.00 | $0.00",
         g_panelX + S(10), y + r * S(14), g_scheme.textSecondary, S(7));
   }

   y += S(90);

   // === КНОПКИ CLOSE ===
   PP_UICreateLine(PANEL_PREFIX + "sep6", g_panelX + S(5), y, g_panelW - S(10));
   y += S(5);

   PP_UICreateButton(PANEL_PREFIX + "btnCloseL", "Close ALL Long",
      g_panelX + S(10), y, S(150), S(24), g_scheme.btnCloseBg, g_scheme.btnCloseText);
   PP_UICreateButton(PANEL_PREFIX + "btnCloseS", "Close ALL Short",
      g_panelX + S(170), y, S(150), S(24), g_scheme.btnCloseBg, g_scheme.btnCloseText);

   y += S(30);
   PP_UICreateButton(PANEL_PREFIX + "btnCloseAll", "Close ALL positions",
      g_panelX + S(10), y, S(310), S(26), g_scheme.btnCloseBg, g_scheme.btnCloseText);

   y += S(35);

   // === БЛОК АГЕНТОВ ===
   if(ShowAgentPanel)
   {
      PP_UICreateLine(PANEL_PREFIX + "sep7", g_panelX + S(5), y, g_panelW - S(10));
      y += S(5);

      PP_UICreateLabel(PANEL_PREFIX + "agtHeader", "-- Agent System ---------- Score --",
         g_panelX + S(10), y, g_scheme.textHighlight, S(8));
      y += S(16);

      // 10 строк агентов
      for(int i = 0; i < MAX_AGENTS; i++)
      {
         string pfx = PANEL_PREFIX + "agt" + IntegerToString(i);

         // Имя агента
         PP_UICreateLabel(pfx + "_name", "Agent " + IntegerToString(i),
            g_panelX + S(10), y + i * S(18), g_scheme.agentTextName, S(8));

         // Полоска (фон)
         PP_UICreateRect(pfx + "_barbg",
            g_panelX + S(90), y + i * S(18), S(150), S(12),
            g_scheme.agentBarBg, g_scheme.agentBorder);

         // Полоска (значение)
         PP_UICreateRect(pfx + "_bar",
            g_panelX + S(90), y + i * S(18), S(1), S(12),
            g_scheme.agentBarPositive, g_scheme.agentBarPositive);

         // Score число
         PP_UICreateLabel(pfx + "_score", "0",
            g_panelX + S(255), y + i * S(18), g_scheme.agentTextScore, S(8));
      }

      y += MAX_AGENTS * S(18) + S(5);

      // Decision строка
      PP_UICreateLabel(PANEL_PREFIX + "decision", "Decision: ---",
         g_panelX + S(10), y, g_scheme.textHighlight, S(9));
      y += S(16);

      // Setup строка
      PP_UICreateLabel(PANEL_PREFIX + "setup", "Setup: ---",
         g_panelX + S(10), y, g_scheme.textPrimary, S(8));
      y += S(16);

      // Pivot Zone строка
      if(ShowPivotZoneOnPanel)
      {
         PP_UICreateLabel(PANEL_PREFIX + "pivotzone", "Pivot Zone: ---",
            g_panelX + S(10), y, g_scheme.pivotLine, S(8));
         y += S(16);
      }
   }

   // === БЛОК НОВОСТЕЙ ===
   if(ShowNewsOnPanel)
   {
      y += S(5);
      PP_UICreateLine(PANEL_PREFIX + "sep8", g_panelX + S(5), y, g_panelW - S(10));
      y += S(5);

      PP_UICreateLabel(PANEL_PREFIX + "newsHeader", "-- News Calendar --",
         g_panelX + S(10), y, g_scheme.textHighlight, S(8));
      y += S(16);

      for(int i = 0; i < MAX_NEWS_DISPLAY; i++)
      {
         PP_UICreateLabel(PANEL_PREFIX + "news" + IntegerToString(i), "",
            g_panelX + S(10), y + i * S(16), g_scheme.textSecondary, S(7));
      }

      y += MAX_NEWS_DISPLAY * S(16) + S(5);

      PP_UICreateLabel(PANEL_PREFIX + "newsStatus", "",
         g_panelX + S(10), y, g_scheme.textPrimary, S(8));
   }

   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Уничтожить панель                                                  |
//+------------------------------------------------------------------+
void PP_UIDestroy()
{
   int total = ObjectsTotal(0);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, PANEL_PREFIX) == 0)
         ObjectDelete(0, name);
   }
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Обновить цены и P&L (каждый тик)                                   |
//+------------------------------------------------------------------+
void PP_UIUpdatePrices()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   double margin  = AccountInfoDouble(ACCOUNT_MARGIN);
   double freeM   = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   long   leverage = AccountInfoInteger(ACCOUNT_LEVERAGE);

   PP_UISetText(PANEL_PREFIX + "balance",
      "Balance: " + DoubleToString(balance, 2) + "$  Equity: " +
      DoubleToString(equity, 2) + "$");

   PP_UISetText(PANEL_PREFIX + "margin",
      "Leverage: 1:" + IntegerToString(leverage) +
      "  Margin: " + DoubleToString(margin, 2) + "$");

   PP_UISetText(PANEL_PREFIX + "freemargin",
      "Free margin: " + DoubleToString(freeM, 2) + "$" +
      "  Level: " + ((margin > 0) ? DoubleToString(equity / margin * 100, 0) : "---") + "%");

   // P&L по позициям
   double longPnL = 0, shortPnL = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) != _Symbol) continue;
      double pnl = PositionGetDouble(POSITION_PROFIT);
      long type = PositionGetInteger(POSITION_TYPE);
      if(type == POSITION_TYPE_BUY)
         longPnL += pnl;
      else
         shortPnL += pnl;
   }

   PP_UISetText(PANEL_PREFIX + "pnl",
      "Long: " + ((longPnL >= 0) ? "+" : "") + DoubleToString(longPnL, 2) +
      "$  Short: " + ((shortPnL >= 0) ? "+" : "") + DoubleToString(shortPnL, 2) + "$");

   // Allowed lot
   double riskAmount = balance * TotalRiskPct / 100.0;
   double slPips = SL_Pips4 * _Point;
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double lotCalc = 0;
   if(slPips > 0 && tickValue > 0 && tickSize > 0)
      lotCalc = riskAmount / (slPips / tickSize * tickValue);

   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lotCalc = MathFloor(lotCalc / lotStep) * lotStep;
   lotCalc = MathMax(minLot, MathMin(maxLot, lotCalc));

   PP_UISetText(PANEL_PREFIX + "lots",
      "Allowed lot: " + DoubleToString(lotCalc, 2));

   // Время
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);

   int gmtHour = (dt.hour - BrokerGMTOffsetHours + 24) % 24;
   int londonHour = gmtHour;
   int chicagoHour = (gmtHour - 6 + 24) % 24;
   int tokyoHour = (gmtHour + 9) % 24;

   PP_UISetText(PANEL_PREFIX + "time1",
      "Server: " + StringFormat("%02d:%02d", dt.hour, dt.min) +
      "  Local: " + TimeToString(TimeLocal(), TIME_MINUTES));

   PP_UISetText(PANEL_PREFIX + "time2",
      "London: " + StringFormat("%02d:%02d", londonHour, dt.min) +
      " | Chicago: " + StringFormat("%02d:%02d", chicagoHour, dt.min) +
      " | Tokyo: " + StringFormat("%02d:%02d", tokyoHour, dt.min));
}

//+------------------------------------------------------------------+
//| Обновить блок агентов (раз в бар)                                  |
//+------------------------------------------------------------------+
void PP_UIUpdateAgentBlock()
{
   if(!ShowAgentPanel) return;

   for(int i = 0; i < MAX_AGENTS; i++)
   {
      string pfx = PANEL_PREFIX + "agt" + IntegerToString(i);

      if(i < g_uiAgentCount)
      {
         // Имя
         PP_UISetText(pfx + "_name", g_uiAgentNames[i]);

         // Score
         string scoreStr = (g_uiAgentScores[i] >= 0 ? "+" : "") +
                            IntegerToString(g_uiAgentScores[i]);
         PP_UISetText(pfx + "_score", scoreStr);

         // Полоска — ширина пропорциональна score
         int barWidth = (int)(MathAbs(g_uiAgentScores[i]) / 100.0 * S(150));
         barWidth = MathMax(1, MathMin(S(150), barWidth));

         ObjectSetInteger(0, pfx + "_bar", OBJPROP_XSIZE, barWidth);

         color barClr;
         if(g_uiAgentScores[i] > 10)
            barClr = g_scheme.agentBarPositive;
         else if(g_uiAgentScores[i] < -10)
            barClr = g_scheme.agentBarNegative;
         else
            barClr = g_scheme.agentBarNeutral;

         ObjectSetInteger(0, pfx + "_bar", OBJPROP_BGCOLOR, barClr);

         // Цвет score
         ObjectSetInteger(0, pfx + "_score", OBJPROP_COLOR,
            (g_uiAgentScores[i] > 0) ? g_scheme.agentDecisionBuy :
            (g_uiAgentScores[i] < 0) ? g_scheme.agentDecisionSell :
            g_scheme.agentDecisionNone);
      }
      else
      {
         PP_UISetText(pfx + "_name", "");
         PP_UISetText(pfx + "_score", "");
         ObjectSetInteger(0, pfx + "_bar", OBJPROP_XSIZE, 0);
      }
   }

   // Decision
   string decText;
   if(g_uiDecShouldTrade)
   {
      string dir = (g_uiDecDirection > 0) ? "^ BUY" : "v SELL";
      color decClr = (g_uiDecDirection > 0) ? g_scheme.agentDecisionBuy : g_scheme.agentDecisionSell;
      decText = "Decision: " + dir + " " + IntegerToString(g_uiDecRiskMultiple) + "R [" +
                DoubleToString(g_uiDecWeightedScore, 0) + "]";
      ObjectSetInteger(0, PANEL_PREFIX + "decision", OBJPROP_COLOR, decClr);
   }
   else
   {
      decText = "Decision: No Trade";
      ObjectSetInteger(0, PANEL_PREFIX + "decision", OBJPROP_COLOR, g_scheme.agentDecisionNone);
   }
   PP_UISetText(PANEL_PREFIX + "decision", decText);

   // Setup
   PP_UISetText(PANEL_PREFIX + "setup", "Setup: " + g_uiSetupText);

   // Pivot Zone
   if(ShowPivotZoneOnPanel)
      PP_UISetText(PANEL_PREFIX + "pivotzone", g_uiPivotZoneText);
}

//+------------------------------------------------------------------+
//| Обновить блок новостей                                             |
//+------------------------------------------------------------------+
void PP_UIUpdateNewsBlock()
{
   if(!ShowNewsOnPanel) return;

   for(int i = 0; i < MAX_NEWS_DISPLAY; i++)
   {
      string name = PANEL_PREFIX + "news" + IntegerToString(i);

      if(i < g_uiNewsCount)
      {
         string minStr;
         if(g_uiNewsMinutes[i] < 0)
            minStr = IntegerToString(-g_uiNewsMinutes[i]) + "m ago";
         else if(g_uiNewsMinutes[i] < 60)
            minStr = IntegerToString(g_uiNewsMinutes[i]) + "m";
         else
            minStr = IntegerToString(g_uiNewsMinutes[i] / 60) + "h";

         string impIcon;
         color clr;
         switch(g_uiNewsImpact[i])
         {
            case 3:  impIcon = "[H]"; clr = g_scheme.newsHigh;   break;
            case 2:  impIcon = "[M]"; clr = g_scheme.newsMedium; break;
            default: impIcon = "[L]"; clr = g_scheme.newsLow;    break;
         }

         PP_UISetText(name, minStr + " | " + impIcon + " " + g_uiNewsTitle[i]);
         ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      }
      else
      {
         PP_UISetText(name, "");
      }
   }
}

//+------------------------------------------------------------------+
//| Обработка нажатий кнопок                                           |
//+------------------------------------------------------------------+
void PP_UIHandleClick(string objName)
{
   // Сбросить состояние кнопки
   ObjectSetInteger(0, objName, OBJPROP_STATE, false);

   // Long кнопки 2R-7R
   if(StringFind(objName, PANEL_PREFIX + "btnL") == 0)
   {
      string rStr = StringSubstr(objName, StringLen(PANEL_PREFIX + "btnL"));
      StringReplace(rStr, "R", "");
      int rMult = (int)StringToInteger(rStr);
      PP_UIExecuteTrade(+1, rMult);
   }
   // Short кнопки 2R-7R
   else if(StringFind(objName, PANEL_PREFIX + "btnS") == 0)
   {
      string rStr = StringSubstr(objName, StringLen(PANEL_PREFIX + "btnS"));
      StringReplace(rStr, "R", "");
      int rMult = (int)StringToInteger(rStr);
      PP_UIExecuteTrade(-1, rMult);
   }
   // BE кнопки
   else if(StringFind(objName, PANEL_PREFIX + "btnBE") == 0)
   {
      bool isLong = (StringFind(objName, "BEL") >= 0);
      string rStr = StringSubstr(objName, StringLen(PANEL_PREFIX + "btnBEL"));
      if(!isLong) rStr = StringSubstr(objName, StringLen(PANEL_PREFIX + "btnBES"));
      StringReplace(rStr, "R", "");
      int rMult = (int)StringToInteger(rStr);
      PP_UIMoveToBreakeven(isLong ? POSITION_TYPE_BUY : POSITION_TYPE_SELL);
   }
   // Close кнопки
   else if(objName == PANEL_PREFIX + "btnCloseL")
      PP_UICloseByType(POSITION_TYPE_BUY);
   else if(objName == PANEL_PREFIX + "btnCloseS")
      PP_UICloseByType(POSITION_TYPE_SELL);
   else if(objName == PANEL_PREFIX + "btnCloseAll")
      PP_UICloseAll();
}

//+------------------------------------------------------------------+
//| Исполнить торговлю из кнопки                                       |
//+------------------------------------------------------------------+
void PP_UIExecuteTrade(int direction, int rMultiple)
{
   // Расчёт лота
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * TotalRiskPct / 100.0;
   double slPips = SL_Pips4 * _Point;
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   if(slPips <= 0 || tickValue <= 0 || tickSize <= 0) return;

   double lotCalc = riskAmount / (slPips / tickSize * tickValue);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lotCalc = MathFloor(lotCalc / lotStep) * lotStep;
   lotCalc = MathMax(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN),
                      MathMin(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX), lotCalc));

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   double sl, tp, price;

   if(direction > 0)  // BUY
   {
      price = ask;
      sl = NormalizeDouble(price - slPips, _Digits);
      tp = NormalizeDouble(price + slPips * rMultiple, _Digits);
   }
   else  // SELL
   {
      price = bid;
      sl = NormalizeDouble(price + slPips, _Digits);
      tp = NormalizeDouble(price - slPips * rMultiple, _Digits);
   }

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
}

//+------------------------------------------------------------------+
//| Перенести SL на Breakeven                                          |
//+------------------------------------------------------------------+
void PP_UIMoveToBreakeven(long posType)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) != _Symbol) continue;
      if(PositionGetInteger(POSITION_TYPE) != posType) continue;

      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentSL = PositionGetDouble(POSITION_SL);
      double currentTP = PositionGetDouble(POSITION_TP);
      ulong  ticket = PositionGetInteger(POSITION_TICKET);

      // Перенести SL на точку входа + 1 пункт
      double newSL;
      if(posType == POSITION_TYPE_BUY)
         newSL = openPrice + _Point;
      else
         newSL = openPrice - _Point;

      newSL = NormalizeDouble(newSL, _Digits);

      if(!g_trade.PositionModify(ticket, newSL, currentTP))
         Print("[UI] BE FAILED: ticket=", ticket, " Error=", GetLastError());
      else
         Print("[UI] BE OK: ticket=", ticket, " newSL=", newSL);
   }
}

//+------------------------------------------------------------------+
//| Закрыть позиции по типу                                            |
//+------------------------------------------------------------------+
void PP_UICloseByType(long posType)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) != _Symbol) continue;
      if(PositionGetInteger(POSITION_TYPE) != posType) continue;

      ulong ticket = PositionGetInteger(POSITION_TICKET);
      if(!g_trade.PositionClose(ticket))
         Print("[UI] Close FAILED: ticket=", ticket, " Error=", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Закрыть все позиции                                                |
//+------------------------------------------------------------------+
void PP_UICloseAll()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) != _Symbol) continue;
      ulong ticket = PositionGetInteger(POSITION_TICKET);
      if(!g_trade.PositionClose(ticket))
         Print("[UI] Close ALL FAILED: ticket=", ticket, " Error=", GetLastError());
   }
}

// ==================== ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ====================

void PP_UICreateRect(string name, int x, int y, int w, int h, color bg, color border)
{
   ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, border);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

void PP_UICreateLabel(string name, string text, int x, int y, color clr, int fontSize)
{
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

void PP_UICreateButton(string name, string text, int x, int y, int w, int h,
                        color bg, color txtClr)
{
   ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_COLOR, txtClr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

void PP_UICreateLine(string name, int x, int y, int width)
{
   PP_UICreateRect(name, x, y, width, 1, g_scheme.panelBorder, g_scheme.panelBorder);
}

void PP_UISetText(string name, string text)
{
   ObjectSetString(0, name, OBJPROP_TEXT, text);
}

#endif
