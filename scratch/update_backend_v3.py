with open('/Users/irf/Desktop/app/mts/account_server_kt/src/main/kotlin/com/mts/account/config/DataInitializer.kt', 'r') as f:
    lines = f.readlines()

with open('/Users/irf/Desktop/app/mts/scratch/kotlin_tickers_split.txt', 'r') as f:
    kotlin_split_code = f.read()

# Indent the split code
indented_code = ""
for line in kotlin_split_code.split('\n'):
    if line.strip():
        indented_code += "            " + line + "\n"

# Find the line that starts with "            val allUsTickers = "
start_idx = -1
for i in range(len(lines)):
    if 'val allUsTickers = ' in lines[i]:
        start_idx = i
        break

if start_idx != -1:
    # Replace that line with the new indented code
    lines[start_idx] = indented_code
    with open('/Users/irf/Desktop/app/mts/account_server_kt/src/main/kotlin/com/mts/account/config/DataInitializer.kt', 'w') as f:
        f.writelines(lines)
    print("Updated DataInitializer.kt with SPLIT shuffled real US tickers.")
else:
    print("Failed to find 'val allUsTickers =' in DataInitializer.kt")
