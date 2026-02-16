# CLAUDE.md — AI Assistant Guide for Claude_v600 Project

## Project Overview

This repository contains the **technical specification** (TZ — "Техническое Задание") for **Claude_v600**, a multi-agent trading Expert Advisor (EA) for MetaTrader 5 (MQL5). It is a full port of Claude_v500 (MT4/MQL4) with significant enhancements.

**Primary language of the specification:** Russian.

### What Claude_v600 Is

A prop-style multi-agent trading system where 10 agents analyze the market, vote, and make trade entry decisions. Key components:

- **10 Agents** analyze market conditions (VWAP, Supply/Demand, Structure, Momentum, Context, WPR, BetterVolume, TD_REI, PVSRA, Weekly Fib Pivot)
- **Professional journal** logs every bar for post-analysis
- **Setup detection** recognizes 6 setup types from Playbook v4
- **News calendar** integrates Forex Factory data via WebRequest
- **TWAP execution** for sliced order entry
- **Q-Learning** module for adaptive behavior

### Trading Methodology

FVG_CAD5 Playbook v4 (Prop-style):
- Pipeline: Context -> Trigger -> Confirmation -> Risk
- Grading: S (skip) / A (0.25-0.75R) / A+ (0.75-1.5R)
- Partial takes: 1R / 3R / 5R, move to BE after 1R
- Daily stop: -3R, trade limit: 3-5/day

---

## Repository Structure

```
Vulkan_1/
  TZ_Claude_v600_MT5_v2.md   # Full technical specification (v2)
  CLAUDE.md                   # This file
```

The specification describes **21 files** to be implemented:

### Target File Structure (MQL5/Experts/Claude_v600/)

| # | File | Purpose |
|---|------|---------|
| 1 | `Claude_v600_pp_inputs.mqh` | Input parameters (18 sections, enums) |
| 2 | `Claude_v600_pp_diag.mqh` | Diagnostics module |
| 3 | `Claude_v600_pp_color_schemes.mqh` | 5 color schemes, 53+ color fields |
| 4 | `Claude_v600_pp_context.mqh` | Market context analysis (MarketContext struct) |
| 5 | `Claude_v600_pp_sessions.mqh` | Session levels (Asia, London, NY, etc.) |
| 6 | `Claude_v600_pp_market_levels.mqh` | ADR, round levels |
| 7 | `Claude_v600_pp_ui_panel.mqh` | UI panel + agent display block |
| 8 | `Claude_v600_pp_agents.mqh` | Agents 1-5 (VWAP, SD, Structure, Momentum, Context) |
| 9 | `Claude_v600_pp_agents_ext.mqh` | Agents 6-9 (WPR, BetterVolume, TD_REI, PVSRA) |
| 10 | `Claude_v600_pp_fib_pivot.mqh` | Agent 10: Weekly Fib Pivot (NEW in v2) |
| 11 | `Claude_v600_pp_decision.mqh` | Decision system (10 agents) |
| 12 | `Claude_v600_pp_learning.mqh` | Q-Learning |
| 13 | `Claude_v600_pp_twap.mqh` | TWAP execution |
| 14 | `Claude_v600_pp_setups.mqh` | 6 setup types from Playbook v4 |
| 15 | `Claude_v600_pp_journal.mqh` | Professional journal (FIXED in v2) |
| 16 | `Claude_v600_pp_news.mqh` | News calendar (NEW) |
| 17 | `Claude_v600_Tester_PropPanel.mq5` | Main EA file |
| 18 | `Claude_v600_VWAP.mq5` | VWAP indicator (-> MQL5/Indicators/) |
| 19 | `Claude_v600_AVWAP.mq5` | Anchored VWAP indicator |
| 20 | `Claude_v600_VolumeProfile.mq5` | Volume Profile indicator |

### Implementation Order (Dependencies)

```
1. pp_inputs.mqh            (no dependencies)
2. pp_diag.mqh              (inputs)
3. pp_color_schemes.mqh     (inputs)
4. pp_context.mqh           (inputs)
5. pp_sessions.mqh          (inputs)
6. pp_market_levels.mqh     (inputs, sessions)
7. pp_agents.mqh            (inputs, context)
8. pp_agents_ext.mqh        (inputs, context, agents)
9. pp_fib_pivot.mqh         (inputs, context, sessions, color_schemes)
10. pp_decision.mqh         (agents, agents_ext, fib_pivot, context)
11. pp_setups.mqh           (agents, context, decision, fib_pivot)
12. pp_journal.mqh          (agents, context, decision, fib_pivot)
13. pp_news.mqh             (inputs)
14. pp_learning.mqh         (agents, decision)
15. pp_twap.mqh             (decision)
16. pp_ui_panel.mqh         (color_schemes, inputs)
17. Main EA .mq5            (ALL modules)
18-20. Indicators .mq5      (standalone)
```

