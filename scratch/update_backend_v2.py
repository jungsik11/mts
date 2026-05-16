with open('/Users/irf/Desktop/app/mts/account_server_kt/src/main/kotlin/com/mts/account/config/DataInitializer.kt', 'r') as f:
    lines = f.readlines()

with open('/Users/irf/Desktop/app/mts/scratch/kotlin_tickers.txt', 'r') as f:
    kotlin_list = f.read()

# Find the line that starts with "            val allUsTickers = "
for i in range(len(lines)):
    if 'val allUsTickers = listOf(' in lines[i]:
        lines[i] = f'            val allUsTickers = {kotlin_list}\n'
        break

with open('/Users/irf/Desktop/app/mts/account_server_kt/src/main/kotlin/com/mts/account/config/DataInitializer.kt', 'w') as f:
    f.writelines(lines)

print("Updated DataInitializer.kt with shuffled real US tickers.")
