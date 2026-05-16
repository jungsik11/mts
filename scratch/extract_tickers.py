import re

input_file = '/Users/irf/.gemini/antigravity/brain/9189d471-ada2-4574-a791-6cb7d0b84aa0/.system_generated/steps/537/content.md'
output_file = '/Users/irf/Desktop/app/mts/simulation/us_tickers_1000.txt'

tickers = []
with open(input_file, 'r') as f:
    for line in f:
        ticker = line.strip()
        # Filter out metadata lines and warrants/units/rights
        # Usually warrants end with W, units with U, rights with R. 
        # Also avoid tickers with more than 5 letters if possible for "cleaner" look, 
        # though many real ones have 4 or 5.
        if not ticker or ticker.startswith('Source') or ticker.startswith('---') or len(ticker) < 1:
            continue
        
        # Heuristic to filter out complex instruments:
        # Tickers ending in W (Warrant), U (Unit), R (Right), Z/Y/X (sometimes preferred or special)
        # We want common stocks.
        if re.search(r'[WURZYX]$', ticker) and len(ticker) > 3:
            continue
            
        tickers.append(ticker)
        if len(tickers) >= 1000:
            break

with open(output_file, 'w') as f:
    for t in tickers:
        f.write(t + '\n')

print(f"Saved {len(tickers)} tickers to {output_file}")
