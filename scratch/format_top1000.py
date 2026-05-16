import json
import random

random.seed(42)

with open('/Users/irf/Desktop/app/mts/simulation/us_top_1000_data.json', 'r') as f:
    tickers_data = json.load(f)

# Shuffle
random.shuffle(tickers_data)

# Kotlin format (split)
tickers = [item['ticker'] for item in tickers_data]
chunk_size = 100
chunks = [tickers[i:i + chunk_size] for i in range(0, len(tickers), chunk_size)]

kotlin_parts = []
for i, chunk in enumerate(chunks):
    part_name = f"usTickersPart{i}"
    part_content = f'val {part_name} = listOf(' + ', '.join([f'"{t}"' for t in chunk]) + ')'
    kotlin_parts.append(part_content)

full_list_def = 'val allUsTickers = ' + ' + '.join([f"usTickersPart{i}" for i in range(len(chunks))])
kotlin_full = '\n'.join(kotlin_parts) + '\n' + full_list_def

with open('/Users/irf/Desktop/app/mts/scratch/kotlin_tickers_top1000.txt', 'w') as f:
    f.write(kotlin_full)

# Python format
python_list = 'US_COMPANIES_RAW = ' + json.dumps([(item['ticker'], item['name'], item['industry']) for item in tickers_data])
with open('/Users/irf/Desktop/app/mts/scratch/python_tickers_top1000.txt', 'w') as f:
    f.write(python_list)

print("Generated shuffled top 1000 ticker lists.")
