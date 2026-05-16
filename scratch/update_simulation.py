import json

with open('/Users/irf/Desktop/app/mts/simulation/price_generator.py', 'r') as f:
    lines = f.readlines()

with open('/Users/irf/Desktop/app/mts/simulation/us_tickers_1000.txt', 'r') as f:
    tickers = [line.strip() for line in f if line.strip()]

# Format as a list of tuples (ticker, name, sector)
# Since we only have tickers from the file, we'll generate realistic names and sectors deterministically
us_sectors = ["Tech", "Bio", "Finance", "Energy", "Consumer", "Logistics", "Industrial"]
import random
random.seed(42)

us_companies_raw = []
for t in tickers:
    sector = random.choice(us_sectors)
    # Use ticker as name for now, or something simple
    us_companies_raw.append((t, f"{t} Corp", sector))

# Find the indices to replace
start_idx = -1
end_idx = -1
for i in range(len(lines)):
    if 'US_COMPANIES_RAW = [' in lines[i]:
        start_idx = i
    if 'US_COMPANIES_RAW.append((ticker, name, random.choice(us_sectors)))' in lines[i]:
        end_idx = i + 1

if start_idx != -1 and end_idx != -1:
    new_block = [f'US_COMPANIES_RAW = {json.dumps(us_companies_raw)}\n']
    new_lines = lines[:start_idx] + new_block + lines[end_idx:]
    with open('/Users/irf/Desktop/app/mts/simulation/price_generator.py', 'w') as f:
        f.writelines(new_lines)
    print("Updated price_generator.py with 1000 shuffled real US tickers.")
else:
    print(f"Failed to find markers: start={start_idx}, end={end_idx}")
