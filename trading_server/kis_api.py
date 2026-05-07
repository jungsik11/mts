import requests
import json
from .config import settings
import redis

# Redis for token caching
r = redis.Redis(host='localhost', port=6379, db=0)

class KISClient:
    def __init__(self):
        self.base_url = settings.KIS_URL
        self.appkey = settings.KIS_APPKEY
        self.secret = settings.KIS_SECRET

    def get_access_token(self):
        # Check Redis first
        token = r.get("kis_access_token")
        if token:
            return token.decode('utf-8')

        url = f"{self.base_url}/oauth2/tokenP"
        body = {
            "grant_type": "client_credentials",
            "appkey": self.appkey,
            "secretkey": self.secret
        }
        res = requests.post(url, data=json.dumps(body))
        if res.status_code == 200:
            token = res.json()["access_token"]
            expires_in = res.json()["expires_in"]
            # Cache in Redis
            r.setex("kis_access_token", expires_in - 60, token)
            return token
        else:
            raise Exception(f"Failed to get KIS access token: {res.text}")

    def get_current_price(self, ticker: str):
        token = self.get_access_token()
        url = f"{self.base_url}/uapi/domestic-stock/v1/quotations/inquire-price"
        headers = {
            "Content-Type": "application/json",
            "authorization": f"Bearer {token}",
            "appkey": self.appkey,
            "appsecret": self.secret,
            "tr_id": "FHKST01010100" # Current price
        }
        params = {
            "fid_cond_mrkt_div_code": "J",
            "fid_input_iscd": ticker
        }
        res = requests.get(url, headers=headers, params=params)
        return res.json()

    def place_order(self, ticker: str, quantity: int, price: int, side: str = "BUY"):
        token = self.get_access_token()
        # Side: BUY (VTTC8434U), SELL (VTTC8433U) - Sandbox/Real IDs vary
        tr_id = "TTTC0802U" if side == "BUY" else "TTTC0801U" # Example Real IDs
        
        url = f"{self.base_url}/uapi/domestic-stock/v1/trading/order-cash"
        headers = {
            "Content-Type": "application/json",
            "authorization": f"Bearer {token}",
            "appkey": self.appkey,
            "appsecret": self.secret,
            "tr_id": tr_id
        }
        # Account formatting (assuming KIS_ACCOUNT is 74712017-01 format)
        acc_no, acc_code = settings.KIS_ACCOUNT.split("-")
        
        body = {
            "CANO": acc_no,
            "ACNT_PRDT_CD": acc_code,
            "PDNO": ticker,
            "ORD_DVSN": "00", # Limit order
            "ORD_QTY": str(quantity),
            "ORD_UNPR": str(price)
        }
        res = requests.post(url, headers=headers, data=json.dumps(body))
        return res.json()
