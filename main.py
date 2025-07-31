from pinenode.executor import ExampleScriptExecutor
from pandas import read_csv

with open("pinescripts/TTS_v1.1.0.tps") as f:
    source = f.read()

df = read_csv("data/BTC_15m_full.csv", index_col=0, parse_dates=True)

executor = ExampleScriptExecutor(source)
executor.execute(df)