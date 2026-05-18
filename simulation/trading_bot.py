import asyncio
import aiohttp
import random
import logging
import os
import redis
import json
from datetime import datetime
import pytz
from dotenv import load_dotenv

load_dotenv()

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("trading-bot")

r_primary_host = os.getenv('REDIS_PRIMARY_HOST', '100.91.106.15')
r_secondary_host = os.getenv('REDIS_SECONDARY_HOST', '100.91.106.15')
r_primary = redis.Redis(host=r_primary_host, port=6379, db=0, decode_responses=True)
r_secondary = redis.Redis(host=r_secondary_host, port=6379, db=0, decode_responses=True)

TRADING_SERVER_URL = os.getenv('TRADING_SERVER_URL', 'http://100.91.106.15:9001/order')
ACCOUNT_SERVER_URL = os.getenv('ACCOUNT_SERVER_URL', 'http://100.91.106.15:9000/assets')
BOT_USER_IDS = list(range(2, 10002))  # IDs 2 to 10001 (Total 10000 bots)

# Cache for bot holdings and tickers to reduce API/Redis calls
bot_holdings_cache = {}
tickers_cache = {"data": [], "last_updated": 0}

# 장 운영 시간 (한국 시간 기준)
KR_OPEN  = 8
KR_CLOSE = 20
US_OPEN  = 17
US_CLOSE = 7
KST = pytz.timezone("Asia/Seoul")

def get_market_status():
    """KR, US 시장 개장 여부 확인"""
    now = datetime.now(KST)
    is_kr = KR_OPEN <= now.hour < KR_CLOSE
    is_us = now.hour >= US_OPEN or now.hour < US_CLOSE
    return is_kr, is_us

def seconds_until_any_market_open():
    """가장 빨리 열리는 시장까지 남은 시간"""
    now = datetime.now(KST)
    # Check next KR open
    kr_next = now.replace(hour=KR_OPEN, minute=0, second=0, microsecond=0)
    if now.hour >= KR_OPEN: kr_next += asyncio.timedelta(days=1)
    
    # Check next US open
    us_next = now.replace(hour=US_OPEN, minute=0, second=0, microsecond=0)
    if now.hour >= US_OPEN: us_next += asyncio.timedelta(days=1)
    
    return min((kr_next - now).total_seconds(), (us_next - now).total_seconds())

tickers_lock = asyncio.Lock()

async def get_all_tickers():
    now = datetime.now().timestamp()
    if tickers_cache["data"] and now - tickers_cache["last_updated"] < 60:
        return tickers_cache["data"]

    async with tickers_lock:
        # Double-check inside lock
        now = datetime.now().timestamp()
        if tickers_cache["data"] and now - tickers_cache["last_updated"] < 60:
            return tickers_cache["data"]

        logger.debug("Refreshing tickers cache from Redis...")
        keys = r_primary.keys("price:*")
        tickers = [k.replace("price:", "") for k in keys]
        tickers_cache["data"] = tickers
        tickers_cache["last_updated"] = now
        return tickers

