with open('/Users/irf/Desktop/app/mts/account_server_kt/src/main/kotlin/com/mts/account/config/DataInitializer.kt', 'r') as f:
    lines = f.readlines()

with open('/Users/irf/Desktop/app/mts/scratch/kotlin_tickers_top1000.txt', 'r') as f:
    kotlin_split_code = f.read()

# Indent the split code
indented_code = ""
for line in kotlin_split_code.split('\n'):
    if line.strip():
        indented_code += "            " + line + "\n"

# Find the start of the usTickersPart section
start_line = -1
end_line = -1
for i in range(len(lines)):
    if 'val usTickersPart0 = ' in lines[i]:
        start_line = i
    if 'val allUsTickers = ' in lines[i] and start_line != -1:
        end_line = i
        break

if start_line != -1 and end_line != -1:
    # Replace the block
    new_lines = lines[:start_line] + [indented_code] + lines[end_line+1:]
    with open('/Users/irf/Desktop/app/mts/account_server_kt/src/main/kotlin/com/mts/account/config/DataInitializer.kt', 'w') as f:
        f.writelines(new_lines)
    print("Updated DataInitializer.kt with TOP 1000 shuffled real US tickers.")
else:
    # If not found, try to find the single-line one and replace it
    for i in range(len(lines)):
        if 'val allUsTickers = listOf(' in lines[i]:
            lines[i] = indented_code
            with open('/Users/irf/Desktop/app/mts/account_server_kt/src/main/kotlin/com/mts/account/config/DataInitializer.kt', 'w') as f:
                f.writelines(lines)
            print("Updated DataInitializer.kt (single-line -> split) with TOP 1000 shuffled real US tickers.")
            break
