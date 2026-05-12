import random
import asyncio
import redis
import json
import os
from datetime import datetime
from dotenv import load_dotenv

load_dotenv()

r_primary_host = os.getenv('REDIS_PRIMARY_HOST', 'localhost')
r_secondary_host = os.getenv('REDIS_SECONDARY_HOST', 'localhost')
r_primary = redis.Redis(host=r_primary_host, port=6379, db=0)
r_secondary = redis.Redis(host=r_secondary_host, port=6379, db=0)

# Real-world Tickers (Top 100+ Korean Stocks)
REAL_COMPANIES = [
    ("005930", "삼성전자", "반도체"), ("000660", "SK하이닉스", "반도체"), ("373220", "LG에너지솔루션", "2차전지"),
    ("207940", "삼성바이오로직스", "바이오"), ("005380", "현대차", "자동차"), ("000270", "기아", "자동차"),
    ("005490", "POSCO홀딩스", "철강"), ("051910", "LG화학", "화학"), ("035420", "NAVER", "인터넷"),
    ("006400", "삼성SDI", "2차전지"), ("068270", "셀트리온", "바이오"), ("105560", "KB금융", "금융"),
    ("055550", "신한지주", "금융"), ("035720", "카카오", "인터넷"), ("012330", "현대모비스", "자동차부품"),
    ("000810", "삼성화재", "보험"), ("033780", "KT&G", "식품"), ("003550", "LG", "지주사"),
    ("066570", "LG전자", "가전"), ("015760", "한국전력", "유틸리티"), ("032830", "삼성생명", "보험"),
    ("003670", "포스코퓨처엠", "2차전지"), ("010130", "고려아연", "금속"), ("086790", "하나금융지주", "금융"),
    ("028260", "삼성물산", "상사"), ("011780", "금호석유", "화학"), ("010950", "S-Oil", "정유"),
    ("009150", "삼성전기", "부품"), ("034730", "SK", "지주사"), ("018260", "삼성SDS", "IT서비스"),
    ("000100", "유한양행", "제약"), ("036570", "엔씨소프트", "게임"), ("009540", "HD한국조선해양", "조선"),
    ("034220", "LG디스플레이", "디스플레이"), ("017670", "SK텔레콤", "통신"), ("024110", "기업은행", "금융"),
    ("000720", "현대건설", "건설"), ("051900", "LG생활건강", "화장품"), ("011200", "HMM", "해운"),
    ("005940", "NH투자증권", "금융"), ("047050", "포스코인터내셔널", "상사"), ("251270", "넷마블", "게임"),
    ("021240", "코웨이", "가전"), ("001450", "현대해상", "보험"), ("000120", "CJ대한통운", "물류"),
    ("004020", "현대제철", "철강"), ("071050", "한국금융지주", "금융"), ("097950", "CJ제일제당", "식품"),
    ("006800", "미래에셋증권", "금융"), ("011070", "LG이노텍", "부품"), ("011170", "롯데케미칼", "화학"),
    ("007070", "GS리테일", "유통"), ("023530", "롯데쇼핑", "유통"), ("004800", "효성", "지주사"),
    ("000080", "하이트진로", "식품"), ("008770", "호텔신라", "관광"), ("128940", "한미약품", "바이오"),
    ("000990", "DB하이텍", "반도체"), ("090430", "아모레퍼시픽", "화장품"), ("064350", "현대로템", "기계"),
    ("001040", "CJ", "지주사"), ("030200", "KT", "통신"), ("042660", "한화오션", "조선"),
    ("001740", "SK네트웍스", "상사"), ("005830", "DB손해보험", "보험"), ("010620", "HD현대미포", "조선"),
    ("039490", "키움증권", "금융"), ("002380", "KCC", "화학"), ("000210", "DL", "지주사"),
    ("000240", "한국앤컴퍼니", "지주사"), ("247540", "에코프로비엠", "2차전지"), ("086520", "에코프로", "2차전지"),
    ("068760", "셀트리온제약", "바이오"), ("263750", "펄어비스", "게임"), ("293480", "카카오게임즈", "게임"),
    ("028300", "HLB", "바이오"), ("112040", "위메이드", "게임"), ("035900", "JYP Ent.", "엔터"),
    ("253450", "스튜디오드래곤", "엔터"), ("058470", "리노공업", "반도체"), ("196170", "알테오젠", "바이오"),
    ("214150", "클래시스", "의료기기"), ("278280", "천보", "화학"), ("036930", "주성엔지니어링", "반도체"),
    ("041510", "에스엠", "엔터"), ("067310", "하나마이크론", "반도체"), ("145020", "휴젤", "바이오"),
    ("056190", "에스에프에이", "기계"), ("084990", "헬릭스미스", "바이오"), ("096530", "씨젠", "의료기기"),
    ("039030", "이오테크닉스", "반도체"), ("277810", "레인보우로보틱스", "로봇"), ("214430", "파마리서치", "바이오"),
    ("121600", "나노신소재", "2차전지"), ("034230", "파라다이스", "관광"), ("036810", "에이치엘비제약", "바이오"),
    ("053030", "바이넥스", "바이오"), ("089010", "켐트로닉스", "화학"), ("048410", "현대바이오", "바이오"),
    ("131970", "테스나", "반도체"), ("069500", "KODEX 200", "ETF"), ("122630", "KODEX 레버리지", "ETF"),
    ("114800", "KODEX 인버스", "ETF"), ("252670", "KODEX 200선물인버스2X", "ETF"),
    ("229200", "코스닥150", "ETF"), ("233740", "코스닥150 레버리지", "ETF"), ("251340", "코스닥150 인버스", "ETF"),
    ("305720", "KODEX 2차전지산업", "ETF"), ("277630", "TIGER 2차전지테마", "ETF"), ("152330", "KODEX 국고채3년", "ETF"),
    ("272580", "TIGER 단기채권액티브", "ETF"), ("261220", "KODEX 미국달러선물레버리지", "ETF")
]

