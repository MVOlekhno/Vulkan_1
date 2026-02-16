#ifndef __CLAUDE_V600_PP_NEWS_MQH__
#define __CLAUDE_V600_PP_NEWS_MQH__
#property strict

// ==================== НОВОСТНОЙ КАЛЕНДАРЬ ====================
// Источник: Forex Factory JSON API
// Кэш: ff_news_cache.json
// Обновление: раз в час

#define NEWS_URL        "https://nfs.faireconomy.media/ff_calendar_thisweek.json"
#define NEWS_CACHE      "ff_news_cache.json"
#define NEWS_UPDATE_SEC 3600  // Раз в час

struct NewsEvent
{
   string   title;
   string   country;
   datetime time;
   int      impact;       // 0=Holiday, 1=Low, 2=Medium, 3=High
   string   forecast;
   string   previous;
};

NewsEvent g_newsEvents[];
datetime  g_newsLastUpdate = 0;
int       g_newsCount = 0;

//+------------------------------------------------------------------+
//| Инициализация новостей                                             |
//+------------------------------------------------------------------+
bool News_Init()
{
   if(!EnableNewsCalendar) return true;

   g_newsCount = 0;
   ArrayResize(g_newsEvents, 0);

   return News_Download();
}

//+------------------------------------------------------------------+
//| Деинициализация                                                    |
//+------------------------------------------------------------------+
void News_Deinit()
{
   ArrayFree(g_newsEvents);
   g_newsCount = 0;
}

//+------------------------------------------------------------------+
//| Загрузить новости с FF API                                         |
//+------------------------------------------------------------------+
bool News_Download()
{
   if(!EnableNewsCalendar) return true;

   if(TimeCurrent() - g_newsLastUpdate < NEWS_UPDATE_SEC && g_newsCount > 0)
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
      if(h != INVALID_HANDLE)
      {
         FileWriteString(h, json);
         FileClose(h);
      }

      News_Parse(json);
      g_newsLastUpdate = TimeCurrent();
      Print("[NEWS] Downloaded OK. Events: ", g_newsCount);
      return true;
   }

   Print("[NEWS] HTTP Error: ", res, ". Trying cache...");
   return News_ReadCache();
}

//+------------------------------------------------------------------+
//| Прочитать кэш                                                     |
//+------------------------------------------------------------------+
bool News_ReadCache()
{
   if(!FileIsExist(NEWS_CACHE)) return false;

   int h = FileOpen(NEWS_CACHE, FILE_READ|FILE_TXT|FILE_ANSI);
   if(h == INVALID_HANDLE) return false;

   string json = "";
   while(!FileIsEnding(h))
      json += FileReadString(h);
   FileClose(h);

   if(StringLen(json) < 10) return false;

   News_Parse(json);
   Print("[NEWS] Loaded from cache. Events: ", g_newsCount);
   return true;
}

//+------------------------------------------------------------------+
//| Парсинг JSON (простой парсер)                                      |
//+------------------------------------------------------------------+
void News_Parse(string json)
{
   ArrayResize(g_newsEvents, 0);
   g_newsCount = 0;

   // Получить валюты символа для фильтрации
   string sym = _Symbol;
   string cur1 = StringSubstr(sym, 0, 3);
   string cur2 = StringSubstr(sym, 3, 3);

   int pos = 0;
   int jsonLen = StringLen(json);

   while(pos < jsonLen)
   {
      // Найти начало объекта
      int objStart = StringFind(json, "{", pos);
      if(objStart < 0) break;

      int objEnd = StringFind(json, "}", objStart);
      if(objEnd < 0) break;

      string obj = StringSubstr(json, objStart, objEnd - objStart + 1);
      pos = objEnd + 1;

      // Извлечь поля
      string title = News_ExtractField(obj, "title");
      string country = News_ExtractField(obj, "country");
      string impactStr = News_ExtractField(obj, "impact");
      string dateStr = News_ExtractField(obj, "date");
      string timeStr = News_ExtractField(obj, "time");
      string forecast = News_ExtractField(obj, "forecast");
      string previous = News_ExtractField(obj, "previous");

      if(title == "" || country == "") continue;

      // Фильтр: только валюты символа или High Impact
      int impact = News_ParseImpact(impactStr);
      bool relevant = (country == cur1 || country == cur2 || impact >= 3);
      if(!relevant) continue;

      // Парсить время
      datetime eventTime = News_ParseDateTime(dateStr, timeStr);
      if(eventTime == 0) continue;

      // Добавить
      int idx = g_newsCount;
      g_newsCount++;
      ArrayResize(g_newsEvents, g_newsCount);

      g_newsEvents[idx].title    = title;
      g_newsEvents[idx].country  = country;
      g_newsEvents[idx].time     = eventTime;
      g_newsEvents[idx].impact   = impact;
      g_newsEvents[idx].forecast = forecast;
      g_newsEvents[idx].previous = previous;
   }
}

