import csv

input_file = '/Users/irf/.gemini/antigravity/brain/9189d471-ada2-4574-a791-6cb7d0b84aa0/.system_generated/steps/638/content.md'
output_file_txt = '/Users/irf/Desktop/app/mts/simulation/us_top_1000_tickers.txt'
output_file_json = '/Users/irf/Desktop/app/mts/simulation/us_top_1000_data.json'

tickers_data = []
with open(input_file, 'r') as f:
    # Skip preamble lines
    lines = f.readlines()
    csv_start = 0
    for i, line in enumerate(lines):
        if line.strip().startswith('symbol,name,price'):
            csv_start = i
            break
    
    reader = csv.DictReader(lines[csv_start:])
    for row in reader:
        symbol = row['symbol'].replace('/', '-') # Handle BRK/B -> BRK-B
        if not symbol: continue
        
        tickers_data.append({
            "ticker": symbol,
            "name": row['name'],
            "industry": row['industry']
        })
        
        if len(tickers_data) >= 1000:
            break

# Save tickers only for Kotlin
with open(output_file_txt, 'w') as f:
    for item in tickers_data:
        f.write(item['ticker'] + '\n')

# Save full data for Python
import json
with open(output_file_json, 'w') as f:
    json.dump(tickers_data, f, indent=4)

print(f"Extracted {len(tickers_data)} top tickers.")
