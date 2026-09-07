import asyncio
import json
import logging
import os
import time
from datetime import datetime
import aiohttp
import pytz
import redis.asyncio as aioredis
from fastapi import FastAPI
from fastapi.responses import HTMLResponse, JSONResponse
import uvicorn

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(name)s: %(message)s")
logger = logging.getLogger("trade-verifier")

REDIS_PRIMARY_HOST = os.getenv("REDIS_PRIMARY_HOST", "redis-primary")
REDIS_PORT = int(os.getenv("REDIS_PORT", 6379))
TRADING_SERVER_URL = os.getenv("TRADING_SERVER_URL", "http://trading-server:8001")
ACCOUNT_SERVER_URL = os.getenv("ACCOUNT_SERVER_URL", "http://account-server:8000")
PORT = int(os.getenv("VERIFIER_PORT", 8002))

KST = pytz.timezone("Asia/Seoul")

metrics = {
    "start_time": time.time(),
    "total_trades_captured": 0,
    "recent_trades": [],
    "trade_history_1m": [],
    "last_trade_time": None,
    "last_trade_info": None,
    "synthetic_test": {
        "last_run": None,
        "status": "PENDING",
        "latency_ms": 0.0,
        "details": "",
        "order_book_status": "UNKNOWN"
    },
    "health_status": "STARTING"
}

app = FastAPI(title="MTS Trade Verifier")
r_primary = None

async def init_redis():
    global r_primary
    while r_primary is None:
        try:
            r_primary = aioredis.Redis(host=REDIS_PRIMARY_HOST, port=REDIS_PORT, db=0, decode_responses=True)
            await r_primary.ping()
            logger.info(f"Connected to Redis at {REDIS_PRIMARY_HOST}:{REDIS_PORT}")
        except Exception as e:
            logger.warning(f"Waiting for Redis connection ({e})... retrying in 2s")
            r_primary = None
            await asyncio.sleep(2)

async def listen_redis_trades():
    """Subscribe to Redis 'trade_updates' channel to record real-time trade executions from trading-server"""
    while True:
        try:
            if not r_primary:
                await asyncio.sleep(1)
                continue
            pubsub = r_primary.pubsub()
            await pubsub.subscribe("trade_updates")
            logger.info("Subscribed to Redis channel: trade_updates")
            
            async for message in pubsub.listen():
                if message and message.get("type") == "message":
                    try:
                        raw_data = message.get("data")
                        if isinstance(raw_data, bytes):
                            raw_data = raw_data.decode("utf-8")
                        data = json.loads(raw_data)
                        now = time.time()
                        metrics["total_trades_captured"] += 1
                        metrics["last_trade_time"] = now
                        metrics["last_trade_info"] = data
                        
                        metrics["recent_trades"].insert(0, {
                            "time": datetime.now(KST).strftime("%H:%M:%S.%f")[:-3],
                            "ticker": data.get("ticker", "-"),
                            "price": data.get("price", 0),
                            "quantity": data.get("quantity", 0),
                            "buyerId": data.get("buyerId", "-"),
                            "sellerId": data.get("sellerId", "-")
                        })
                        if len(metrics["recent_trades"]) > 50:
                            metrics["recent_trades"].pop()
                        
                        metrics["trade_history_1m"].append(now)
                    except Exception as e:
                        logger.error(f"Error parsing trade_updates message: {e}")
        except Exception as e:
            logger.error(f"Redis pubsub error ({e}). Reconnecting in 3s...")
            await asyncio.sleep(3)

async def run_synthetic_trade_check():
    """Periodically test order placement and order book endpoints on trading-server"""
    await asyncio.sleep(3)
    async with aiohttp.ClientSession() as session:
        while True:
            try:
                start_t = time.time()
                headers = {"X-Internal-Secret": "mts-simulation-secret"}
                
                test_ticker = "005930"
                try:
                    async with session.get(f"{TRADING_SERVER_URL}/order/book/{test_ticker}", timeout=aiohttp.ClientTimeout(total=5)) as ob_resp:
                        if ob_resp.status == 200:
                            metrics["synthetic_test"]["order_book_status"] = "OK"
                        else:
                            metrics["synthetic_test"]["order_book_status"] = f"HTTP {ob_resp.status}"
                except Exception as e:
                    metrics["synthetic_test"]["order_book_status"] = f"ERR: {e}"

                payload = {
                    "ticker": "TEST_VERIFY",
                    "quantity": 1,
                    "price": 10.0,
                    "side": "BUY",
                    "user_id": 1
                }
                async with session.post(f"{TRADING_SERVER_URL}/order", json=payload, headers=headers, timeout=aiohttp.ClientTimeout(total=5)) as order_resp:
                    latency = (time.time() - start_t) * 1000.0
                    metrics["synthetic_test"]["latency_ms"] = round(latency, 2)
                    metrics["synthetic_test"]["last_run"] = datetime.now(KST).strftime("%Y-%m-%d %H:%M:%S")
                    
                    if order_resp.status == 200:
                        res_data = await order_resp.json()
                        status_msg = res_data.get("status", "")
                        if status_msg in ["Order Processed", "Rejected"]:
                            metrics["synthetic_test"]["status"] = "PASSED"
                            metrics["synthetic_test"]["details"] = f"Trading Server responded '{status_msg}' in {round(latency, 1)}ms"
                        else:
                            metrics["synthetic_test"]["status"] = "DEGRADED"
                            metrics["synthetic_test"]["details"] = f"Unexpected response status: {status_msg}"
                    else:
                        metrics["synthetic_test"]["status"] = "FAILED"
                        metrics["synthetic_test"]["details"] = f"Trading Server HTTP {order_resp.status}"
                        
            except Exception as e:
                metrics["synthetic_test"]["status"] = "FAILED"
                metrics["synthetic_test"]["details"] = f"Connection error: {e}"
                metrics["synthetic_test"]["last_run"] = datetime.now(KST).strftime("%Y-%m-%d %H:%M:%S")
            
            await asyncio.sleep(15)

