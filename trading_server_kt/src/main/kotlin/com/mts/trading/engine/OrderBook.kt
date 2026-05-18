package com.mts.trading.engine

import java.util.*
import java.util.concurrent.ConcurrentLinkedQueue

class OrderBook(val ticker: String) {
    // BUY: Descending order (highest price first)
    val buys = TreeMap<Int, ConcurrentLinkedQueue<Order>>(Collections.reverseOrder())
    // SELL: Ascending order (lowest price first)
    val sells = TreeMap<Int, ConcurrentLinkedQueue<Order>>()

    @Synchronized
    fun addOrder(order: Order): List<TradeMatch> {
        val matches = mutableListOf<TradeMatch>()
        
        if (order.side == "BUY") {
            matchOrder(order, sells, matches)
            if (order.quantity > 0) {
                buys.computeIfAbsent(order.price) { ConcurrentLinkedQueue() }.add(order)
            }
        } else {
            matchOrder(order, buys, matches)
            if (order.quantity > 0) {
                sells.computeIfAbsent(order.price) { ConcurrentLinkedQueue() }.add(order)
            }
        }
        return matches
    }

    @Synchronized
    fun cancelOrder(orderId: String): Order? {
        for (book in listOf(buys, sells)) {
            for ((price, queue) in book) {
                val orderToRemove = queue.firstOrNull { it.orderId == orderId }
                if (orderToRemove != null) {
                    queue.remove(orderToRemove)
                    if (queue.isEmpty()) {
                        book.remove(price)
                    }
                    return orderToRemove
                }
            }
        }
        return null
    }

    private fun matchOrder(order: Order, oppositeBook: TreeMap<Int, ConcurrentLinkedQueue<Order>>, matches: MutableList<TradeMatch>) {
        val it = oppositeBook.entries.iterator()
        while (it.hasNext() && order.quantity > 0) {
            val entry = it.next()
            val price = entry.key
            
            // For BUY order, price must be >= sell price. For SELL order, price must be <= buy price.
            val isMatch = if (order.side == "BUY") order.price >= price else order.price <= price
            if (!isMatch) break

            val queue = entry.value
            while (queue.isNotEmpty() && order.quantity > 0) {
                val oppositeOrder = queue.peek()
                val matchQty = minOf(order.quantity, oppositeOrder.quantity)
                
                val buyerId = if (order.side == "BUY") order.userId else oppositeOrder.userId
                val sellerId = if (order.side == "SELL") order.userId else oppositeOrder.userId
                val buyerOrderPrice = if (order.side == "BUY") order.price else oppositeOrder.price

                matches.add(TradeMatch(
                    buyer_id = buyerId,
                    seller_id = sellerId,
                    ticker = ticker,
                    price = price, // Execution price is the existing order's price
                    quantity = matchQty,
                    buyer_order_price = buyerOrderPrice
                ))

                order.quantity -= matchQty
                oppositeOrder.quantity -= matchQty

                if (oppositeOrder.quantity == 0) {
                    queue.poll()
                }
            }
            if (queue.isEmpty()) {
                it.remove()
            }
        }
    }
}
