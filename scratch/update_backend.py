with open('/Users/irf/Desktop/app/mts/account_server_kt/src/main/kotlin/com/mts/account/config/DataInitializer.kt', 'r') as f:
    content = f.read()

with open('/Users/irf/Desktop/app/mts/scratch/kotlin_tickers.txt', 'r') as f:
    kotlin_list = f.read()

import re

# Replace the entire section from usBaseTickers = listOf(...) to allUsTickers = ...
pattern = r'val usBaseTickers = listOf\(.*?\)\s+.*?val usMockTickers = .*?\}\s+val allUsTickers = .*?\n'
# Note: The above regex might be tricky. Let's try a simpler approach.

start_marker = 'val usBaseTickers = listOf('
end_marker = 'val allUsTickers = (usBaseTickers + usMockTickers)'

start_idx = content.find(start_marker)
end_idx = content.find(end_marker) + len(end_marker)

if start_idx != -1 and end_idx != -1:
    new_content = content[:start_idx] + f'val allUsTickers = {kotlin_list}' + content[end_idx:]
    with open('/Users/irf/Desktop/app/mts/account_server_kt/src/main/kotlin/com/mts/account/config/DataInitializer.kt', 'w') as f:
        f.write(new_content)
    print("Updated DataInitializer.kt with 1000 real US tickers.")
else:
    print(f"Failed to find markers: start={start_idx}, end={end_idx}")
