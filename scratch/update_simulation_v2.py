with open('/Users/irf/Desktop/app/mts/simulation/price_generator.py', 'r') as f:
    lines = f.readlines()

with open('/Users/irf/Desktop/app/mts/scratch/python_tickers_top1000.txt', 'r') as f:
    python_block = f.read()

# Find the indices to replace
start_idx = -1
end_idx = -1
for i in range(len(lines)):
    if 'US_COMPANIES_RAW = [' in lines[i]:
        start_idx = i
        # Find the end of this list. It's a long line now.
        end_idx = i + 1
        break

if start_idx != -1:
    new_lines = lines[:start_idx] + [python_block + '\n'] + lines[end_idx:]
    with open('/Users/irf/Desktop/app/mts/simulation/price_generator.py', 'w') as f:
        f.writelines(new_lines)
    print("Updated price_generator.py with TOP 1000 shuffled real US tickers.")
else:
    print(f"Failed to find 'US_COMPANIES_RAW = [' in price_generator.py")
