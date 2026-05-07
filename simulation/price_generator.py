import random
import asyncio
import redis
import json
import os

r_host = os.getenv('REDIS_HOST', 'localhost')
r = redis.Redis(host=r_host, port=6379, db=0)

# Mock tickers and their initial prices
# Mock tickers and their initial prices (Expanded to 100 items)
TICKERS_DATA = {
    "SAMSUNG": {"price": 75000, "name": "Samsung Electronics", "sector": "Technology"},
    "SK_HYNIX": {"price": 185000, "name": "SK Hynix", "sector": "Technology"},
    "NAVER": {"price": 195000, "name": "Naver Corp", "sector": "Communication"},
    "KAKAO": {"price": 49000, "name": "Kakao Corp", "sector": "Communication"},
    "HYUNDAI": {"price": 245000, "name": "Hyundai Motor", "sector": "Consumer Discretionary"},
    "LG_ENSOL": {"price": 385000, "name": "LG Energy Solution", "sector": "Energy"},
    "POSCO": {"price": 360000, "name": "POSCO Holdings", "sector": "Materials"},
    "KIA": {"price": 115000, "name": "Kia Motors", "sector": "Consumer Discretionary"},
    "CELLTRION": {"price": 175000, "name": "Celltrion", "sector": "Healthcare"},
    "ECOPRO": {"price": 560000, "name": "EcoPro", "sector": "Materials"},
    "SAMSUNG_BIO": {"price": 820000, "name": "Samsung Biologics", "sector": "Healthcare"},
    "LG_CHEM": {"price": 450000, "name": "LG Chem", "sector": "Materials"},
    "SAMSUNG_SDI": {"price": 390000, "name": "Samsung SDI", "sector": "Energy"},
    "KB_FINANCIAL": {"price": 78000, "name": "KB Financial Group", "sector": "Financials"},
    "SHINHAN": {"price": 45000, "name": "Shinhan Financial", "sector": "Financials"},
    "HANA_FIN": {"price": 58000, "name": "Hana Financial", "sector": "Financials"},
    "WOORI_FIN": {"price": 15000, "name": "Woori Financial", "sector": "Financials"},
    "POSCO_F_M": {"price": 260000, "name": "POSCO Future M", "sector": "Materials"},
    "ECOPRO_BM": {"price": 210000, "name": "EcoPro BM", "sector": "Materials"},
    "KT_G": {"price": 92000, "name": "KT&G", "sector": "Consumer Staples"},
    "LG_ELEC": {"price": 105000, "name": "LG Electronics", "sector": "Technology"},
    "HYUNDAI_MOBIS": {"price": 230000, "name": "Hyundai Mobis", "sector": "Consumer Discretionary"},
    "KOREA_ZINC": {"price": 520000, "name": "Korea Zinc", "sector": "Materials"},
    "SAMSUNG_FIRE": {"price": 310000, "name": "Samsung Fire & Marine", "sector": "Financials"},
    "MERITZ_FIN": {"price": 82000, "name": "Meritz Financial", "sector": "Financials"},
    "SK_INNO": {"price": 110000, "name": "SK Innovation", "sector": "Energy"},
    "KRAFTON": {"price": 250000, "name": "Krafton", "sector": "Communication"},
    "KOREAN_AIR": {"price": 23000, "name": "Korean Air", "sector": "Industrials"},
    "HMM": {"price": 18000, "name": "HMM", "sector": "Industrials"},
    "AMOREPACIFIC": {"price": 170000, "name": "AmorePacific", "sector": "Consumer Staples"},
    "NETMARBLE": {"price": 55000, "name": "Netmarble", "sector": "Communication"},
    "NC_SOFT": {"price": 190000, "name": "NC Soft", "sector": "Communication"},
    "DOOSAN_ENER": {"price": 21000, "name": "Doosan Enerbility", "sector": "Industrials"},
    "HYUNDAI_GLOVIS": {"price": 190000, "name": "Hyundai Glovis", "sector": "Industrials"},
    "S_OIL": {"price": 72000, "name": "S-Oil", "sector": "Energy"},
    "LG_DISP": {"price": 11000, "name": "LG Display", "sector": "Technology"},
    "COWAY": {"price": 58000, "name": "Coway", "sector": "Consumer Discretionary"},
    "Yuhan": {"price": 74000, "name": "Yuhan Corp", "sector": "Healthcare"},
    "Samsung_SDS": {"price": 155000, "name": "Samsung SDS", "sector": "Technology"},
    "CJ_ENM": {"price": 82000, "name": "CJ ENM", "sector": "Communication"},
    "APPLE": {"price": 265000, "name": "Apple Inc.", "sector": "Technology"},
    "MICROSOFT": {"price": 580000, "name": "Microsoft Corp.", "sector": "Technology"},
    "GOOGLE": {"price": 235000, "name": "Alphabet Inc.", "sector": "Communication"},
    "AMAZON": {"price": 260000, "name": "Amazon.com Inc.", "sector": "Consumer Discretionary"},
    "TESLA": {"price": 255000, "name": "Tesla Inc.", "sector": "Consumer Discretionary"},
    "NVIDIA": {"price": 1250000, "name": "NVIDIA Corp.", "sector": "Technology"},
    "META": {"price": 650000, "name": "Meta Platforms", "sector": "Communication"},
    "NETFLIX": {"price": 850000, "name": "Netflix Inc.", "sector": "Communication"},
    "TSMC": {"price": 215000, "name": "TSMC", "sector": "Technology"},
    "ADOBE": {"price": 720000, "name": "Adobe Inc.", "sector": "Technology"},
    "AMD": {"price": 225000, "name": "AMD", "sector": "Technology"},
    "INTEL": {"price": 45000, "name": "Intel Corp.", "sector": "Technology"},
    "BROADCOM": {"price": 1850000, "name": "Broadcom Inc.", "sector": "Technology"},
    "QUALCOMM": {"price": 285000, "name": "Qualcomm Inc.", "sector": "Technology"},
    "DISNEY": {"price": 145000, "name": "Walt Disney Co.", "sector": "Communication"},
    "VISA": {"price": 385000, "name": "Visa Inc.", "sector": "Financials"},
    "MASTERCARD": {"price": 650000, "name": "Mastercard Inc.", "sector": "Financials"},
    "JP_MORGAN": {"price": 275000, "name": "JPMorgan Chase", "sector": "Financials"},
    "BANK_OF_AMERICA": {"price": 58000, "name": "Bank of America", "sector": "Financials"},
    "COCA_COLA": {"price": 85000, "name": "Coca-Cola Co.", "sector": "Consumer Staples"},
    "PEPSICO": {"price": 235000, "name": "PepsiCo Inc.", "sector": "Consumer Staples"},
    "STARBUCKS": {"price": 125000, "name": "Starbucks Corp.", "sector": "Consumer Discretionary"},
    "NIKE": {"price": 135000, "name": "Nike Inc.", "sector": "Consumer Discretionary"},
    "MCDONALDS": {"price": 395000, "name": "McDonald's Corp.", "sector": "Consumer Discretionary"},
    "COSTCO": {"price": 1150000, "name": "Costco Wholesale", "sector": "Consumer Staples"},
    "WALMART": {"price": 92000, "name": "Walmart Inc.", "sector": "Consumer Staples"},
    "PFE_BIO": {"price": 42000, "name": "Pfizer Inc.", "sector": "Healthcare"},
    "MODERNA": {"price": 155000, "name": "Moderna Inc.", "sector": "Healthcare"},
    "JOHNSON_J": {"price": 215000, "name": "Johnson & Johnson", "sector": "Healthcare"},
    "LILLY": {"price": 1250000, "name": "Eli Lilly & Co.", "sector": "Healthcare"},
    "ORACLE": {"price": 185000, "name": "Oracle Corp.", "sector": "Technology"},
    "SALESFORCE": {"price": 385000, "name": "Salesforce Inc.", "sector": "Technology"},
    "UBER": {"price": 98000, "name": "Uber Technologies", "sector": "Industrials"},
    "AIRBNB": {"price": 215000, "name": "Airbnb Inc.", "sector": "Consumer Discretionary"},
    "PALANTIR": {"price": 35000, "name": "Palantir Technologies", "sector": "Technology"},
    "COINBASE": {"price": 320000, "name": "Coinbase Global", "sector": "Financials"},
    "SNOWFLAKE": {"price": 225000, "name": "Snowflake Inc.", "sector": "Technology"},
    "DATADOG": {"price": 175000, "name": "Datadog Inc.", "sector": "Technology"},
    "ARM_HOLD": {"price": 185000, "name": "Arm Holdings", "sector": "Technology"},
    "ASML": {"price": 1450000, "name": "ASML Holding", "sector": "Technology"},
    "LVMH": {"price": 1150000, "name": "LVMH Moët Hennessy", "sector": "Consumer Discretionary"},
    "HERMES": {"price": 3250000, "name": "Hermès International", "sector": "Consumer Discretionary"},
    "FERRARI": {"price": 580000, "name": "Ferrari N.V.", "sector": "Consumer Discretionary"},
    "PORSCHE": {"price": 125000, "name": "Porsche AG", "sector": "Consumer Discretionary"},
    "BMW": {"price": 145000, "name": "BMW AG", "sector": "Consumer Discretionary"},
    "TOYOTA": {"price": 48000, "name": "Toyota Motor", "sector": "Consumer Discretionary"},
    "SONY": {"price": 125000, "name": "Sony Group", "sector": "Technology"},
    "NINTENDO": {"price": 85000, "name": "Nintendo Co.", "sector": "Communication"},
    "SOFTBANK": {"price": 95000, "name": "SoftBank Group", "sector": "Financials"},
    "ALIBABA": {"price": 115000, "name": "Alibaba Group", "sector": "Consumer Discretionary"},
    "TENCENT": {"price": 78000, "name": "Tencent Holdings", "sector": "Communication"},
    "XIAOMI": {"price": 3500, "name": "Xiaomi Corp.", "sector": "Technology"},
    "BYD": {"price": 45000, "name": "BYD Co.", "sector": "Consumer Discretionary"},
    "SAMSUNG_C_T": {"price": 148000, "name": "Samsung C&T", "sector": "Industrials"},
    "HANWHA_SOL": {"price": 28000, "name": "Hanwha Solutions", "sector": "Industrials"},
    "SK_SQUARE": {"price": 72000, "name": "SK Square", "sector": "Technology"},
    "HYOSUNG_TNC": {"price": 340000, "name": "Hyosung TNC", "sector": "Consumer Discretionary"},
    "L_G_H_H": {"price": 310000, "name": "LG H&H", "sector": "Consumer Staples"},
    "CJ_LOGI": {"price": 118000, "name": "CJ Logistics", "sector": "Industrials"},
    "HANJIN_KAL": {"price": 65000, "name": "Hanjin Kal", "sector": "Industrials"}
}