async def place_random_order(session):
    is_kr_open, is_us_open = get_market_status()
    if not is_kr_open and not is_us_open:
        return

    user_id = random.choice(BOT_USER_IDS)
    side = random.choice(["BUY", "SELL"])

    # Filter tickers based on which market is open
    all_tickers = await get_all_tickers()
    available_tickers = []
    if is_kr_open:
        available_tickers += [t for t in all_tickers if t.isdigit()]
    if is_us_open:
        available_tickers += [t for t in all_tickers if not t.isdigit()]

    if not available_tickers:
        return

    ticker = None
    if side == "SELL":
        # Try to pick from holdings
        if user_id not in bot_holdings_cache or random.random() < 0.05:
            try:
                async with session.get(f"{ACCOUNT_SERVER_URL}/{user_id}") as resp:
                    if resp.status == 200:
                        data = await resp.json()
                        bot_holdings_cache[user_id] = [h["ticker"] for h in data.get("holdings", []) if h["quantity"] > 0]
            except Exception: pass
        
        holdings = [t for t in bot_holdings_cache.get(user_id, []) if t in available_tickers]
        if holdings:
            ticker = random.choice(holdings)
        else:
            side = "BUY"

    if not ticker:
        ticker = random.choice(available_tickers)

    is_us_stock = not ticker.isdigit()

    # 1. Fetch current price
    try:
        price_data_raw = r_primary.get(f"price:{ticker}")
        price_data = json.loads(price_data_raw) if price_data_raw else {}
    except Exception: price_data = {}

    current_price = price_data.get("price", 10000 if not is_us_stock else 100.0)
    
    dice = random.random()
    offset = random.uniform(0, 0.005) if dice < 0.7 else random.uniform(0.005, 0.02)
    
    if side == "BUY":
        price = current_price * (1 + offset) if dice < 0.3 else current_price * (1 - offset)
    else:
        price = current_price * (1 - offset) if dice < 0.3 else current_price * (1 + offset)

    # Rounding logic
    if is_us_stock:
        price = round(price, 2) # 2 decimal places for USD
    else:
        price = int(price)
        if price > 100000: price = (price // 100) * 100
        elif price > 1000: price = (price // 10) * 10
    
    if price <= 0: price = 0.01 if is_us_stock else 10

    quantity = random.randint(1, 10) if is_us_stock else random.randint(1, 100)
    payload = {
        "user_id": user_id,
        "ticker": ticker,
        "quantity": quantity,
        "price": price,
        "side": side,
    }

    headers = {"X-Internal-Secret": "mts-simulation-secret", "Content-Type": "application/json"}

    try:
        async with session.post(TRADING_SERVER_URL, json=payload, headers=headers) as resp:
            if resp.status != 200:
                logger.error(f"Order failed with status {resp.status}")
    except Exception as e:
        logger.error(f"Error placing order: {e}")

async def heartbeat():
    while True:
        try:
            r_secondary.set("heartbeat:trading-bot", json.dumps({
                "status": "ACTIVE",
                "timestamp": datetime.now(KST).isoformat(),
                "bots_count": len(BOT_USER_IDS)
            }), ex=10)
        except Exception: pass
        await asyncio.sleep(2)

import socket
import urllib.parse

def resolve_url(url):
    try:
        parsed = urllib.parse.urlparse(url)
        ip = socket.gethostbyname(parsed.hostname)
        return url.replace(parsed.hostname, ip)
    except Exception:
        return url

async def main():
    logger.info("Trading Bot 시작 - KR(08-20), US(17-07) KST")
    
    # DNS 과부하로 인한 'Name or service not known' 에러를 방지하기 위해 시작 시 IP를 미리 해석합니다.
    global TRADING_SERVER_URL, ACCOUNT_SERVER_URL
    TRADING_SERVER_URL = resolve_url(TRADING_SERVER_URL)
    ACCOUNT_SERVER_URL = resolve_url(ACCOUNT_SERVER_URL)
    logger.info(f"Resolved TRADING_SERVER_URL: {TRADING_SERVER_URL}")
    logger.info(f"Resolved ACCOUNT_SERVER_URL: {ACCOUNT_SERVER_URL}")

    # Increase connection limit to handle more concurrent requests
    connector = aiohttp.TCPConnector(limit=5000, use_dns_cache=True, ttl_dns_cache=300)
    async with aiohttp.ClientSession(connector=connector) as session:
        asyncio.create_task(heartbeat())
        while True:
            is_kr, is_us = get_market_status()
            if not is_kr and not is_us:
                wait_sec = seconds_until_any_market_open()
                logger.info(f"모든 장 마감. {wait_sec / 3600:.1f}시간 대기.")
                await asyncio.sleep(wait_sec)
                continue

            # Increase batch size to 200 (from 50) and reduce sleep slightly to boost TPS
            tasks = [place_random_order(session) for _ in range(200)]
            await asyncio.gather(*tasks)
            await asyncio.sleep(0.005)

if __name__ == "__main__":
    asyncio.run(main())
