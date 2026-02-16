#ifndef __CLAUDE_V600_PP_LEARNING_MQH__
#define __CLAUDE_V600_PP_LEARNING_MQH__
#property strict

// ==================== Q-LEARNING ====================
// Обучение с подкреплением для адаптации весов агентов
// По умолчанию ВЫКЛЮЧЕН

#define Q_STATES     30    // Количество состояний
#define Q_ACTIONS    3     // 0=HOLD, 1=BUY, 2=SELL
#define Q_GAMMA      0.95  // Discount factor

double g_qTable[Q_STATES][Q_ACTIONS];
int    g_qLastState  = 0;
int    g_qLastAction = 0;
bool   g_qInitialized = false;

//+------------------------------------------------------------------+
//| Инициализация Q-Learning                                           |
//+------------------------------------------------------------------+
bool QL_Init()
{
   if(!EnableQLearning) return true;

   // Обнулить Q-table
   for(int s = 0; s < Q_STATES; s++)
      for(int a = 0; a < Q_ACTIONS; a++)
         g_qTable[s][a] = 0;

   // Загрузить если файл существует
   if(FileIsExist(QTableFile))
   {
      QL_Load();
   }

   g_qInitialized = true;
   Print("[QL] Q-Learning initialized. States=", Q_STATES, " Actions=", Q_ACTIONS);
   return true;
}

//+------------------------------------------------------------------+
//| Деинициализация                                                    |
//+------------------------------------------------------------------+
void QL_Deinit()
{
   if(!EnableQLearning || !g_qInitialized) return;

   QL_Save();
   Print("[QL] Q-table saved.");
}

//+------------------------------------------------------------------+
//| Кодировать состояние рынка в индекс 0..Q_STATES-1                  |
//+------------------------------------------------------------------+
int QL_EncodeState(MarketContext &ctx)
{
   // Упрощённое кодирование:
   // regime (0-5) * 5 + session_bucket (0-4)
   int regimeBucket = ctx.regime;  // 0-5

   int sessionBucket;
   if(ctx.session == SESSION_NY_LONDON)
      sessionBucket = 4;
   else if(ctx.session == SESSION_LONDON || ctx.session == SESSION_NY)
      sessionBucket = 3;
   else if(ctx.session == SESSION_TOKYO)
      sessionBucket = 2;
   else if(ctx.session == SESSION_SYDNEY || ctx.session == SESSION_SYDNEY_TOKYO)
      sessionBucket = 1;
   else
      sessionBucket = 0;

   int state = regimeBucket * 5 + sessionBucket;
   return MathMax(0, MathMin(Q_STATES - 1, state));
}

//+------------------------------------------------------------------+
//| Выбрать действие (epsilon-greedy)                                  |
//+------------------------------------------------------------------+
int QL_ChooseAction(int state)
{
   // Epsilon-greedy
   if(MathRand() / 32768.0 < ExplorationRate)
   {
      return MathRand() % Q_ACTIONS;  // Случайное действие
   }

   // Greedy: выбрать действие с максимальным Q
   int bestAction = 0;
   double bestQ = g_qTable[state][0];

   for(int a = 1; a < Q_ACTIONS; a++)
   {
      if(g_qTable[state][a] > bestQ)
      {
         bestQ = g_qTable[state][a];
         bestAction = a;
      }
   }

   return bestAction;
}

//+------------------------------------------------------------------+
//| Обновить Q-table                                                   |
//+------------------------------------------------------------------+
void QL_Update(int prevState, int action, double reward, int newState)
{
   if(!EnableQLearning || !g_qInitialized) return;

   // Максимальный Q для нового состояния
   double maxQNext = g_qTable[newState][0];
   for(int a = 1; a < Q_ACTIONS; a++)
   {
      if(g_qTable[newState][a] > maxQNext)
         maxQNext = g_qTable[newState][a];
   }

   // Q-Learning update rule
   double oldQ = g_qTable[prevState][action];
   g_qTable[prevState][action] = oldQ + LearningRate *
      (reward + Q_GAMMA * maxQNext - oldQ);
}

//+------------------------------------------------------------------+
//| Получить reward из результата сделки                                |
//+------------------------------------------------------------------+
double QL_CalcReward(double pnlR)
{
   // Reward = PnL в R-единицах
   // Положительный PnL = положительный reward
   // Штраф за отсутствие торговли в хороших условиях = 0
   return pnlR;
}

//+------------------------------------------------------------------+
//| Обработать бар (вызывается каждый бар)                              |
//+------------------------------------------------------------------+
void QL_OnBar(MarketContext &ctx, TradeDecision &dec)
{
   if(!EnableQLearning || !g_qInitialized) return;

   int state = QL_EncodeState(ctx);
   int action = QL_ChooseAction(state);

   // Запомнить для следующего обновления
   g_qLastState = state;
   g_qLastAction = action;
}

//+------------------------------------------------------------------+
//| Обработать закрытие сделки                                         |
//+------------------------------------------------------------------+
void QL_OnTradeClose(MarketContext &ctx, double pnlR)
{
   if(!EnableQLearning || !g_qInitialized) return;

   int newState = QL_EncodeState(ctx);
   double reward = QL_CalcReward(pnlR);

   QL_Update(g_qLastState, g_qLastAction, reward, newState);
}

//+------------------------------------------------------------------+
//| Сохранить Q-table в файл                                           |
//+------------------------------------------------------------------+
void QL_Save()
{
   int h = FileOpen(QTableFile, FILE_WRITE|FILE_CSV, ',');
   if(h == INVALID_HANDLE) return;

   for(int s = 0; s < Q_STATES; s++)
   {
      FileWrite(h,
         IntegerToString(s),
         DoubleToString(g_qTable[s][0], 6),
         DoubleToString(g_qTable[s][1], 6),
         DoubleToString(g_qTable[s][2], 6)
      );
   }

   FileClose(h);
}

//+------------------------------------------------------------------+
//| Загрузить Q-table из файла                                         |
//+------------------------------------------------------------------+
void QL_Load()
{
   int h = FileOpen(QTableFile, FILE_READ|FILE_CSV, ',');
   if(h == INVALID_HANDLE) return;

   int row = 0;
   while(!FileIsEnding(h) && row < Q_STATES)
   {
      string sIdx = FileReadString(h);
      g_qTable[row][0] = StringToDouble(FileReadString(h));
      g_qTable[row][1] = StringToDouble(FileReadString(h));
      g_qTable[row][2] = StringToDouble(FileReadString(h));
      row++;
   }

   FileClose(h);
   Print("[QL] Loaded Q-table: ", row, " states");
}

#endif
