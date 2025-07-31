// This Pine Script® code is subject to the terms of the Mozilla Public License 2.0 at https://mozilla.org/MPL/2.0/
// © andy91926

//@version=6
//Based on Turtle traders strategy: buy/sell on Donchian breakouts and stop loss on ATR 2x
// Added: Start/End Date filters
strategy("TTS_v1.1.0", overlay=true, calc_on_every_tick=true)

// === Helper functions ===

// Create the table once with multiple rows (one row for each condition)
var table conditionTable = table.new(position.top_right, 1, 20) // 1 column, 5 rows max (expandable)

// Function to check a given condition and update the table
f_displayCondition(condition, label, rowIndex) =>
    // Update the table with the condition result (true/false)
    if condition
        // If condition is true, set text to green
        table.cell(conditionTable, 0, rowIndex, label + ": TRUE", text_color=color.green, bgcolor=color.white)
    else
        // If condition is false, set text to red
        table.cell(conditionTable, 0, rowIndex, label + ": FALSE", text_color=color.red, bgcolor=color.white)

// Function to display a value in the table (without condition checking)
f_displayText(label, value, rowIndex) =>
    table.cell(conditionTable, 0, rowIndex, label + ": " + (value == 0 or na(value) ? "NONE" : str.tostring(value)), text_color=color.black, bgcolor=color.white)

// Function that creates a new label every `interval` bars and deletes the old one
f_create_label(prefix, value, y_pos, interval, style, bgcolor, txtcolor, old_lbl) =>
    if (bar_index % interval == 0)
        if not na(old_lbl)
            label.delete(old_lbl)
        label.new(bar_index, y_pos, prefix + ": " + str.tostring(value, "#.##"), style, bgcolor, txtcolor)
    else
        old_lbl

// === Date Range Inputs ===
startDate = input.time(title="Start Date", defval=timestamp("01 Jan 2025 00:00 +0000"), group="Date Range")
endDate   = input.time(title="End Date",  defval=timestamp("31 Dec 2099 23:59 +0000"), group="Date Range")

// Split the string on ":" to separate the exchange from the pair
splitResult = str.split(syminfo.tickerid, ":")
pairName = array.size(splitResult) > 1 ? array.get(splitResult, 1) : na

// === Stratagy performance conditions ===
isProfitable = strategy.netprofit > 0
winRate = (strategy.wintrades / strategy.closedtrades) * 100
rr = math.abs(strategy.avg_winning_trade_percent / strategy.avg_losing_trade_percent)
positivePerformance = (winRate >= 0.35) and (rr >= 1.5)

f_displayText("WinRate", winRate, 0)
f_displayText("RiskReward", rr, 1)
f_displayCondition(isProfitable, "Profitable", 2)
f_displayCondition(positivePerformance, "Performance", 3)

// === Original Inputs ===
enter_period = input.int(20, minval=1, title="Enter Channel")
exit_period = input.int(10, minval=1, title="Exit Channel")
pipSizeAdjustment = input.int(4, title="Pip Size Adjustment (number of pips to add)", minval=1)  // User can adjust the number of pips to add
direction = input.string("Long",options=["Long","Short"],title="Direction")
max_length = math.max(enter_period,exit_period)
atrmult = input.float(2.0,title="ATR multiplier (Stop Loss)")
atrperiod = input.int(20,title="ATR Period")

// === Date Range Check ===
inDateRange = (time >= startDate) and (time <= endDate)

// === Strategy Logic ===	
dir_long = direction == "Long"? true : false
atr = ta.rma(ta.tr(true), atrperiod)  // Wilder's smoothing
atrstop = atrmult * atr
upper = dir_long ? ta.highest(enter_period): ta.highest(exit_period)
lower = dir_long ? ta.lowest(exit_period): ta.lowest(enter_period)
atrupper = ta.ema(close + atrstop,3)
atrlower = ta.ema(close - atrstop,3)
atrupper_incpos = close + atr
atrlower_incpos = close - atr
plotted_atr = dir_long ? atrlower : atrupper
atr_incpos = dir_long ? atrupper_incpos : atrlower_incpos

// === Plotting ===
l = plot(lower, style=plot.style_line, linewidth=3, color=color.lime, offset=1)
u = plot(upper, style=plot.style_line, linewidth=3, color=color.lime, offset=1)
a = plot(plotted_atr, style=plot.style_line,linewidth=2,color=color.red,offset=1)
lin = line.new(x1=bar_index[5],x2=bar_index,y1=atr_incpos,y2=atr_incpos,color=color.lime,style=line.style_dashed)
line.set_width(lin,2)
line.delete(lin[4])

