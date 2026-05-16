import re
import random

random.seed(42) # Deterministic shuffle

input_file = '/Users/irf/.gemini/antigravity/brain/9189d471-ada2-4574-a791-6cb7d0b84aa0/.system_generated/steps/537/content.md'
output_file = '/Users/irf/Desktop/app/mts/simulation/us_tickers_1000.txt'

all_tickers = []
with open(input_file, 'r') as f:
    for line in f:
        ticker = line.strip()
        if not ticker or ticker.startswith('Source') or ticker.startswith('---') or len(ticker) < 1:
            continue
        
        # Filter out warrants/units/rights
        if re.search(r'[WURZYX]$', ticker) and len(ticker) > 3:
            continue
            
        all_tickers.append(ticker)

# Shuffle to get a good mix of letters
random.shuffle(all_tickers)
selected_tickers = all_tickers[:1000]

with open(output_file, 'w') as f:
    for t in selected_tickers:
        f.write(t + '\n')

print(f"Saved {len(selected_tickers)} shuffled tickers to {output_file}")
