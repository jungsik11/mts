import json

with open('/Users/irf/Desktop/app/mts/simulation/us_tickers_1000.txt', 'r') as f:
    tickers = [line.strip() for line in f if line.strip()]

# Kotlin format
kotlin_list = 'listOf(' + ', '.join([f'"{t}"' for t in tickers]) + ')'
with open('/Users/irf/Desktop/app/mts/scratch/kotlin_tickers.txt', 'w') as f:
    f.write(kotlin_list)

# Python format
python_list = 'US_SYMBOLS = ' + json.dumps(tickers)
with open('/Users/irf/Desktop/app/mts/scratch/python_tickers.txt', 'w') as f:
    f.write(python_list)

print("Generated ticker lists for Kotlin and Python.")