//################MULTIFRAME-BEGIN######################################//

// Debounce filter controls
useDebounce = input.bool(true, "Use Debounce Filter", group="Debounce Filter")
debounceLen = input.int(3, "Debounce Length", minval=1, group="Debounce Filter")

useMultiFrameCondition1 = input.bool(defval=false, title="Use Multiframe Signal 1", group = "Configure Multiframe Signals")
useMultiFrameCondition2 = input.bool(defval=false, title="Use Multiframe Signal 2")
useMultiFrameCondition3 = input.bool(defval=false, title="Use Multiframe Signal 3")

//Signals from other indicators
MultiframeSignal1Raw = input.source(close, title="Multiframe Signal 1", group = "Connect Section")
MultiframeSignal2Raw = input.source(close, title="Multiframe Signal 2")
MultiframeSignal3Raw = input.source(close, title="Multiframe Signal 3")

MultiFrameCondition1 = useMultiFrameCondition1 ? MultiframeSignal1Raw > 0 : true
MultiFrameCondition2 = useMultiFrameCondition2 ? MultiframeSignal2Raw > 0 : true
MultiFrameCondition3 = useMultiFrameCondition3 ? MultiframeSignal3Raw > 0 : true

ShowHTFFilter = input.bool(false, "Show HTF Filter", group = "Other configs")

//Output - HTF Filter
MultframeCondition = MultiFrameCondition1 and MultiFrameCondition2 and MultiFrameCondition3

// === Debounce filter implementation ===
var int countTrue = 0
var int countFalse = 0
var bool lastState = false

if MultframeCondition
    countTrue := countTrue + 1
    countFalse := 0
else
    countFalse := countFalse + 1
    countTrue := 0

if countTrue >= debounceLen
    lastState := true
if countFalse >= debounceLen
    lastState := false

filteredCondition = useDebounce ? lastState : MultframeCondition

bgcolor((ShowHTFFilter and filteredCondition) ? color.new(color.green, 80) : na)

//################MULTIFRAME-END######################################//

//################ TRIGGER SIGNALS - BEGIN ###########################//
// === Input to Enable/Disable Trigger Signals ===
useTriggerSignals = input.bool(false, "Use Trigger Signals", group = "Trigger Signals")

// Example trigger signal (can be replaced with your own logic)
triggerSignal1 = input.source(close, "Trigger Signal 1", group = "Trigger Signals")

// === Crossover detection (signal goes from 0 to 1) ===
triggerOn = useTriggerSignals ? ta.crossover(triggerSignal1, 0) : true

// Persistent token (resets when trade happens)
var bool tokenReady = false

// Set token when signal goes from 0 to 1
if triggerOn
    tokenReady := true
    if useTriggerSignals 
        label.new(bar_index, low, "🎯 Trigger 1 Set", color=color.green, textcolor=color.white)


//################ TRIGGER SIGNALS - END ###########################//

// === Position Sizing ===
var float riskAmount = na
var float positionSize = na
var float maxPositionSize = na
var float entryPrice = na
var float stopLossPrice = na
var float TrancatedPositionSize = na
var float quarterSize = na
var float limitPrice = na
var float risk = na

RiskRatio = input.float(1, "Risk Ratio (%)", minval=0.1, group="Risk Management Settings") / 100 // Risk Ratio (1% by default)

// === Multi Target Take Profit ===
useTargetPoints = input.bool(false, "Use Target Points", group="TP Settings")
targetRatio1 = input.float(2.0, "Target 1 RR", group="TP Settings")
targetRatio2 = input.float(3.0, "Target 2 RR", group="TP Settings")
targetRatio3 = input.float(4.0, "Target 3 RR", group="TP Settings")

// === Manual Conditions ===
//Condition1 = input(false, title="Price Action Pattern on Zig-Zag", group = "Manual Conditions")
//Condition2 = input(false, title="Low volume pattern on Volume SMAs (blue volume + buy signal) ")
//ManualCondition = Condition1 and Condition2

//f_displayCondition(ManualCondition, "Price action + Low volume with pike", 3)

// === Entry/Exit Conditions ===
break_up = (close >= upper[1]) and inDateRange and filteredCondition
EnterZoneCondition = inDateRange and filteredCondition
break_down = (close <= lower[1]) and inDateRange
stop_loss = dir_long ? (close<=plotted_atr[1]) : (close>=plotted_atr[1])
       