INDUSTRY_MAP = {
    "IT/기술": ["테크", "시스템", "솔루션", "디지털", "데이터", "네트웍스", "소프트"],
    "바이오": ["신약", "메디", "사이언스", "생명", "제약", "백신", "헬스케어"],
    "금융": ["인베스트", "파트너스", "캐피탈", "증권", "금융지주", "자산운용"],
    "에너지/화학": ["이노베이션", "그린", "에너지", "화학", "퓨얼셀", "케미칼"],
    "소비재": ["식품", "생활", "리테일", "상사", "패션", "뷰티"],
    "반도체": ["반도체", "하이테크", "칩스", "나노", "일렉트릭", "마이크로"],
}

# Use a fixed seed for deterministic generation of the 1000 tickers
random.seed(42)

TICKERS_DATA = {}
for code, name, sector in REAL_COMPANIES:
    TICKERS_DATA[code] = {"price": random.randint(100, 5000) * 100, "name": name, "sector": sector}

used_names = set(name for _, name, _ in REAL_COMPANIES)
prefixes = ["한국", "대한", "글로벌", "미래", "한화", "금강", "동양", "중앙", "태양", "대성", "일진", "성우", "아진"]
suffixes = ["산업", "물산", "상사", "개발", "홀딩스", "기계", "금속", "정밀", "화학", "유통", "건설", "금업"]

# Generate deterministic tickers for the remaining slots (matching DataInitializer.kt pattern 99xxxx)
for i in range(1, 1001):
    if len(TICKERS_DATA) >= 1000:
        break
    
    # Try to generate a realistic name
    sec = random.choice(list(INDUSTRY_MAP.keys()))
    kw = random.choice(INDUSTRY_MAP[sec])
    pre = random.choice(prefixes)
    suf = random.choice(suffixes)
    
    dice = random.random()
    if dice < 0.3: name = f"{pre}{kw}"
    elif dice < 0.6: name = f"{kw}{suf}"
    else: name = f"{pre}{kw}{suf}"
    
    if name in used_names:
        name = f"{name}_{i}" # Ensure uniqueness if needed
    
    code = f"99{i:04d}" # Fixed pattern 990001, 990002... to match DataInitializer.kt
    if code not in TICKERS_DATA:
        TICKERS_DATA[code] = {
            "price": random.randint(50, 2000) * 100,
            "name": name,
            "sector": sec
        }
        used_names.add(name)

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
    print(f"Initializing {len(TICKERS_DATA)} tickers (Strictly Deterministic & Trade-Driven)...")
    
    pipe_primary = r_primary.pipeline()
    pipe_secondary = r_secondary.pipeline()
    
    # 1. Complete Cleanup of ALL potential ticker patterns
    print("Performing complete cleanup of old Redis data...")
    # Clean up everything to ensure NO mock data remains
    for pattern in ["price:*", "base_price:*", "ticker_info:*", "orderbook:*"]:
        keys = r_primary.keys(pattern)
        if keys:
            print(f"Deleting {len(keys)} keys for pattern {pattern}")
            pipe_primary.delete(*keys)
    
    keys = r_secondary.keys("candles:*")
    if keys:
        print(f"Deleting {len(keys)} candle keys")
        pipe_secondary.delete(*keys)
        
    pipe_primary.execute()
    pipe_secondary.execute()

    # 2. Seed Data
    print("Seeding deterministic ticker info and base prices...")
    for ticker, data in TICKERS_DATA.items():
        base_p = data["price"]
        pipe_primary.set(f"base_price:{ticker}", base_p)
        pipe_primary.set(f"ticker_info:{ticker}", json.dumps({
            "name": data["name"],
            "sector": data["sector"],
            "productCode": "200" if data["sector"].startswith("ETF") else "100"
        }))
        
        initial_data = {
            "ticker": ticker,
            "price": base_p,
            "change_percent": 0.0,
            "timestamp": int(datetime.now().timestamp() * 1000)
        }
        pipe_primary.set(f"price:{ticker}", json.dumps(initial_data))
        
        # Seed initial candles
        for interval, duration in [("1m", 60), ("1h", 3600), ("1d", 86400)]:
            now = int(datetime.now().timestamp())
            base_t = (now // duration) * duration
            candles = []
            for i in range(30):
                t = base_t - (30 - i) * duration
                candles.append(json.dumps({
                    "timestamp": t * 1000, "open": float(base_p), "high": float(base_p),
                    "low": float(base_p), "close": float(base_p), "volume": 0
                }))
            pipe_secondary.rpush(f"candles:{ticker}:{interval}", *candles)
            
        if len(pipe_primary) > 100:
            pipe_primary.execute()
            pipe_secondary.execute()

    pipe_primary.execute()
    pipe_secondary.execute()
    print(f"Successfully seeded {len(TICKERS_DATA)} tickers.")

    # 3. Start Heartbeat
    await asyncio.gather(heartbeat())

if __name__ == "__main__":
    asyncio.run(generate_prices())
