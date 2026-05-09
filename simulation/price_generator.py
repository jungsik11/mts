import random
import asyncio
import redis
import json
import os
from datetime import datetime

r_primary_host = os.getenv('REDIS_PRIMARY_HOST', 'localhost')
r_secondary_host = os.getenv('REDIS_SECONDARY_HOST', 'localhost')
r_primary = redis.Redis(host=r_primary_host, port=6379, db=0)
r_secondary = redis.Redis(host=r_secondary_host, port=6379, db=0)

# Mock tickers and their initial prices (100+ Actual Korean Stock Codes)
TICKERS_DATA = {
    # KOSPI Top 70
    "005930": {"price": 75000, "name": "삼성전자", "sector": "반도체"},
    "000660": {"price": 185000, "name": "SK하이닉스", "sector": "반도체"},
    "373220": {"price": 385000, "name": "LG에너지솔루션", "sector": "2차전지"},
    "207940": {"price": 820000, "name": "삼성바이오로직스", "sector": "제약바이오"},
    "005380": {"price": 245000, "name": "현대차", "sector": "자동차"},
    "000270": {"price": 115000, "name": "기아", "sector": "자동차"},
    "005490": {"price": 360000, "name": "POSCO홀딩스", "sector": "철강"},
    "051910": {"price": 450000, "name": "LG화학", "sector": "화학"},
    "035420": {"price": 195000, "name": "NAVER", "sector": "IT서비스"},
    "006400": {"price": 390000, "name": "삼성SDI", "sector": "2차전지"},
    "068270": {"price": 175000, "name": "셀트리온", "sector": "제약바이오"},
    "105560": {"price": 78000, "name": "KB금융", "sector": "금융"},
    "055550": {"price": 45000, "name": "신한지주", "sector": "금융"},
    "035720": {"price": 49000, "name": "카카오", "sector": "IT서비스"},
    "012330": {"price": 230000, "name": "현대모비스", "sector": "자동차부품"},
    "000810": {"price": 310000, "name": "삼성화재", "sector": "보험"},
    "033780": {"price": 92000, "name": "KT&G", "sector": "담배/인삼"},
    "003550": {"price": 85000, "name": "LG", "sector": "지주사"},
    "066570": {"price": 105000, "name": "LG전자", "sector": "가전"},
    "015760": {"price": 21000, "name": "한국전력", "sector": "유틸리티"},
    "032830": {"price": 72000, "name": "삼성생명", "sector": "보험"},
    "003670": {"price": 260000, "name": "포스코퓨처엠", "sector": "2차전지"},
    "010130": {"price": 520000, "name": "고려아연", "sector": "비철금속"},
    "086790": {"price": 58000, "name": "하나금융지주", "sector": "금융"},
    "028260": {"price": 148000, "name": "삼성물산", "sector": "지주사"},
    "011780": {"price": 125000, "name": "금호석유", "sector": "화학"},
    "010950": {"price": 72000, "name": "S-Oil", "sector": "정유"},
    "009150": {"price": 155000, "name": "삼성전기", "sector": "전자부품"},
    "034730": {"price": 175000, "name": "SK", "sector": "지주사"},
    "018260": {"price": 155000, "name": "삼성SDS", "sector": "IT서비스"},
    "000100": {"price": 74000, "name": "유한양행", "sector": "제약바이오"},
    "036570": {"price": 190000, "name": "엔씨소프트", "sector": "게임"},
    "009540": {"price": 125000, "name": "HD한국조선해양", "sector": "조선"},
    "034220": {"price": 11000, "name": "LG디스플레이", "sector": "전자부품"},
    "017670": {"price": 52000, "name": "SK텔레콤", "sector": "통신"},
    "024110": {"price": 14500, "name": "기업은행", "sector": "금융"},
    "000720": {"price": 35000, "name": "현대건설", "sector": "건설"},
    "051900": {"price": 310000, "name": "LG생활건강", "sector": "화장품"},
    "011200": {"price": 18000, "name": "HMM", "sector": "해운"},
    "005940": {"price": 12500, "name": "NH투자증권", "sector": "금융"},
    "047050": {"price": 58000, "name": "포스코인터내셔널", "sector": "상사"},
    "251270": {"price": 55000, "name": "넷마블", "sector": "게임"},
    "021240": {"price": 58000, "name": "코웨이", "sector": "가전"},
    "001450": {"price": 32000, "name": "현대해상", "sector": "보험"},
    "000120": {"price": 118000, "name": "CJ대한통운", "sector": "물류"},
    "004020": {"price": 34000, "name": "현대제철", "sector": "철강"},
    "071050": {"price": 65000, "name": "한국금융지주", "sector": "금융"},
    "097950": {"price": 325000, "name": "CJ제일제당", "sector": "식품"},
    "006800": {"price": 9500, "name": "미래에셋증권", "sector": "금융"},
    "011070": {"price": 185000, "name": "LG이노텍", "sector": "전자부품"},
    "011170": {"price": 115000, "name": "롯데케미칼", "sector": "화학"},
    "007070": {"price": 22000, "name": "GS리테일", "sector": "유통"},
    "023530": {"price": 28000, "name": "롯데쇼핑", "sector": "유통"},
    "004800": {"price": 65000, "name": "효성", "sector": "지주사"},
    "000080": {"price": 21000, "name": "하이트진로", "sector": "주류"},
    "008770": {"price": 62000, "name": "호텔신라", "sector": "관광"},
    "128940": {"price": 315000, "name": "한미약품", "sector": "제약바이오"},
    "000990": {"price": 52000, "name": "DB하이텍", "sector": "반도체"},
    "090430": {"price": 170000, "name": "아모레퍼시픽", "sector": "화장품"},
    "064350": {"price": 38000, "name": "현대로템", "sector": "철도/방산"},
    "001040": {"price": 115000, "name": "CJ", "sector": "지주사"},
    "030200": {"price": 38000, "name": "KT", "sector": "통신"},
    "042660": {"price": 28000, "name": "한화오션", "sector": "조선"},
    "001740": {"price": 5200, "name": "SK네트웍스", "sector": "상사"},
    "005830": {"price": 95000, "name": "DB손해보험", "sector": "보험"},
    "010620": {"price": 68000, "name": "HD현대미포", "sector": "조선"},
    "039490": {"price": 128000, "name": "키움증권", "sector": "금융"},
    "002380": {"price": 215000, "name": "KCC", "sector": "화학/건자재"},
    "000210": {"price": 48000, "name": "DL", "sector": "지주사"},
    "000240": {"price": 15000, "name": "한국앤컴퍼니", "sector": "지주사"},

    # KOSDAQ Top 30
    "247540": {"price": 210000, "name": "에코프로비엠", "sector": "2차전지"},
    "086520": {"price": 560000, "name": "에코프로", "sector": "2차전지"},
    "068760": {"price": 95000, "name": "셀트리온제약", "sector": "제약바이오"},
    "263750": {"price": 55000, "name": "펄어비스", "sector": "게임"},
    "293480": {"price": 22000, "name": "카카오게임즈", "sector": "게임"},
    "028300": {"price": 115000, "name": "HLB", "sector": "제약바이오"},
    "112040": {"price": 45000, "name": "위메이드", "sector": "게임"},
    "035900": {"price": 68000, "name": "JYP Ent.", "sector": "엔터"},
    "253450": {"price": 82000, "name": "스튜디오드래곤", "sector": "엔터"},
    "058470": {"price": 215000, "name": "리노공업", "sector": "반도체"},
    "196170": {"price": 175000, "name": "알테오젠", "sector": "제약바이오"},
    "214150": {"price": 95000, "name": "클래시스", "sector": "의료기기"},
    "278280": {"price": 215000, "name": "천보", "sector": "2차전지"},
    "036930": {"price": 18000, "name": "주성엔지니어링", "sector": "반도체"},
    "041510": {"price": 78000, "name": "에스엠", "sector": "엔터"},
    "067310": {"price": 25000, "name": "하나마이크론", "sector": "반도체"},
    "145020": {"price": 185000, "name": "휴젤", "sector": "제약바이오"},
    "056190": {"price": 32000, "name": "에스에프에이", "sector": "장비"},
    "084990": {"price": 5200, "name": "헬릭스미스", "sector": "제약바이오"},
    "096530": {"price": 12500, "name": "씨젠", "sector": "의료기기"},
    "039030": {"price": 215000, "name": "이오테크닉스", "sector": "반도체"},
    "277810": {"price": 165000, "name": "레인보우로보틱스", "sector": "로봇"},
    "214430": {"price": 115000, "name": "파마리서치", "sector": "제약바이오"},
    "121600": {"price": 145000, "name": "나노신소재", "sector": "2차전지"},
    "034230": {"price": 13500, "name": "파라다이스", "sector": "관광"},
    "036810": {"price": 12000, "name": "에이치엘비제약", "sector": "제약바이오"},
    "053030": {"price": 15000, "name": "바이넥스", "sector": "제약바이오"},
    "089010": {"price": 35000, "name": "켐트로닉스", "sector": "화학"},
    "048410": {"price": 8500, "name": "현대바이오", "sector": "제약바이오"},
    "131970": {"price": 11000, "name": "테스나", "sector": "반도체"},

    # ETFs
    "069500": {"price": 35000, "name": "KODEX 200", "sector": "ETF-지수"},
    "122630": {"price": 21000, "name": "KODEX 레버리지", "sector": "ETF-지수"},
    "114800": {"price": 2500, "name": "KODEX 인버스", "sector": "ETF-지수"},
    "252670": {"price": 2000, "name": "KODEX 200선물인버스2X", "sector": "ETF-지수"},
    "229200": {"price": 15000, "name": "KODEX 코스닥150", "sector": "ETF-지수"},
    "233740": {"price": 12000, "name": "KODEX 코스닥150레버리지", "sector": "ETF-지수"},
    "251340": {"price": 3800, "name": "KODEX 코스닥150선물인버스", "sector": "ETF-지수"},
    "305720": {"price": 18000, "name": "TIGER 2차전지테마", "sector": "ETF-테마"},
    "277630": {"price": 18500, "name": "TIGER 200선물레버리지", "sector": "ETF-지수"},
    "152330": {"price": 102000, "name": "KODEX 국고채3년", "sector": "ETF-채권"},
    "272580": {"price": 108000, "name": "TIGER 단기채권액티브", "sector": "ETF-채권"},
    "261220": {"price": 15500, "name": "KODEX WTI원유선물(H)", "sector": "ETF-원자재"}
}

