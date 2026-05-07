import asyncio
import aiohttp
import random
import logging
import os
import redis
import json
from datetime import datetime
import pytz

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("trading-bot")

r_host = os.getenv('REDIS_HOST', 'localhost')
r = redis.Redis(host=r_host, port=6379, db=0, decode_responses=True)

TRADING_SERVER_URL = "http://trading-server:8001/order"
BOT_USER_IDS = [2, 3, 4, 5]  # Corresponds to bots created in DataInitializer

# 장 운영 시간 (한국 시간 기준)
MARKET_OPEN_HOUR  = 8   # 오전 8시
MARKET_CLOSE_HOUR = 20  # 오후 8시
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
    keys = r.keys("price:*")
    return [k.replace("price:", "") for k in keys]


async def place_random_order(session):
    tickers = get_all_tickers()
    if not tickers:
        return
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
    price = (price // 100) * 100  # Round to nearest 100

    payload = {
        "user_id": user_id,
        "ticker": ticker,
        "quantity": quantity,
        "price": price,
        "side": side,
    }

    try:
        async with session.post(TRADING_SERVER_URL, json=payload) as resp:
            if resp.status == 200:
                pass
            else:
                pass
    except Exception as e:
        logger.error(f"Error in bot: {e}")


async def main():
    logger.info("Trading Bot 시작 - 장 운영 시간: 08:00 ~ 20:00 KST")
    async with aiohttp.ClientSession() as session:
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

            # 장 운영 중: 5~10개 주문 랜덤 간격으로 반복
            for _ in range(random.randint(5, 10)):
                await place_random_order(session)
            await asyncio.sleep(random.uniform(0.1, 0.5))


if __name__ == "__main__":
    asyncio.run(main())