// === Strategy Execution ===
if (EnterZoneCondition and strategy.opentrades == 0 and tokenReady)
    tokenReady := false
    entryPrice := upper[1]
    stopLossPrice := lower[1]
    riskAmount := strategy.equity * RiskRatio//StartEquity * RiskRatio
    // Calculate the position size based on the risk amount and the distance from entry to stop-loss
    risk := entryPrice - stopLossPrice
    positionSize := riskAmount / risk  // The entry price is Donchian Upper Price
    maxPositionSize := 0.99 * (strategy.equity / entryPrice)
    TrancatedPositionSize := math.min(maxPositionSize, positionSize)
    quarterSize := TrancatedPositionSize / 4
    limitPrice := entryPrice + pipSizeAdjustment * syminfo.mintick  // Add pips to the upperDC price
    target1 = entryPrice + risk * targetRatio1
    target2 = entryPrice + risk * targetRatio2
    target3 = entryPrice + risk * targetRatio3
    // Compose alert message for Limit Buy Order
    string alertMsgEnter = "<type>LimitBuyOrder</type>\n" +
                           "<tp1>" + str.tostring(target1, "#.######") + "</tp1>\n" +
                           "<tp2>" + str.tostring(target2, "#.######") + "</tp2>\n" +
                           "<tp3>" + str.tostring(target3, "#.######") + "</tp3>\n" +
                           "<EntryPrice>" + str.tostring(entryPrice, "#.######") + "</EntryPrice>\n" +
                           "<StopLoss>" + str.tostring(stopLossPrice, "#.######") + "</StopLoss>\n"

    strategy.entry(id="Limit Buy Order", direction=strategy.long, qty=TrancatedPositionSize, stop=entryPrice, limit=limitPrice, alert_message=alertMsgEnter)
    if useTargetPoints

        // Compose alert message for TP orders
        string alertMsgTP1 = "<type>TP1</type>\n"
        string alertMsgTP2 = "<type>TP2</type>\n"
        string alertMsgTP3 = "<type>TP2</type>\n"

        // Partial take profits
        strategy.exit("TP1", from_entry="Limit Buy Order", qty=quarterSize, limit=target1, alert_message=alertMsgTP1)
        strategy.exit("TP2", from_entry="Limit Buy Order", qty=quarterSize, limit=target2, alert_message=alertMsgTP2)
        strategy.exit("TP3", from_entry="Limit Buy Order", qty=quarterSize, limit=target3, alert_message=alertMsgTP3)

        // Final target (runner) uses stop loss at lower
        //strategy.exit("SL4", from_entry="Limit Buy Order", qty=TrancatedPositionSize, stop=stopLossPrice)
    else
        // Fallback: all-in position with single exit
        strategy.exit("Target Sell", from_entry="Limit Buy Order", stop=stopLossPrice)

if not EnterZoneCondition
    strategy.cancel("Limit Buy Order")

if (stop_loss or close <= stopLossPrice) and dir_long and (strategy.opentrades > 0)
    strategy.close("Limit Buy Order")

// === Send Additional Alerts ===

// Store previous count of closed trades
var int last_closed_trades = 0
var float last_profit = na
var int last_index = na
var float duration_minutes = na
var int entry_bar = na
var int exit_bar = na
var int duration_bars = na

// Check if a new trade was closed
if strategy.closedtrades > last_closed_trades
    log.info("New trade has been closed:" + 
             "\nNumber of closed trades: " + str.tostring(strategy.closedtrades, "#.########"))
    // Index of the last closed trade
    last_index := strategy.closedtrades - 1
    // Get the profit of the most recently closed trade
    last_profit := strategy.closedtrades.profit(last_index)

    // Calculate duration in bars
    entry_bar := strategy.closedtrades.entry_bar_index(last_index)
    exit_bar  := strategy.closedtrades.exit_bar_index(last_index)
    duration_bars := exit_bar - entry_bar

    // Optional: convert bar duration to minutes (depends on chart resolution)
    duration_minutes := duration_bars * str.tonumber(timeframe.period)

    // Compose alert message
    string alertMessage = "<strategy>\n" +
                          "  <name>TTS_v1.1.0</name>\n" +
                          "</strategy>\n" +
                          "<alert>\n" +
                          "  <type>sell</type>\n" +
                          "  <profit>" + str.tostring(last_profit, "#.##") + "</profit>\n" +
                          "  <duration>" + str.tostring(duration_minutes) + "</duration>\n" +
                          "  <ticker>" + syminfo.ticker + "</ticker>" +
                          "</alert>"

    // Send the alert
    alert(alertMessage, alert.freq_once_per_bar)

    // Update the last recorded trade count
    last_closed_trades := strategy.closedtrades