---

## Critical Development Rules

### 1. Native MQL5 — NOT MQL4 Transliteration

Use MQL5 native constructs:
- `CTrade`, `CPositionInfo`, `CSymbolInfo` — from `<Trade/*.mqh>`
- `OnCalculate()` for indicators (NOT `start()`)
- Indicator handles + `CopyBuffer()` (NOT direct `iMA(...)` return values)
- `EventSetTimer()` / `OnTimer()` for periodic tasks
- `PositionsTotal()` for open positions (NOT `OrdersTotal()`)

### 2. Indicator Handle Pattern

```mql5
// Create in OnInit():
int g_hATR = iATR(_Symbol, _Period, ATR_Period);

// Read in calculations:
double buf[];
CopyBuffer(g_hATR, 0, 0, 1, buf);
double atr = buf[0];

// Release in OnDeinit():
IndicatorRelease(g_hATR);
```

Always call `ArraySetAsSeries(buf, true)` for price arrays.

### 3. Built-in Formulas — No iCustom

All agent formulas (BetterVolume, PVSRA, TD_REI, Fib Pivot) are **embedded** — do NOT use `iCustom()`.

### 4. Color Scheme System

All colors go through `g_scheme` (the global ColorScheme struct). **Never hardcode colors.** There are 5 schemes: Deep Ocean, Warm Sand, Night Violet, Cream Classic, Espresso.

### 5. Context Filter Must NOT Zero-Out Scores

```
CtxFilter BASE = 1.0 (NOT zero!)
Kill Zone = 1.3, Outside Kill Zone = 0.7
Zero ONLY: Friday > 15:00 UTC, Spread > 3x ATR, or blocked by high-impact news
```

This was a critical bug in the MT4 version where `CtxFilter = 0` caused `WeightedScore = 0`.

### 6. Panel Updates

- Full panel update: **once per bar** (NOT every tick)
- Exception: P&L display updates every tick
- Agent data passed via **global variables** (not struct parameters between .mqh files)

### 7. Journal Format

- Delimiter: semicolon `;`
- Version marker: `JournalV2`
- Clean broker suffixes from symbol names (e.g., `GBPUSDb` -> `GBPUSD`)
- New fields vs MT4: AsiaH/L, LondonH/L, MidnightOpen, PrevNYClose, News fields, Pivot fields

### 8. Fib Pivot Recalculation Frequency

- Weekly Pivot: recalculate in `OnInit()` + when W1 bar changes (once per week)
- Daily Pivot: recalculate when D1 bar changes (once per day)
- **Do NOT recalculate every tick**

### 9. Agent Array Size

- `signals[]` array is size **10** (indices 0-9)
- Agent at index 4 (Context Filter) is a **multiplier**, not a voter
- Agent at index 9 (Fib Pivot) **does vote**

### 10. Include Guard Convention

Every `.mqh` file must have:
```mql5
#ifndef __CLAUDE_V600_PP_MODULENAME_MQH__
#define __CLAUDE_V600_PP_MODULENAME_MQH__
// ... code ...
#endif
```

### 11. Include Style

All `.mqh` includes use **quotes** (same directory), not angle brackets:
```mql5
#include "Claude_v600_pp_inputs.mqh"   // Local include
#include <Trade/Trade.mqh>              // Standard library include
```

### 12. No DLLs

The system uses only `WebRequest()` for external communication (news feed). No DLL imports allowed.

---

## Key Architectural Patterns

### Agent System

Each agent produces a signal with:
- `score` (-100 to +100): direction and strength
- `confidence` (0.0 to 1.0): weight in aggregation
- `name`: display name for UI

The decision system aggregates scores:
```
WeightedScore = SUM(score[i] * confidence[i]) * ContextMultiplier
```

Trade triggers require:
- `WeightedScore >= EntryThreshold` (default: 70)
- `AgentsAgree >= MinAgentsAgree` (default: 3)

