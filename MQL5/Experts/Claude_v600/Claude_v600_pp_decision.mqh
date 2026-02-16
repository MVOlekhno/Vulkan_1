#ifndef __CLAUDE_V600_PP_DECISION_MQH__
#define __CLAUDE_V600_PP_DECISION_MQH__
#property strict

// ==================== СИСТЕМА РЕШЕНИЙ (10 агентов) ====================
// signals[0..9]: 10 агентов
// [4] CtxFilter — множитель, НЕ голосует
// Все остальные — голосуют

//+------------------------------------------------------------------+
//| Рассчитать WeightedScore                                           |
//| КРИТИЧЕСКОЕ: CtxFilter НЕ обнуляет score (базовый = 1.0)          |
//+------------------------------------------------------------------+
double CalcWeightedScore(AgentSignal &signals[], int count, double ctxMult)
{
   double sum = 0;
   for(int i = 0; i < count; i++)
   {
      if(i == 4) continue;  // CtxFilter не голосует, он множитель
      if(!signals[i].enabled) continue;

      sum += signals[i].score * signals[i].confidence * signals[i].weight;
   }
   return sum * ctxMult;  // Множитель НЕ ноль (кроме блокировки)
}

//+------------------------------------------------------------------+
//| Подсчитать количество согласных агентов                             |
//+------------------------------------------------------------------+
void CountAgreement(AgentSignal &signals[], int count,
                     int &longVotes, int &shortVotes, int &agreeCount)
{
   longVotes = 0;
   shortVotes = 0;

   for(int i = 0; i < count; i++)
   {
      if(i == 4) continue;  // CtxFilter не голосует
      if(!signals[i].enabled) continue;

      if(signals[i].score > 10)
         longVotes++;
      else if(signals[i].score < -10)
         shortVotes++;
   }

   agreeCount = MathMax(longVotes, shortVotes);
}

//+------------------------------------------------------------------+
//| Определить Risk Multiple (2R-7R) на основе score                   |
//+------------------------------------------------------------------+
int CalcRiskMultiple(double absScore)
{
   if(absScore >= 500) return 7;
   if(absScore >= 400) return 6;
   if(absScore >= 300) return 5;
   if(absScore >= 200) return 4;
   if(absScore >= 150) return 3;
   return 2;
}

//+------------------------------------------------------------------+
//| Определить грейд сетапа                                            |
//+------------------------------------------------------------------+
string CalcSetupClass(double absScore, int agreeCount)
{
   if(absScore >= 300 && agreeCount >= 5)
      return "A+";
   else if(absScore >= (double)EntryThreshold)
      return "A";
   else
      return "S";
}

//+------------------------------------------------------------------+
//| Принять решение о торговле                                         |
//+------------------------------------------------------------------+
void DEC_MakeDecision(AgentSignal &signals[], int count,
                       MarketContext &ctx, TradeDecision &dec)
{
   ZeroMemory(dec);
   dec.shouldTrade = false;
   dec.direction = 0;
   dec.riskMultiple = 2;
   dec.weightedScore = 0;

   if(!EnableAgentSystem) return;

   // Context multiplier
   double ctxMult = ctx.context_multiplier;

   // WeightedScore
   dec.weightedScore = CalcWeightedScore(signals, count, ctxMult);

   // Подсчёт голосов
   CountAgreement(signals, count, dec.longVotes, dec.shortVotes, dec.agreeCount);

   // Направление
   if(dec.weightedScore > 0)
      dec.direction = +1;
   else if(dec.weightedScore < 0)
      dec.direction = -1;
   else
      dec.direction = 0;

   double absScore = MathAbs(dec.weightedScore);

   // Проверка порогов
   if(absScore >= (double)EntryThreshold && dec.agreeCount >= MinAgentsAgree)
   {
      dec.shouldTrade = true;
      dec.riskMultiple = CalcRiskMultiple(absScore);
      dec.setupClass = CalcSetupClass(absScore, dec.agreeCount);
   }
   else
   {
      dec.shouldTrade = false;
      dec.setupClass = "S";
   }

   // Блокировка при CtxMult = 0
   if(ctxMult == 0.0)
   {
      dec.shouldTrade = false;
      dec.setupClass = "S";
   }
}

//+------------------------------------------------------------------+
//| Получить строку решения для отображения                             |
//+------------------------------------------------------------------+
string DEC_GetDecisionString(TradeDecision &dec)
{
   if(!dec.shouldTrade)
      return "No Trade (S)";

   string dir = (dec.direction > 0) ? "BUY" : "SELL";
   string arrow = (dec.direction > 0) ? "^" : "v";

   return arrow + " " + dir + " " + IntegerToString(dec.riskMultiple) + "R [" +
          DoubleToString(dec.weightedScore, 0) + "] " + dec.setupClass;
}

#endif
