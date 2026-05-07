from fastapi import FastAPI, HTTPException, WebSocket, WebSocketDisconnect
import asyncio
import requests
from .matching_engine import get_order_book, Order
from pydantic import BaseModel
import redis.asyncio as redis # Use async redis
import json

app = FastAPI(title="MTS Matching Server")
r = redis.Redis(host='localhost', port=6379, db=0, decode_responses=True)

LEDGER_URL = "http://localhost:8000"

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    pubsub = r.pubsub()
    await pubsub.subscribe("market_prices", "trade_updates")
    
    try:
        while True:
            # Check for new messages from Redis
            message = await pubsub.get_message(ignore_subscribe_in_init=True)
            if message:
                await websocket.send_text(json.dumps({
                    "channel": message['channel'],
                    "data": json.loads(message['data'])
                }))
            await asyncio.sleep(0.01) # Small sleep to prevent CPU hogging
    except WebSocketDisconnect:
        await pubsub.unsubscribe("market_prices", "trade_updates")
    except Exception as e:
        print(f"WS Error: {e}")

class OrderRequest(BaseModel):
    user_id: int
    ticker: str
    quantity: int
    price: int
    side: str # BUY / SELL

@app.post("/order")
async def place_order(req: OrderRequest):
    # 1. Margin Check
    try:
        margin_res = requests.post(
            f"{LEDGER_URL}/internal/margin-check",
            json={
                "user_id": req.user_id,
                "ticker": req.ticker,
                "side": req.side,
                "price": req.price,
                "quantity": req.quantity
            }
        )
        margin_data = margin_res.json()
        if not margin_data.get("allowed", False):
            return {"status": "Rejected", "reason": margin_data.get("reason", "Margin check failed")}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Margin check server error: {e}")

    # 2. Add to Matching Engine
    order = Order(
        order_id="mock_id", 
        user_id=req.user_id,
        ticker=req.ticker,
        side=req.side,
        price=req.price,
        quantity=req.quantity
    )
    
    book = get_order_book(req.ticker)
    matches = book.add_order(order)
    
    # 3. Process Settlements
    settled_matches = []
    for match in matches:
        try:
            res = requests.post(f"{LEDGER_URL}/internal/settle", json=match)
            if res.status_code == 200:
                settled_matches.append(match)
                # Broadcast match via Redis
                await r.publish("trade_updates", json.dumps(match))
            else:
                print(f"Settlement failed: {res.text}")
        except Exception as e:
            print(f"Settlement error: {e}")
            
    return {
        "status": "Order Processed",
        "matches": settled_matches,
        "remaining_qty": order.quantity
    }

@app.get("/orderbook/{ticker}")
async def get_book(ticker: str):
    book = get_order_book(ticker)
    return {
        "buys": [{"price": abs(p), "qty": o.quantity} for p, o in book.buys[:10]],
        "sells": [{"price": p, "qty": o.quantity} for p, o in book.sells[:10]]
    }