async def generate_prices():
    prices = {ticker: data["price"] for ticker, data in TICKERS_DATA.items()}
    
    # Initialize base prices and ticker info in Redis
    for ticker, data in TICKERS_DATA.items():
        r.set(f"base_price:{ticker}", data["price"])
        r.set(f"ticker_info:{ticker}", json.dumps({
            "name": data["name"],
            "sector": data["sector"]
        }))
        
    while True:
        for ticker in prices:
            # Sync with Redis to pick up execution prices from trading-server
            redis_data = r.get(f"price:{ticker}")
            if redis_data:
                try:
                    current_market_data = json.loads(redis_data)
                    prices[ticker] = current_market_data["price"]
                except Exception:
                    pass

            # Random fluctuation (-0.1% to +0.1%)
            change_percent = random.uniform(-0.001, 0.001)
            prices[ticker] = int(prices[ticker] * (1 + change_percent))
            
            # Calculate change_percent relative to base_price (previous day close)
            base_price = TICKERS_DATA[ticker]["price"]
            total_change_percent = round(((prices[ticker] - base_price) / base_price) * 100, 2)
            
            # Push to Redis
            data = {
                "ticker": ticker,
                "price": prices[ticker],
                "change_percent": total_change_percent
            }
            r.set(f"price:{ticker}", json.dumps(data))
            r.publish("market_prices", json.dumps(data))
            
        await asyncio.sleep(2)  # Update every 2 seconds (was 1s).
        # price_generator publishes 100 tickers per loop iteration.
        # At 1s this produced ~100 WebSocket events/sec to Flutter,
        # causing continuous UI rebuilds and frame drops. At 2s the
        # rate is halved; Flutter-side throttling handles the rest.

if __name__ == "__main__":
    asyncio.run(generate_prices())
