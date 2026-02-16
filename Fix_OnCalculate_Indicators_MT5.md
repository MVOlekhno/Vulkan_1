# ЗАДАЧА: Исправить ошибки компиляции в 3 индикаторах MT5

## Проблема

Все 3 индикатора в `MQL5/Indicators/` не компилируются. У каждого одинаковые ошибки:

```
⚠ Warning: 'OnCalculate' function declared with wrong type or/and parameters
❌ Error: OnCalculate function not found in custom indicator
```

Ошибка в файлах:
1. `MQL5/Indicators/Claude_v600_VWAP.mq5`
2. `MQL5/Indicators/Claude_v600_AVWAP.mq5`
3. `MQL5/Indicators/Claude_v600_VolumeProfile.mq5`

## Причина ошибки

Неправильная сигнатура функции `OnCalculate()`. В параметре `volume` указан тип `double`, но **MQL5 требует `long`**.

### ❌ НЕПРАВИЛЬНО (текущий код):
```mql5
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const double &volume[],       // ← ОШИБКА: double
                const int &spread[])
```

### ✅ ПРАВИЛЬНО (как должно быть):
```mql5
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],         // ← ИСПРАВЛЕНО: long
                const int &spread[])
```

## Что нужно сделать

1. Открой каждый из 3 файлов индикаторов в `MQL5/Indicators/`
2. Найди объявление функции `OnCalculate`
3. Замени `const double &volume[]` на `const long &volume[]`
4. **ВАЖНО**: Проверь, нет ли внутри тела функции обращений к `volume[]` с приведением к double. Если есть — убедись что приведение типа корректно (например `(double)volume[i]` при математических операциях). Массив `volume` теперь `long[]`, поэтому:
   - Если `volume[i]` используется в арифметике с `double` — добавь явное приведение `(double)volume[i]`
   - Если `volume[i]` присваивается `long` переменной — оставь как есть
5. Сделай коммит с сообщением: 

```
fix: исправлена сигнатура OnCalculate() во всех 3 индикаторах

Проблема: параметр volume[] был объявлен как double вместо long.
MQL5 требует строго: const long &volume[]
Это вызывало ошибку компиляции:
- Warning: 'OnCalculate' function declared with wrong type or/and parameters  
- Error: OnCalculate function not found in custom indicator

Исправлено в:
- Claude_v600_VWAP.mq5
- Claude_v600_AVWAP.mq5
- Claude_v600_VolumeProfile.mq5
```

## Справка из документации MQL5

Полная правильная сигнатура OnCalculate (вторая форма, с отдельными массивами):

```mql5
int OnCalculate(const int rates_total,        // размер массивов
                const int prev_calculated,     // обработано на прошлом вызове
                const datetime &time[],        // время
                const double &open[],          // цены открытия
                const double &high[],          // максимумы
                const double &low[],           // минимумы
                const double &close[],         // цены закрытия
                const long &tick_volume[],     // тиковый объём
                const long &volume[],          // реальный объём (LONG!)
                const int &spread[])           // спред
```

**Все типы должны совпадать ТОЧНО — MQL5 не допускает отклонений в сигнатуре OnCalculate.**
