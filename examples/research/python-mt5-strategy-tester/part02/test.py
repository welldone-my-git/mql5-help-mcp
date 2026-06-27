import MetaTrader5 as mt5
from datetime import datetime, timedelta
import time
import pytz
from simulator import Simulator


if not mt5.initialize(): # Initialize MetaTrader5 instance
    print(f"Failed to Initialize MetaTrader5. Error = {mt5.last_error()}")
    mt5.shutdown()
    quit()


sim = Simulator(simulator_name="MySimulator", mt5_instance=mt5, deposit=1078.30, leverage="1:500")

start = datetime(2025, 1, 1)
end = datetime(2025, 1, 5)

bars = 10
symbol = "EURUSD"
timeframe = mt5.TIMEFRAME_H1

sim.Start(IS_TESTER=True)
# rates = sim.copy_rates_from(symbol=symbol, timeframe=mt5.TIMEFRAME_H1, date_from=start, count=bars)
# rates = sim.copy_rates_from_pos(symbol=symbol, timeframe=timeframe, start_pos=0, count=bars)
# rates = sim.copy_rates_range(symbol=symbol, timeframe=timeframe, date_from=start, date_to=end)
# print("is_tester=true\n", rates)

ticks = sim.copy_ticks_from(symbol=symbol, date_from=start.replace(month=12, hour=0, minute=0), count=bars)
print("is_tester=true\n", ticks)

sim.Start(IS_TESTER=False) # start the simulator in real-time trading

# rates = sim.copy_rates_from_pos(symbol=symbol, timeframe=timeframe, start_pos=0, count=bars)
# rates = sim.copy_rates_from(symbol=symbol, timeframe=timeframe, date_from=start, count=bars)
# rates = sim.copy_rates_range(symbol=symbol, timeframe=timeframe, date_from=start, date_to=end)
# print("is_tester=false\n",rates)

ticks = sim.copy_ticks_from(symbol=symbol, date_from=start.replace(month=12, hour=0, minute=0), count=bars)
print("is_tester=false\n", ticks)
