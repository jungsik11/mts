from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from . import models, auth, database
from pydantic import BaseModel
from typing import List

app = FastAPI(title="MTS Account Server")

# Create tables
models.Base.metadata.create_all(bind=database.engine)

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="login")

class UserCreate(BaseModel):
    username: str
    password: str
    email: str

class UserResponse(BaseModel):
    username: str
    email: str
    class Config:
        from_attributes = True

@app.post("/signup", response_model=UserResponse)
def signup(user: UserCreate, db: Session = Depends(database.get_db)):
    db_user = db.query(models.User).filter(models.User.username == user.username).first()
    if db_user:
        raise HTTPException(status_code=400, detail="Username already registered")
    
    hashed_pwd = auth.get_password_hash(user.password)
    new_user = models.User(username=user.username, hashed_password=hashed_pwd, email=user.email)
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    return new_user

@app.post("/login")
def login(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(database.get_db)):
    user = db.query(models.User).filter(models.User.username == form_data.username).first()
    if not user or not auth.verify_password(form_data.password, user.hashed_password):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Incorrect username or password")
    
    access_token = auth.create_access_token(data={"sub": user.username})
    return {"access_token": access_token, "token_type": "bearer"}

@app.get("/me", response_model=UserResponse)
def get_me(token: str = Depends(oauth2_scheme), db: Session = Depends(database.get_db)):
    try:
        payload = auth.jwt.decode(token, auth.SECRET_KEY, algorithms=[auth.ALGORITHM])
        username: str = payload.get("sub")
        if username is None:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
    except auth.JWTError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
    
    user = db.query(models.User).filter(models.User.username == username).first()
    return user

@app.get("/assets")
def get_assets(token: str = Depends(oauth2_scheme), db: Session = Depends(database.get_db)):
    user = get_me(token, db)
    assets = db.query(models.Asset).filter(models.Asset.user_id == user.id).all()
    return assets

class SettlementRequest(BaseModel):
    buyer_id: int
    seller_id: int
    ticker: str
    price: float
    quantity: float

class MarginCheckRequest(BaseModel):
    user_id: int
    ticker: str
    side: str
    price: float
    quantity: float

@app.post("/internal/margin-check")
def margin_check(req: MarginCheckRequest, db: Session = Depends(database.get_db)):
    user = db.query(models.User).filter(models.User.id == req.user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    if req.side == "BUY":
        total_cost = req.price * req.quantity
        if user.cash_balance < total_cost:
            return {"allowed": False, "reason": "Insufficient cash balance"}
    else: # SELL
        asset = db.query(models.Asset).filter(
            models.Asset.user_id == req.user_id,
            models.Asset.ticker == req.ticker
        ).first()
        if not asset or asset.quantity < req.quantity:
            return {"allowed": False, "reason": "Insufficient stock holdings"}
    
    return {"allowed": True}

@app.post("/internal/settle")
def settle_trade(req: SettlementRequest, db: Session = Depends(database.get_db)):
    # 1. Update Buyer
    buyer = db.query(models.User).filter(models.User.id == req.buyer_id).first()
    total_cost = req.price * req.quantity
    if buyer.cash_balance < total_cost:
        raise HTTPException(status_code=400, detail="Buyer insufficient funds")
    buyer.cash_balance -= total_cost

    # Update Buyer Holdings
    buyer_asset = db.query(models.Asset).filter(
        models.Asset.user_id == req.buyer_id, 
        models.Asset.ticker == req.ticker
    ).first()
    if buyer_asset:
        new_total_qty = buyer_asset.quantity + req.quantity
        buyer_asset.avg_price = ((buyer_asset.avg_price * buyer_asset.quantity) + total_cost) / new_total_qty
        buyer_asset.quantity = new_total_qty
    else:
        new_asset = models.Asset(user_id=req.buyer_id, ticker=req.ticker, quantity=req.quantity, avg_price=req.price)
        db.add(new_asset)

    # 2. Update Seller
    seller = db.query(models.User).filter(models.User.id == req.seller_id).first()
    seller.cash_balance += total_cost

    # Update Seller Holdings
    seller_asset = db.query(models.Asset).filter(
        models.Asset.user_id == req.seller_id, 
        models.Asset.ticker == req.ticker
    ).first()
    if not seller_asset or seller_asset.quantity < req.quantity:
        raise HTTPException(status_code=400, detail="Seller insufficient stock")
    seller_asset.quantity -= req.quantity

    # 3. Log History
    history_buy = models.TransactionHistory(user_id=req.buyer_id, ticker=req.ticker, transaction_type="BUY", quantity=req.quantity, price=req.price)
    history_sell = models.TransactionHistory(user_id=req.seller_id, ticker=req.ticker, transaction_type="SELL", quantity=req.quantity, price=req.price)
    db.add(history_buy)
    db.add(history_sell)

    db.commit()
    return {"status": "settled"}
