import json

with open('/Users/irf/Desktop/app/mts/simulation/us_tickers_1000.txt', 'r') as f:
    tickers = [line.strip() for line in f if line.strip()]

# Split into chunks of 100 to avoid JVM method size limits
chunk_size = 100
chunks = [tickers[i:i + chunk_size] for i in range(0, len(tickers), chunk_size)]

kotlin_parts = []
for i, chunk in enumerate(chunks):
    part_name = f"usTickersPart{i}"
    part_content = f'val {part_name} = listOf(' + ', '.join([f'"{t}"' for t in chunk]) + ')'
    kotlin_parts.append(part_content)

full_list_def = 'val allUsTickers = ' + ' + '.join([f"usTickersPart{i}" for i in range(len(chunks))])

kotlin_full = '\n'.join(kotlin_parts) + '\n' + full_list_def

with open('/Users/irf/Desktop/app/mts/scratch/kotlin_tickers_split.txt', 'w') as f:
    f.write(kotlin_full)

print(f"Generated split ticker list for Kotlin ({len(chunks)} chunks).")
