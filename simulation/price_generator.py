import random
import asyncio
import redis
import json
import os

r_host = os.getenv('REDIS_HOST', 'localhost')
r = redis.Redis(host=r_host, port=6379, db=0)

# Mock tickers and their initial prices
# Mock tickers and their initial prices (Expanded to 100 items)
TICKERS = {
    "SAMSUNG": 75000, "SK_HYNIX": 185000, "NAVER": 195000, "KAKAO": 49000, "HYUNDAI": 245000,
    "LG_ENSOL": 385000, "POSCO": 360000, "KIA": 115000, "CELLTRION": 175000, "ECOPRO": 560000,
    "SAMSUNG_BIO": 820000, "LG_CHEM": 450000, "SAMSUNG_SDI": 390000, "KB_FINANCIAL": 78000, "SHINHAN": 45000,
    "HANA_FIN": 58000, "WOORI_FIN": 15000, "POSCO_F_M": 260000, "ECOPRO_BM": 210000, "KT_G": 92000,
    "LG_ELEC": 105000, "HYUNDAI_MOBIS": 230000, "KOREA_ZINC": 520000, "SAMSUNG_FIRE": 310000, "MERITZ_FIN": 82000,
    "SK_INNO": 110000, "KRAFTON": 250000, "KOREAN_AIR": 23000, "HMM": 18000, "AMOREPACIFIC": 170000,
    "NETMARBLE": 55000, "NC_SOFT": 190000, "DOOSAN_ENER": 21000, "HYUNDAI_GLOVIS": 190000, "S_OIL": 72000,
    "LG_DISP": 11000, "COWAY": 58000, "Yuhan": 74000, "Samsung_SDS": 155000, "CJ_ENM": 82000,
    "APPLE": 265000, "MICROSOFT": 580000, "GOOGLE": 235000, "AMAZON": 260000, "TESLA": 255000,
    "NVIDIA": 1250000, "META": 650000, "NETFLIX": 850000, "TSMC": 215000, "ADOBE": 720000,
    "AMD": 225000, "INTEL": 45000, "BROADCOM": 1850000, "QUALCOMM": 285000, "DISNEY": 145000,
    "VISA": 385000, "MASTERCARD": 650000, "JP_MORGAN": 275000, "BANK_OF_AMERICA": 58000, "COCA_COLA": 85000,
    "PEPSICO": 235000, "STARBUCKS": 125000, "NIKE": 135000, "MCDONALDS": 395000, "COSTCO": 1150000,
    "WALMART": 92000, "PFE_BIO": 42000, "MODERNA": 155000, "JOHNSON_J": 215000, "LILLY": 1250000,
    "ORACLE": 185000, "SALESFORCE": 385000, "UBER": 98000, "AIRBNB": 215000, "PALANTIR": 35000,
    "COINBASE": 320000, "SNOWFLAKE": 225000, "DATADOG": 175000, "ARM_HOLD": 185000, "ASML": 1450000,
    "LVMH": 1150000, "HERMES": 3250000, "FERRARI": 580000, "PORSCHE": 125000, "BMW": 145000,
    "TOYOTA": 48000, "SONY": 125000, "NINTENDO": 85000, "SOFTBANK": 95000, "ALIBABA": 115000,
    "TENCENT": 78000, "XIAOMI": 3500, "BYD": 45000, "SAMSUNG_C_T": 148000, "HANWHA_SOL": 28000,
    "SK_SQUARE": 72000, "HYOSUNG_TNC": 340000, "L_G_H_H": 310000, "CJ_LOGI": 118000, "HANJIN_KAL": 65000
}

async def generate_prices():
    prices = {ticker: price for ticker, price in TICKERS.items()}
    
    # Initialize base prices (previous day close) in Redis
    for ticker, price in TICKERS.items():
        r.set(f"base_price:{ticker}", price)
        
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
            base_price = TICKERS[ticker]
            total_change_percent = round(((prices[ticker] - base_price) / base_price) * 100, 2)
            
            # Push to Redis
            data = {
                "ticker": ticker,
                "price": prices[ticker],
                "change_percent": total_change_percent
            }
            r.set(f"price:{ticker}", json.dumps(data))
            r.publish("market_prices", json.dumps(data))
            
        await asyncio.sleep(1) # Update every second

if __name__ == "__main__":
    asyncio.run(generate_prices())