//+------------------------------------------------------------------+
//| Извлечь значение поля из JSON объекта                               |
//+------------------------------------------------------------------+
string News_ExtractField(string obj, string field)
{
   string search = "\"" + field + "\":\"";
   int start = StringFind(obj, search);
   if(start < 0)
   {
      // Попробовать без кавычек значения
      search = "\"" + field + "\":";
      start = StringFind(obj, search);
      if(start < 0) return "";

      start += StringLen(search);
      // Пропустить пробелы
      while(start < StringLen(obj) && StringGetCharacter(obj, start) == ' ')
         start++;

      if(StringGetCharacter(obj, start) == '"')
      {
         start++;
         int end = StringFind(obj, "\"", start);
         if(end < 0) return "";
         return StringSubstr(obj, start, end - start);
      }
      else
      {
         int end = StringFind(obj, ",", start);
         if(end < 0) end = StringFind(obj, "}", start);
         if(end < 0) return "";
         return StringSubstr(obj, start, end - start);
      }
   }

   start += StringLen(search);
   int end = StringFind(obj, "\"", start);
   if(end < 0) return "";

   return StringSubstr(obj, start, end - start);
}

//+------------------------------------------------------------------+
//| Парсить impact строку                                              |
//+------------------------------------------------------------------+
int News_ParseImpact(string impactStr)
{
   if(impactStr == "High" || impactStr == "high")     return 3;
   if(impactStr == "Medium" || impactStr == "medium") return 2;
   if(impactStr == "Low" || impactStr == "low")       return 1;
   return 0;  // Holiday
}

//+------------------------------------------------------------------+
//| Парсить дату+время в datetime                                      |
//+------------------------------------------------------------------+
datetime News_ParseDateTime(string dateStr, string timeStr)
{
   // FF формат: date="2026-02-16", time="8:30am" или "All Day"
   if(dateStr == "" || timeStr == "" || timeStr == "All Day")
      return 0;

   // Парсить время
   bool isPM = (StringFind(timeStr, "pm") >= 0 || StringFind(timeStr, "PM") >= 0);
   StringReplace(timeStr, "am", "");
   StringReplace(timeStr, "pm", "");
   StringReplace(timeStr, "AM", "");
   StringReplace(timeStr, "PM", "");

   int colonPos = StringFind(timeStr, ":");
   int hour = 0, minute = 0;

   if(colonPos >= 0)
   {
      hour = (int)StringToInteger(StringSubstr(timeStr, 0, colonPos));
      minute = (int)StringToInteger(StringSubstr(timeStr, colonPos + 1));
   }
   else
   {
      hour = (int)StringToInteger(timeStr);
   }

   if(isPM && hour < 12) hour += 12;
   if(!isPM && hour == 12) hour = 0;

   // FF время в EST (UTC-5)
   // Конвертируем в broker time: +5 + BrokerGMTOffsetHours
   hour = (hour + 5 + BrokerGMTOffsetHours) % 24;

   string dtStr = dateStr + " " +
                   StringFormat("%02d", hour) + ":" +
                   StringFormat("%02d", minute);

   return StringToTime(dtStr);
}