async def heartbeat_and_metrics_loop():
    """Clean trade history, evaluate overall health, log summary, push heartbeat to Redis"""
    while True:
        try:
            now = time.time()
            metrics["trade_history_1m"] = [t for t in metrics["trade_history_1m"] if now - t <= 60]
            tpm = len(metrics["trade_history_1m"])
            
            synth_ok = metrics["synthetic_test"]["status"] == "PASSED"
            if synth_ok:
                metrics["health_status"] = "HEALTHY"
            else:
                metrics["health_status"] = "DEGRADED" if tpm > 0 else "UNHEALTHY"
            
            if r_primary:
                hb_data = {
                    "timestamp": datetime.now(KST).strftime("%Y-%m-%d %H:%M:%S"),
                    "status": metrics["health_status"],
                    "tpm": tpm,
                    "total_trades": metrics["total_trades_captured"],
                    "latency_ms": metrics["synthetic_test"]["latency_ms"]
                }
                await r_primary.set("heartbeat:trade-verifier", json.dumps(hb_data), ex=30)
                
            logger.info(
                f"[TRADE VERIFIER] Status: {metrics['health_status']} | "
                f"Trades/Min: {tpm} | Total Captured: {metrics['total_trades_captured']} | "
                f"Synth Test: {metrics['synthetic_test']['status']} ({metrics['synthetic_test']['latency_ms']}ms)"
            )
        except Exception as e:
            logger.error(f"Error in heartbeat loop: {e}")
            
        await asyncio.sleep(5)

@app.on_event("startup")
async def startup_event():
    await init_redis()
    asyncio.create_task(listen_redis_trades())
    asyncio.create_task(run_synthetic_trade_check())
    asyncio.create_task(heartbeat_and_metrics_loop())

@app.get("/health")
async def health_check():
    status_code = 200 if metrics["health_status"] in ["HEALTHY", "DEGRADED"] else 503
    return JSONResponse(status_code=status_code, content={"status": metrics["health_status"]})

@app.get("/api/status")
async def api_status():
    now = time.time()
    tpm = len([t for t in metrics["trade_history_1m"] if now - t <= 60])
    return {
        "status": metrics["health_status"],
        "uptime_seconds": round(now - metrics["start_time"]),
        "trading_metrics": {
            "total_trades_captured": metrics["total_trades_captured"],
            "trades_per_minute": tpm,
            "last_trade_time": datetime.fromtimestamp(metrics["last_trade_time"], KST).strftime("%Y-%m-%d %H:%M:%S") if metrics["last_trade_time"] else None,
            "last_trade_info": metrics["last_trade_info"]
        },
        "synthetic_test": metrics["synthetic_test"],
        "recent_trades": metrics["recent_trades"][:15]
    }

