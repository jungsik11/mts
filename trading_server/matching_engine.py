import bisect
import uuid
from pydantic import BaseModel, Field
from typing import List, Dict

class Order(BaseModel):
    order_id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    user_id: int
    ticker: str
    side: str # BUY / SELL
    price: int
    quantity: int
    initial_quantity: int = 0

    def __init__(self, **data):
        super().__init__(**data)
        if self.initial_quantity == 0:
            self.initial_quantity = self.quantity

class OrderBook:
    def __init__(self, ticker: str):
        self.ticker = ticker
        self.buys = [] # Sorted by price desc, then time
        self.sells = [] # Sorted by price asc, then time

    def add_order(self, order: Order):
        if order.side == "BUY":
            # Match with sells
            matches = self.match(order, self.sells, is_buy=True)
            if order.quantity > 0:
                # Add remaining to buys
                bisect.insort(self.buys, (-order.price, order)) # Negative price for desc sort
        else:
            # Match with buys
            matches = self.match(order, self.buys, is_buy=False)
            if order.quantity > 0:
                # Add remaining to sells
                bisect.insort(self.sells, (order.price, order))
        return matches

    def match(self, order: Order, book: list, is_buy: bool):
        matches = []
        while book and order.quantity > 0:
            best_price_tuple = book[0]
            best_price = abs(best_price_tuple[0])
            maker_order = best_price_tuple[1]

            # Price matching logic
            if (is_buy and order.price >= best_price) or (not is_buy and order.price <= best_price):
                match_qty = min(order.quantity, maker_order.quantity)
                match_price = best_price # Maker price
                
                matches.append({
                    "buyer_id": order.user_id if is_buy else maker_order.user_id,
                    "seller_id": maker_order.user_id if is_buy else order.user_id,
                    "ticker": self.ticker,
                    "price": match_price,
                    "quantity": match_qty
                })

                order.quantity -= match_qty
                maker_order.quantity -= match_qty

                if maker_order.quantity == 0:
                    book.pop(0)
            else:
                break
        return matches

# Global state for simulation
order_books: Dict[str, OrderBook] = {}

def get_order_book(ticker: str) -> OrderBook:
    if ticker not in order_books:
        order_books[ticker] = OrderBook(ticker)
    return order_books[ticker]