//+------------------------------------------------------------------+
//| Минут до ближайшей новости указанного минимального импакта          |
//+------------------------------------------------------------------+
int News_MinutesToNext(int minImpact)
{
   if(!EnableNewsCalendar || g_newsCount == 0) return 99999;

   datetime now = TimeCurrent();
   int closest = 99999;

   for(int i = 0; i < g_newsCount; i++)
   {
      if(g_newsEvents[i].impact < minImpact) continue;

      int diff = (int)(g_newsEvents[i].time - now) / 60;
      if(diff >= -5 && diff < closest)
         closest = diff;
   }

   return closest;
}

//+------------------------------------------------------------------+
//| Получить ближайшие N новостей для панели                            |
//+------------------------------------------------------------------+
int News_GetUpcoming(string &titles[], int &minutes[], int &impacts[], int maxCount)
{
   if(!EnableNewsCalendar || g_newsCount == 0) return 0;

   datetime now = TimeCurrent();
   int count = 0;

   ArrayResize(titles, maxCount);
   ArrayResize(minutes, maxCount);
   ArrayResize(impacts, maxCount);

   // Сортируем по времени (ближайшие первые)
   for(int i = 0; i < g_newsCount && count < maxCount; i++)
   {
      int diff = (int)(g_newsEvents[i].time - now) / 60;
      if(diff >= -10 && diff < 720)  // От -10 мин до +12 часов
      {
         titles[count] = g_newsEvents[i].country + " " + g_newsEvents[i].title;
         minutes[count] = diff;
         impacts[count] = g_newsEvents[i].impact;
         count++;
      }
   }

   return count;
}

//+------------------------------------------------------------------+
//| Обновить контекст новостями                                        |
//+------------------------------------------------------------------+
void News_UpdateContext(MarketContext &ctx)
{
   if(!EnableNewsCalendar)
   {
      ctx.news_minutes_to = 99999;
      ctx.news_impact = 0;
      ctx.news_title = "";
      return;
   }

   ctx.news_minutes_to = News_MinutesToNext(2);  // Medium+

   // Найти ближайшую
   datetime now = TimeCurrent();
   int closestDiff = 99999;
   int closestIdx = -1;

   for(int i = 0; i < g_newsCount; i++)
   {
      int diff = (int)(g_newsEvents[i].time - now) / 60;
      if(diff >= -5 && diff < closestDiff)
      {
         closestDiff = diff;
         closestIdx = i;
      }
   }

   if(closestIdx >= 0)
   {
      ctx.news_impact = g_newsEvents[closestIdx].impact;
      ctx.news_title  = g_newsEvents[closestIdx].country + " " +
                          g_newsEvents[closestIdx].title;
   }
   else
   {
      ctx.news_impact = 0;
      ctx.news_title = "";
   }
}

//+------------------------------------------------------------------+
//| Рисовать вертикальные линии новостей на графике                     |
//+------------------------------------------------------------------+
void News_DrawOnChart()
{
   if(!DrawNewsLines) return;

   // Удалить старые
   int total = ObjectsTotal(0);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, "NEWS_") == 0)
         ObjectDelete(0, name);
   }

   datetime now = TimeCurrent();

   for(int i = 0; i < g_newsCount; i++)
   {
      int diff = (int)(g_newsEvents[i].time - now) / 60;
      if(diff < -60 || diff > 1440) continue;  // ±1 день

      string name = "NEWS_" + IntegerToString(i);
      color clr;

      switch(g_newsEvents[i].impact)
      {
         case 3:  clr = g_scheme.newsHigh;   break;
         case 2:  clr = g_scheme.newsMedium; break;
         default: clr = g_scheme.newsLow;    break;
      }

      ObjectCreate(0, name, OBJ_VLINE, 0, g_newsEvents[i].time, 0);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_STYLE,
         (g_newsEvents[i].impact >= 3) ? STYLE_SOLID : STYLE_DOT);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetString(0, name, OBJPROP_TOOLTIP,
         g_newsEvents[i].country + " | " + g_newsEvents[i].title +
         "\nForecast: " + g_newsEvents[i].forecast +
         " | Previous: " + g_newsEvents[i].previous);
   }
}

#endif