### Fib Pivot Zones (Agent 10)

| Zone | Range | Behavior |
|------|-------|----------|
| 0 | Near Pivot | Neutral, no direction |
| 1 | 0-38% | Mild, near equilibrium |
| 2 | 38-61% | Transitional, weak counter-trend |
| 3 | 61-78% | **David's trading zone** — primary counter-trend |
| 4 | 78-100% | **Carney zone** — strong counter-trend |
| 5 | >100% | Breakout — trade WITH trend |

### MarketContext Struct

The central data structure shared between modules. Contains:
- Market regime (0=StrongUp .. 5=StrongDown)
- Session info (Sydney, Tokyo, London, NY, overlaps)
- Indicator values (ADX, ATR, RSI, volume)
- Session levels (AsiaH/L, LondonH/L, MidnightOpen, PrevNYClose)
- News proximity info
- Pivot data (weekly/daily zones, bias, nearest levels)

---

## Verification Checklist

After implementation, verify:

- [ ] Each `.mqh` has `#ifndef` include guard
- [ ] All `#include` use quotes for local files
- [ ] Main EA compiles with 0 errors in MetaEditor 5
- [ ] All 3 indicators compile with 0 errors
- [ ] Panel displays correctly (buttons, metrics, exchanges)
- [ ] Agent block shows **10 rows** with progress bars
- [ ] News block shows upcoming events
- [ ] Journal creates `Claude_Journal_SYMBOL_TF.csv`
- [ ] `WeightedScore != 0` when agents produce signals
- [ ] Context Filter does NOT zero out scores (except blocking)
- [ ] Symbol name cleaned of broker suffixes
- [ ] AsiaH/L, LondonH/L populated in journal
- [ ] Fib Pivot lines render on chart (both draw modes)
- [ ] Fib Pivot labels are visible and readable
- [ ] Fib Pivot colors follow active color scheme
- [ ] Daily pivots display as thin dashed lines
- [ ] PivotZone and PivotBias populated in journal
- [ ] Panel shows "Pivot Zone: ..." line
- [ ] 2R-7R buttons open trades via `CTrade`
- [ ] BE buttons modify stop via `trade.PositionModify()`
- [ ] Close buttons close via `trade.PositionClose()`

### Strategy Tester Configuration

```
Mode: Visual
Symbol: GBPUSD
Period: M5
Model: Every tick
EnableAgentSystem = true
EntryThreshold = 70
MinAgentsAgree = 3
Agent_FibPivot_Enabled = true
DrawFibPivotLines = true
```

---

## MQL4 -> MQL5 Quick Reference

| MQL4 | MQL5 |
|------|------|
| `OrderSend(...)` | `CTrade trade; trade.Buy()/Sell()` |
| `OrderSelect(ticket)` | `CPositionInfo pos; pos.SelectByTicket(ticket)` |
| `OrderClose(ticket)` | `trade.PositionClose(ticket)` |
| `OrderModify(ticket)` | `trade.PositionModify(ticket, newSL, newTP)` |
| `iMA(sym, tf, period, ...)` returns value | `int h = iMA(...); CopyBuffer(h, 0, shift, count, buf)` |
| `Bid / Ask` | `SymbolInfoDouble(sym, SYMBOL_BID/SYMBOL_ASK)` |
| `Volume[i]` | `CopyTickVolume(sym, tf, 0, count, vol)` |
| `start()` (indicator) | `OnCalculate(...)` |
| `init()` / `deinit()` | `OnInit()` / `OnDeinit()` |

---

## v1 -> v2 Changelog Summary

- **NEW**: Agent 10 — Weekly Fib Pivot (Davit's Pivot Trading methodology)
- **NEW**: News calendar module (`pp_news.mqh`) with Forex Factory integration
- **FIXED**: Context Filter no longer zeros out `WeightedScore`
- **FIXED**: Journal format upgraded to V2, broker suffix cleanup
- **ADDED**: Session levels (AsiaH/L, LondonH/L, MidnightOpen) in journal
- **ADDED**: 9 Fib Pivot color fields across all 5 color schemes
- **ADDED**: 10 new MarketContext fields for pivot data
- **EXPANDED**: `signals[]` array from 9 to 10 elements
- **EXPANDED**: Pivot zone display line in agent panel
- **EXPANDED**: Fib Pivot TP targets for trade grading (2R-13R)
