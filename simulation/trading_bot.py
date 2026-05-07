import asyncio
import aiohttp
import random
import logging
import os
import redis
import json

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("trading-bot")

r_host = os.getenv('REDIS_HOST', 'localhost')
r = redis.Redis(host=r_host, port=6379, db=0, decode_responses=True)

TRADING_SERVER_URL = "http://trading-server:8001/order"
BOT_USER_IDS = [2, 3, 4, 5] # Corresponds to bots created in DataInitializer

def get_all_tickers():
    keys = r.keys("price:*")
    return [k.replace("price:", "") for k in keys]

async def place_random_order(session):
    tickers = get_all_tickers()
    if not tickers: return
    ticker = random.choice(tickers)
    
    # 1. Fetch current price from Redis
    try:
        redis_data = r.get(f"price:{ticker}")
        if redis_data:
            current_data = json.loads(redis_data)
            base = current_data["price"]
        else:
            return
    except Exception:
        return

    side = random.choice(["BUY", "SELL"])
    quantity = random.randint(1, 100)
    user_id = random.choice(BOT_USER_IDS)
    
    # Price fluctuates around current market price
    price = int(base * (1 + random.uniform(-0.005, 0.005)))
    price = (price // 100) * 100 # Round to nearest 100

    payload = {
        "user_id": user_id,
        "ticker": ticker,
        "quantity": quantity,
        "price": price,
        "side": side
    }

    try:
        async with session.post(TRADING_SERVER_URL, json=payload) as resp:
            if resp.status == 200:
                # logger.info(f"Bot placed {side} order for {ticker}: {quantity} @ {price}")
                pass
            else:
                # logger.error(f"Bot failed to place order: {await resp.text()}")
                pass
    except Exception as e:
        logger.error(f"Error in bot: {e}")

async def main():
    logger.info("Starting Trading Bot...")
    async with aiohttp.ClientSession() as session:
        # Seed the book
        for _ in range(50):
            await place_random_order(session)
            
        while True:
            # Place 5-10 orders every cycle
            for _ in range(random.randint(5, 10)):
                await place_random_order(session)
            await asyncio.sleep(random.uniform(0.1, 0.5))

if __name__ == "__main__":
    asyncio.run(main())
