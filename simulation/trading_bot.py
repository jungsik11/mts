import asyncio
import aiohttp
import random
import logging
import os
import redis
import json
from datetime import datetime
import pytz
import socket
import urllib.parse
from dotenv import load_dotenv

load_dotenv()

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("trading-bot")

r_primary_host = os.getenv('REDIS_PRIMARY_HOST', 'redis-primary')
r_secondary_host = os.getenv('REDIS_SECONDARY_HOST', 'redis-secondary')
r_primary = redis.Redis(host=r_primary_host, port=6379, db=0, decode_responses=True)
r_secondary = redis.Redis(host=r_secondary_host, port=6379, db=0, decode_responses=True)

TRADING_SERVER_URL = os.getenv('TRADING_SERVER_URL', 'http://trading-server:8001/order')
ACCOUNT_SERVER_URL = os.getenv('ACCOUNT_SERVER_URL', 'http://account-server:8000/assets')
ACCOUNT_BASE_URL = os.getenv('ACCOUNT_BASE_URL', 'http://account-server:8000')

MM_BOT_USER_IDS = []
NORMAL_BOT_USER_IDS = []
BOT_USER_IDS = []

async def init_bot_ids(session):
    global MM_BOT_USER_IDS, NORMAL_BOT_USER_IDS, BOT_USER_IDS
    try:
        async with session.get(f"{ACCOUNT_BASE_URL}/admin/bots/ids") as resp:
            if resp.status == 200:
                ids = await resp.json()
                if ids:
                    BOT_USER_IDS = sorted(ids)
                    mm_count = max(1, len(BOT_USER_IDS) // 10)
                    MM_BOT_USER_IDS = BOT_USER_IDS[:mm_count]
                    NORMAL_BOT_USER_IDS = BOT_USER_IDS[mm_count:]
                    logger.info(f"Loaded {len(BOT_USER_IDS)} bot IDs from server.")
                else:
                    logger.warning("No bot IDs returned from server.")
            else:
                logger.error(f"Failed to fetch bot IDs. Status: {resp.status}")
    except Exception as e:
        logger.error(f"Error fetching bot IDs: {e}")

# Cache for bot holdings and tickers to reduce API/Redis calls
bot_assets_cache = {}
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
        now = datetime.now().timestamp()
        if tickers_cache["data"] and now - tickers_cache["last_updated"] < 60:
            return tickers_cache["data"]

        logger.debug("Refreshing tickers cache from Redis...")
        keys = r_primary.keys("price:*")
        tickers = [k.replace("price:", "") for k in keys]
        tickers_cache["data"] = tickers
        tickers_cache["last_updated"] = now
        return tickers

async def get_bot_assets(session, user_id):
    now = datetime.now().timestamp()
    cached = bot_assets_cache.get(user_id)
    if cached and now - cached["last_updated"] < 60:
        return cached

    is_mm = user_id in MM_BOT_USER_IDS
    try:
        async with session.get(f"{ACCOUNT_SERVER_URL}/{user_id}") as resp:
            if resp.status == 200:
                data = await resp.json()
                cash = data.get("cash_balance", 0.0)
                
                # Bot Respawn Logic
                if cash < 10000:
                    try:
                        async with session.get(f"{ACCOUNT_BASE_URL}/account/list/{user_id}") as acc_resp:
                            if acc_resp.status == 200:
                                accounts = await acc_resp.json()
                                if accounts:
                                    acc = accounts[0]
                                    locked_cash = acc.get("lockedBalance", 0.0)
                                    acc_num = acc.get("accountNumber")
                                    
                                    # Only respawn if total cash (available + locked) is really low
                                    if (cash + locked_cash) < 10000:
                                        amount = 100000000 if is_mm else 10000000
                                        payload = {"accountNumber": acc_num, "amount": amount, "currency": "KRW"}
                                        async with session.post(f"{ACCOUNT_BASE_URL}/admin/account/deposit", json=payload) as dep_resp:
                                            if dep_resp.status == 200:
                                                resp_json = await dep_resp.json()
                                                if resp_json.get("status") == "Success":
                                                    cash += amount
                                                    logger.info(f"Respawned Bot {user_id} with {amount} KRW")
                                                else:
                                                    logger.error(f"Failed to respawn bot {user_id}: {resp_json}")
                    except Exception as e:
                        logger.error(f"Failed to respawn bot {user_id}: {e}")

                new_cache = {
                    "last_updated": now,
                    "cash_balance": cash,
                    "holdings": data.get("holdings", [])
                }
                bot_assets_cache[user_id] = new_cache
                return new_cache
    except Exception:
        pass
    return {"last_updated": now, "cash_balance": 0.0, "holdings": []}

async def place_random_order(session):
    is_kr_open, is_us_open = get_market_status()
    if not is_kr_open and not is_us_open:
        return

    user_id = random.choice(BOT_USER_IDS)
    is_mm = user_id in MM_BOT_USER_IDS
    
    all_tickers = await get_all_tickers()
    available_tickers = []
    if is_kr_open:
        available_tickers += [t for t in all_tickers if t.isdigit()]
    if is_us_open:
        available_tickers += [t for t in all_tickers if not t.isdigit()]

    if not available_tickers:
        return

    async def _place(t, p, q, s):
        headers = {"X-Internal-Secret": "mts-simulation-secret", "Content-Type": "application/json"}
        payload = {"user_id": user_id, "ticker": t, "quantity": q, "price": p, "side": s}
        try:
            async with session.post(TRADING_SERVER_URL, json=payload, headers=headers) as resp:
                if resp.status not in (200, 400):
                    logger.error(f"Order failed with status {resp.status}")
        except Exception:
            pass

    def _round_price(p, is_us):
        if is_us:
            return max(0.01, round(p, 2))
        else:
            p = int(p)
            if p > 100000: p = (p // 100) * 100
            elif p > 1000: p = (p // 10) * 10
            return max(10, p)

    if is_mm:
        # Market Maker Logic with Inventory-Aware Pricing
        ticker = random.choice(available_tickers)
        is_us_stock = not ticker.isdigit()
        
        try:
            price_data_raw = r_primary.get(f"price:{ticker}")
            current_price = json.loads(price_data_raw).get("price", 100.0 if is_us_stock else 10000) if price_data_raw else (100.0 if is_us_stock else 10000)
        except Exception: 
            current_price = 100.0 if is_us_stock else 10000

        # Fetch assets to adjust skew
        assets = await get_bot_assets(session, user_id)
        holdings_dict = {h["ticker"]: h["quantity"] for h in assets.get("holdings", [])}
        current_qty = holdings_dict.get(ticker, 0)
        
        target_qty = 50 if is_us_stock else 500
        skew = (current_qty - target_qty) / target_qty
        
        # Adjust mid_price based on skew (max 0.5% shift)
        skew_effect = max(-0.005, min(0.005, skew * -0.002))
        shifted_mid = current_price * (1 + skew_effect)

        spread = random.uniform(0.001, 0.005) # 0.1% ~ 0.5% spread
        buy_price = _round_price(shifted_mid * (1 - spread), is_us_stock)
        sell_price = _round_price(shifted_mid * (1 + spread), is_us_stock)
        quantity = random.randint(5, 20) if is_us_stock else random.randint(50, 200)

        await _place(ticker, buy_price, quantity, "BUY")
        await _place(ticker, sell_price, quantity, "SELL")

    else:
        # Normal Directional Bot Logic
        side = random.choice(["BUY", "SELL"])
        ticker = None
        
        if side == "SELL":
            assets = await get_bot_assets(session, user_id)
            holdings = [h["ticker"] for h in assets.get("holdings", []) if h["quantity"] > 0 and h["ticker"] in available_tickers]
            if holdings:
                ticker = random.choice(holdings)
            else:
                return # Skip if no holdings

        if not ticker:
            ticker = random.choice(available_tickers)

        is_us_stock = not ticker.isdigit()

        try:
            price_data_raw = r_primary.get(f"price:{ticker}")
            current_price = json.loads(price_data_raw).get("price", 100.0 if is_us_stock else 10000) if price_data_raw else (100.0 if is_us_stock else 10000)
        except Exception: 
            current_price = 100.0 if is_us_stock else 10000
        
        dice = random.random()
        offset = random.uniform(0, 0.005) if dice < 0.7 else random.uniform(0.005, 0.02)
        
        if side == "BUY":
            price = current_price * (1 + offset) if dice < 0.3 else current_price * (1 - offset)
        else:
            price = current_price * (1 - offset) if dice < 0.3 else current_price * (1 + offset)

        price = _round_price(price, is_us_stock)
        quantity = random.randint(1, 10) if is_us_stock else random.randint(1, 100)

        await _place(ticker, price, quantity, side)

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

def resolve_url(url):
    try:
        parsed = urllib.parse.urlparse(url)
        ip = socket.gethostbyname(parsed.hostname)
        return url.replace(parsed.hostname, ip)
    except Exception:
        return url

async def main():
    logger.info("Trading Bot 시작 - KR(08-20), US(17-07) KST")
    
    global TRADING_SERVER_URL, ACCOUNT_SERVER_URL, ACCOUNT_BASE_URL
    TRADING_SERVER_URL = resolve_url(TRADING_SERVER_URL)
    ACCOUNT_SERVER_URL = resolve_url(ACCOUNT_SERVER_URL)
    ACCOUNT_BASE_URL = resolve_url(ACCOUNT_BASE_URL)
    logger.info(f"Resolved TRADING_SERVER_URL: {TRADING_SERVER_URL}")
    logger.info(f"Resolved ACCOUNT_BASE_URL: {ACCOUNT_BASE_URL}")

    connector = aiohttp.TCPConnector(limit=5000, use_dns_cache=True, ttl_dns_cache=300)
    async with aiohttp.ClientSession(connector=connector) as session:
        await init_bot_ids(session)
        asyncio.create_task(heartbeat())
        while True:
            is_kr, is_us = get_market_status()
            if not is_kr and not is_us:
                wait_sec = seconds_until_any_market_open()
                logger.info(f"모든 장 마감. {wait_sec / 3600:.1f}시간 대기.")
                await asyncio.sleep(wait_sec)
                continue

            if not BOT_USER_IDS:
                await asyncio.sleep(5)
                await init_bot_ids(session)
                continue

            tasks = [place_random_order(session) for _ in range(200)]
            await asyncio.gather(*tasks)
            await asyncio.sleep(0.005)

if __name__ == "__main__":
    asyncio.run(main())