HTML_TEMPLATE = """<!DOCTYPE html>
<html lang="ko">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>MTS Trade Execution Verifier Dashboard</title>
    <style>
        :root {
            --bg-color: #0f172a;
            --card-bg: #1e293b;
            --text-main: #f8fafc;
            --text-muted: #94a3b8;
            --accent-green: #10b981;
            --accent-yellow: #f59e0b;
            --accent-red: #ef4444;
            --accent-blue: #3b82f6;
            --border-color: #334155;
        }
        body {
            font-family: 'Segoe UI', system-ui, -apple-system, sans-serif;
            background-color: var(--bg-color);
            color: var(--text-main);
            margin: 0;
            padding: 24px;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
        }
        .header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding-bottom: 20px;
            border-bottom: 1px solid var(--border-color);
            margin-bottom: 24px;
        }
        .header h1 {
            margin: 0;
            font-size: 24px;
            font-weight: 600;
            display: flex;
            align-items: center;
            gap: 12px;
        }
        .badge {
            padding: 6px 16px;
            border-radius: 20px;
            font-weight: 700;
            font-size: 14px;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        .badge-healthy { background: rgba(16, 185, 129, 0.2); color: var(--accent-green); border: 1px solid var(--accent-green); }
        .badge-degraded { background: rgba(245, 158, 11, 0.2); color: var(--accent-yellow); border: 1px solid var(--accent-yellow); }
        .badge-unhealthy { background: rgba(239, 68, 68, 0.2); color: var(--accent-red); border: 1px solid var(--accent-red); }
        
        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-bottom: 24px;
        }
        .card {
            background: var(--card-bg);
            border: 1px solid var(--border-color);
            border-radius: 12px;
            padding: 20px;
        }
        .card-title {
            color: var(--text-muted);
            font-size: 13px;
            font-weight: 600;
            text-transform: uppercase;
            margin-bottom: 8px;
        }
        .card-value {
            font-size: 28px;
            font-weight: 700;
            margin-bottom: 4px;
        }
        .card-sub {
            font-size: 13px;
            color: var(--text-muted);
        }

        .section-title {
            font-size: 18px;
            font-weight: 600;
            margin-bottom: 16px;
            display: flex;
            align-items: center;
            gap: 8px;
        }

        table {
            width: 100%;
            border-collapse: collapse;
            background: var(--card-bg);
            border-radius: 12px;
            overflow: hidden;
            border: 1px solid var(--border-color);
        }
        th, td {
            padding: 12px 16px;
            text-align: left;
            border-bottom: 1px solid var(--border-color);
            font-size: 14px;
        }
        th {
            background: #162032;
            color: var(--text-muted);
            font-weight: 600;
            font-size: 12px;
            text-transform: uppercase;
        }
        tr:hover {
            background: rgba(255, 255, 255, 0.03);
        }
        .tag-buy { color: var(--accent-green); font-weight: 600; }
        .tag-sell { color: var(--accent-red); font-weight: 600; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>⚡ MTS Trading Execution Verifier</h1>
            <div id="statusBadge" class="badge badge-healthy">HEALTHY</div>
        </div>

        <div class="grid">
            <div class="card">
                <div class="card-title">Real-time Trade Rate</div>
                <div class="card-value" id="tpmVal">0</div>
                <div class="card-sub">Executed Trades in Last 60s</div>
            </div>
            <div class="card">
                <div class="card-title">Total Trades Captured</div>
                <div class="card-value" id="totalTradesVal">0</div>
                <div class="card-sub" id="lastTradeTime">No trades yet</div>
            </div>
            <div class="card">
                <div class="card-title">E2E Order API Test</div>
                <div class="card-value" id="synthStatusVal">PENDING</div>
                <div class="card-sub" id="synthLatencyVal">Latency: 0ms</div>
            </div>
            <div class="card">
                <div class="card-title">OrderBook Service</div>
                <div class="card-value" id="obStatusVal">UNKNOWN</div>
                <div class="card-sub">Endpoint Check</div>
            </div>
        </div>

        <div class="section-title">📊 Live Executed Trades Stream (Redis pub/sub)</div>
        <table>
            <thead>
                <tr>
                    <th>Time</th>
                    <th>Ticker</th>
                    <th>Price</th>
                    <th>Qty</th>
                    <th>Buyer ID</th>
                    <th>Seller ID</th>
                </tr>
            </thead>
            <tbody id="tradeTableBody">
                <tr><td colspan="6" style="text-align:center; color: var(--text-muted);">Waiting for live trade executions...</td></tr>
            </tbody>
        </table>
    </div>

    <script>
        async function updateDashboard() {
            try {
                const res = await fetch('/api/status');
                const data = await res.json();

                const badge = document.getElementById('statusBadge');
                badge.innerText = data.status;
                badge.className = 'badge badge-' + data.status.toLowerCase();

                document.getElementById('tpmVal').innerText = data.trading_metrics.trades_per_minute;
                document.getElementById('totalTradesVal').innerText = data.trading_metrics.total_trades_captured.toLocaleString();
                document.getElementById('lastTradeTime').innerText = data.trading_metrics.last_trade_time ? 'Last trade: ' + data.trading_metrics.last_trade_time : 'No recent trades';

                document.getElementById('synthStatusVal').innerText = data.synthetic_test.status;
                document.getElementById('synthStatusVal').style.color = data.synthetic_test.status === 'PASSED' ? '#10b981' : '#ef4444';
                document.getElementById('synthLatencyVal').innerText = 'Latency: ' + data.synthetic_test.latency_ms + ' ms';

                document.getElementById('obStatusVal').innerText = data.synthetic_test.order_book_status;

                const tbody = document.getElementById('tradeTableBody');
                if (data.recent_trades && data.recent_trades.length > 0) {
                    tbody.innerHTML = data.recent_trades.map(t => `
                        <tr>
                            <td>${t.time}</td>
                            <td><strong>${t.ticker}</strong></td>
                            <td>${typeof t.price === 'number' ? t.price.toLocaleString() : t.price}</td>
                            <td>${t.quantity}</td>
                            <td>User #${t.buyerId}</td>
                            <td>User #${t.sellerId}</td>
                        </tr>
                    `).join('');
                }
            } catch (err) {
                console.error('Failed to fetch status:', err);
            }
        }

        setInterval(updateDashboard, 2000);
        updateDashboard();
    </script>
</body>
</html>
"""

@app.get("/", response_class=HTMLResponse)
async def html_dashboard():
    return HTML_TEMPLATE

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=PORT)
