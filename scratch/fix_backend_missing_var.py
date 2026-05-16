with open('/Users/irf/Desktop/app/mts/account_server_kt/src/main/kotlin/com/mts/account/config/DataInitializer.kt', 'r') as f:
    lines = f.readlines()

# Find where to insert krMockTickers
# It should be after baseTickers
insert_idx = -1
for i in range(len(lines)):
    if 'val baseTickers =' in lines[i]:
        insert_idx = i + 1
        break

if insert_idx != -1:
    # Check if krMockTickers already exists (just in case)
    exists = False
    for line in lines:
        if 'val krMockTickers =' in line:
            exists = True
            break
    
    if not exists:
        lines.insert(insert_idx, '            val krMockTickers = (100..999).map { "K$it" }\n')
        with open('/Users/irf/Desktop/app/mts/account_server_kt/src/main/kotlin/com/mts/account/config/DataInitializer.kt', 'w') as f:
            f.writelines(lines)
        print("Restored krMockTickers in DataInitializer.kt")
    else:
        print("krMockTickers already exists.")
else:
    print("Failed to find baseTickers.")
