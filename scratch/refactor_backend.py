import re

with open('/Users/irf/Desktop/app/mts/account_server_kt/src/main/kotlin/com/mts/account/config/DataInitializer.kt', 'r') as f:
    content = f.read()

# Extract all usTickersPartX definitions
parts = re.findall(r'val (usTickersPart\d) = (listOf\([^)]+\))', content)

new_content = content
new_methods = []

for var_name, list_val in parts:
    method_name = f"get{var_name[0].upper()}{var_name[1:]}"
    new_methods.append(f"    private fun {method_name}() = {list_val}")
    new_content = new_content.replace(f"val {var_name} = {list_val}", f"val {var_name} = {method_name}()")

# Insert methods into the class
if new_methods:
    methods_str = "\n\n" + "\n".join(new_methods) + "\n"
    # Find the end of the initData function or the class
    # The class ends with a }
    last_brace_idx = new_content.rfind('}')
    new_content = new_content[:last_brace_idx] + methods_str + new_content[last_brace_idx:]

with open('/Users/irf/Desktop/app/mts/account_server_kt/src/main/kotlin/com/mts/account/config/DataInitializer.kt', 'w') as f:
    f.write(new_content)

print(f"Refactored {len(parts)} ticker parts into private methods.")
