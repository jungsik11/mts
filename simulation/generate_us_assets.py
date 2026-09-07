import redis
import random
import os

def main():
    print("Fetching US tickers from Redis...")
    redis_host = os.getenv("REDIS_PRIMARY_HOST", "redis-primary")
    r = redis.Redis(host=redis_host, port=6379, db=0, decode_responses=True)
    keys = r.keys("price:*")
    
    # Filter US tickers (non-numeric, e.g. TSLA, AAPL, not 005930 or 990001)
    us_tickers = []
    for k in keys:
        ticker = k.replace("price:", "")
        if not ticker.isdigit():
            us_tickers.append(ticker)
            
    print(f"Found {len(us_tickers)} US tickers.")
    if not us_tickers:
        print("No US tickers found! Exiting.")
        return

    # Read bot account IDs
    # Note: On Windows PowerShell, redirecting output might produce UTF-16 or extra whitespace.
    # We will read it robustly, decoding or stripping accordingly.
    accounts_file = "bot_accounts.txt"
    if not os.path.exists(accounts_file):
        print(f"Error: {accounts_file} not found!")
        return

    with open(accounts_file, "rb") as f:
        content = f.read()
    
    # Try decoding UTF-16 first, then fallback to UTF-8
    try:
        text = content.decode("utf-16")
    except Exception:
        text = content.decode("utf-8", errors="ignore")

    account_ids = []
    for line in text.splitlines():
        line = line.strip()
        if line.isdigit():
            account_ids.append(int(line))

    print(f"Loaded {len(account_ids)} bot account IDs.")
    if not account_ids:
        print("No account IDs found! Exiting.")
        return

    print("Generating seed_us_assets.sql...")
    
    # We will generate INSERT statements for the assets table.
    # assets table schema:
    # id (bigint, primary key, uses sequence assets_id_seq)
    # account_id (bigint)
    # avg_price (double precision)
    # quantity (integer)
    # ticker (varchar)
    # Unique constraint: (account_id, ticker)
    
    # For each bot, we will give them 5 to 15 random US tickers.
    sql_lines = []
    
    # Use ON CONFLICT DO NOTHING to avoid duplicate constraint violations
    for account_id in account_ids:
        num_stocks = random.randint(5, 15)
        selected_tickers = random.sample(us_tickers, min(num_stocks, len(us_tickers)))
        
        for ticker in selected_tickers:
            # US stocks average price can be random, say 10 to 500 dollars
            avg_price = round(random.uniform(10.0, 500.0), 2)
            quantity = random.randint(100, 5000)
            
            sql_lines.append(
                f"INSERT INTO assets (account_id, avg_price, quantity, ticker) "
                f"VALUES ({account_id}, {avg_price}, {quantity}, '{ticker}') "
                f"ON CONFLICT (account_id, ticker) DO NOTHING;"
            )

    sql_filepath = "seed_us_assets.sql"
    with open(sql_filepath, "w", encoding="utf-8") as f:
        f.write("\n".join(sql_lines))
        
    print(f"Successfully generated {sql_filepath} with {len(sql_lines)} insert statements.")

if __name__ == "__main__":
    main()
