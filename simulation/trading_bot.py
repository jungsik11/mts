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
BOT_USER_IDS = list(range(2, 1002))  # IDs 2 to 1001 (Total 1000 bots)

# Cache for bot holdings to reduce API calls
bot_holdings_cache = {}

# 장 운영 시간 (한국 시간 기준)
MARKET_OPEN_HOUR  = 8
MARKET_CLOSE_HOUR = 20
KST = pytz.timezone("Asia/Seoul")


def is_market_open() -> bool:
    """장 운영 시간 여부 확인: 매일 08:00 ~ 20:00 KST"""
    now = datetime.now(KST)
    return MARKET_OPEN_HOUR <= now.hour < MARKET_CLOSE_HOUR


def seconds_until_market_open() -> float:
    """다음 장 개장까지 남은 초 계산"""
    now = datetime.now(KST)
    # 오늘 08:00 KST
    open_today = now.replace(hour=MARKET_OPEN_HOUR, minute=0, second=0, microsecond=0)
    if now >= open_today:
        # 이미 오전 8시를 지났으면 내일 오전 8시
        from datetime import timedelta
        open_today += timedelta(days=1)
    return (open_today - now).total_seconds()


def get_all_tickers():
    keys = r_primary.keys("price:*")
    tickers = [k.replace("price:", "") for k in keys]
    domestic_tickers = []
    for ticker in tickers:
        try:
            info_raw = r_primary.get(f"ticker_info:{ticker}")
            if info_raw:
                info = json.loads(info_raw)
                # Filter out foreign ETFs or names containing "미국"
                if "미국" in info.get("name", "") or "해외" in info.get("sector", ""):
                    continue
            domestic_tickers.append(ticker)
        except Exception:
            domestic_tickers.append(ticker) # Fallback to including if info missing
    return domestic_tickers


async def place_random_order(session):
    user_id = random.choice(BOT_USER_IDS)
    side = random.choice(["BUY", "SELL"])

    ticker = None
    if side == "SELL":
        # Try to pick from holdings
        if user_id not in bot_holdings_cache or random.random() < 0.1: # 10% chance to refresh
            try:
                async with session.get(f"{ACCOUNT_SERVER_URL}/{user_id}") as resp:
                    if resp.status == 200:
                        data = await resp.json()
                        bot_holdings_cache[user_id] = [h["ticker"] for h in data.get("holdings", []) if h["quantity"] > 0]
            except Exception:
                pass
        
        holdings = bot_holdings_cache.get(user_id, [])
        if holdings:
            ticker = random.choice(holdings)
        else:
            side = "BUY" # Switch to BUY if nothing to sell

    if not ticker:
        tickers = get_all_tickers()
        if not tickers:
            return
        ticker = random.choice(tickers)

    # 1. Fetch current price from Redis
    try:
        price_data_raw = r_primary.get(f"price:{ticker}")
        price_data = json.loads(price_data_raw) if price_data_raw else {}
    except Exception:
        price_data = {}

    # 2. Determine order price (near current price)
    current_price = price_data.get("price", 10000)
    
    # Randomly decide how aggressive to be
    # 30% Market-like (very close to current price)
    # 40% Active (within 0.5% of current price)
    # 30% Limit (within 1-2% of current price to build order book)
    dice = random.random()
    if dice < 0.3:
        # Very aggressive (Immediate match)
        offset = random.uniform(0, 0.001)
    elif dice < 0.7:
        # Active (Near current spread)
        offset = random.uniform(0.001, 0.005)
    else:
        # Limit (Creating depth)
        offset = random.uniform(0.005, 0.02)
    
    if side == "BUY":
        # Bids are usually lower than current price, but aggressive bids are higher
        if dice < 0.3:
            price = int(current_price * (1 + offset)) # Aggressive BUY (higher than current)
        else:
            price = int(current_price * (1 - offset)) # Passive BUY (lower than current)
    else:
        # Asks are usually higher than current price, but aggressive asks are lower
        if dice < 0.3:
            price = int(current_price * (1 - offset)) # Aggressive SELL (lower than current)
        else:
            price = int(current_price * (1 + offset)) # Passive SELL (higher than current)

    # Rounding logic
    if price > 100000: price = (price // 100) * 100
    elif price > 1000: price = (price // 10) * 10
    
    if price <= 0: price = 10

    quantity = random.randint(1, 20)
    payload = {
        "user_id": user_id,
        "ticker": ticker,
        "quantity": quantity,
        "price": price,
        "side": side,
    }

    headers = {
        "X-Internal-Secret": "mts-simulation-secret",
        "Content-Type": "application/json"
    }

    try:
        async with session.post(TRADING_SERVER_URL, json=payload, headers=headers) as resp:
            if resp.status == 200:
                logger.info(f"Bot {user_id} placed {side} for {ticker}: {quantity} @ {price}")
            else:
                body = await resp.text()
                logger.warning(f"Order failed: {resp.status} - {body}")
    except Exception as e:
        logger.error(f"Error in bot: {e}")


async def heartbeat():
    while True:
        try:
            r_secondary.set("heartbeat:trading-bot", json.dumps({
                "status": "ACTIVE",
                "timestamp": datetime.now(KST).isoformat(),
                "bots_count": len(BOT_USER_IDS)
            }), ex=10)
        except Exception as e:
            logger.error(f"Heartbeat error: {e}")
        await asyncio.sleep(2)


async def main():
    logger.info("Trading Bot 시작 - 장 운영 시간: 08:00 ~ 20:00 KST")
    async with aiohttp.ClientSession() as session:
        # Run heartbeat and main bot loop concurrently
        asyncio.create_task(heartbeat())
        while True:
            if not is_market_open():
                wait_sec = seconds_until_market_open()
                open_time = datetime.now(KST).replace(
                    hour=MARKET_OPEN_HOUR, minute=0, second=0, microsecond=0
                )
                logger.info(
                    f"장 마감 시간입니다. 다음 개장({open_time.strftime('%Y-%m-%d %H:%M KST')})까지 "
                    f"{wait_sec / 3600:.1f}시간 대기합니다."
                )
                await asyncio.sleep(wait_sec)
                # 개장 시 오더북 시딩
                logger.info("장 개장 - 오더북 초기화 중...")
                for _ in range(50):
                    await place_random_order(session)
                logger.info("오더북 초기화 완료. 매매 시작.")
                continue

            # 장 운영 중: 대규모 병렬 주문으로 매매 빈도 극대화 (~400 orders/sec)
            tasks = [place_random_order(session) for _ in range(20)]
            await asyncio.gather(*tasks)
            await asyncio.sleep(0.05)


if __name__ == "__main__":
    asyncio.run(main())