async def heartbeat():
    while True:
        try:
            r_secondary.set("heartbeat:price-generator", json.dumps({
                "status": "ACTIVE",
                "timestamp": datetime.now().isoformat(),
                "tickers_count": len(TICKERS_DATA)
            }), ex=10)
        except Exception as e:
            print(f"Heartbeat error: {e}")
        await asyncio.sleep(2)

async def generate_prices():
    # Clear existing ticker data to ensure domestic-only environment matching current TICKERS_DATA
    print("Cleaning up old ticker data from Redis...")
    for pattern in ["price:*", "base_price:*", "ticker_info:*"]:
        keys = r_primary.keys(pattern)
        if keys:
            r_primary.delete(*keys)
    
    # Clean secondary for candles
    keys = r_secondary.keys("candles:*")
    if keys:
        r_secondary.delete(*keys)
    
    for ticker, data in TICKERS_DATA.items():
        r_primary.set(f"base_price:{ticker}", data["price"])
        r_primary.set(f"ticker_info:{ticker}", json.dumps({
            "name": data["name"],
            "sector": data["sector"],
            "productCode": "200" if data["sector"].startswith("ETF") else "100"
        }))
        initial_data = {
            "ticker": ticker,
            "price": data["price"],
            "change_percent": 0.0
        }
        r_primary.set(f"price:{ticker}", json.dumps(initial_data))
        r_primary.publish("market_prices", json.dumps(initial_data))

        # Seed initial candles (50 points)
        for interval, duration in [("1m", 60), ("1h", 3600), ("1d", 86400)]:
            now = int(datetime.now().timestamp())
            base_t = (now // duration) * duration
            candles = []
            current_price = data["price"]
            for i in range(50):
                t = base_t - (50 - i) * duration
                # Add some random walk
                change = random.uniform(-0.005, 0.005)
                open_p = current_price
                close_p = int(open_p * (1 + change))
                high_p = max(open_p, close_p) + random.randint(0, 100)
                low_p = min(open_p, close_p) - random.randint(0, 100)
                
                candle = {
                    "timestamp": t * 1000,
                    "open": float(open_p),
                    "high": float(high_p),
                    "low": float(low_p),
                    "close": float(close_p),
                    "volume": random.randint(100, 1000)
                }
                candles.append(json.dumps(candle))
                current_price = close_p
            
            key = f"candles:{ticker}:{interval}"
            r_secondary.delete(key)
            r_secondary.rpush(key, *candles)

    print("Market prices and candles initialized. Heartbeat active.")
    await heartbeat()

if __name__ == "__main__":
    asyncio.run(generate_prices())
