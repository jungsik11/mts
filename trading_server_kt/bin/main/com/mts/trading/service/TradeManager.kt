package com.mts.trading.service

import com.mts.trading.engine.Order
import com.mts.trading.engine.OrderBook
import com.mts.trading.engine.TradeMatch
import com.fasterxml.jackson.databind.ObjectMapper
import org.springframework.beans.factory.annotation.Qualifier
import org.springframework.beans.factory.annotation.Value
import org.springframework.data.redis.core.StringRedisTemplate
import org.springframework.stereotype.Service
import org.springframework.web.client.RestTemplate
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.CompletableFuture
import java.util.concurrent.Executors

@Service
class TradeManager(
    @Value("\${ledger.url}") private val ledgerUrl: String,
    private val redisTemplate: StringRedisTemplate,
    @Qualifier("secondaryRedisTemplate") private val secondaryRedisTemplate: StringRedisTemplate,
    private val objectMapper: ObjectMapper
) {
    private val books = ConcurrentHashMap<String, OrderBook>()
    private val restTemplate = RestTemplate()
    private val asyncExecutor = Executors.newFixedThreadPool(200)

    var isKrMarketOpen: Boolean = true
        set(value) {
            field = value
            try {
                redisTemplate.opsForValue().set("market_status:kr:open", value.toString())
            } catch (e: Exception) {
                println("Failed to sync KR market status to Redis: ${e.message}")
            }
        }

    var isUsMarketOpen: Boolean = false
        set(value) {
            field = value
            try {
                redisTemplate.opsForValue().set("market_status:us:open", value.toString())
            } catch (e: Exception) {
                println("Failed to sync US market status to Redis: ${e.message}")
            }
        }

    fun placeOrder(order: Order): Map<String, Any> {
        println("Incoming Order: ${order.side} ${order.ticker} ${order.quantity}@${order.price} (User: ${order.userId})")
        if (order.price <= 0) {
            return mapOf("status" to "Rejected", "reason" to "Price must be greater than zero")
        }
        val isUsStock = order.ticker.any { it.isLetter() }
        if (isUsStock) {
            if (!isUsMarketOpen) return mapOf("status" to "Rejected", "reason" to "US Market is closed")
        } else {
            if (!isKrMarketOpen) return mapOf("status" to "Rejected", "reason" to "KR Market is closed")
        }

        // 1. Margin Check
        val marginCheckUrl = "$ledgerUrl/internal/margin-check"
        val marginReq = mapOf(
            "user_id" to order.userId,
            "ticker" to order.ticker,
            "side" to order.side,
            "price" to order.price,
            "quantity" to order.quantity
        )
        
        try {
            val res = restTemplate.postForObject(marginCheckUrl, marginReq, Map::class.java)
            if (res?.get("allowed") != true) {
                println("Order REJECTED by Ledger: ${res?.get("reason")}")
                return mapOf("status" to "Rejected", "reason" to (res?.get("reason") ?: "Unknown"))
            }
        } catch (e: Exception) {
            println("Ledger Error: ${e.message}")
            return mapOf("status" to "Error", "reason" to "Ledger server unavailable")
        }

        // 2. Matching
        val book = books.computeIfAbsent(order.ticker) { OrderBook(it) }
        val matches = book.addOrder(order)
        
        if (matches.isNotEmpty()) {
            println("Matched ${matches.size} trades for ${order.ticker}")
        }
        if (order.quantity > 0) {
            println("Added to Book: ${order.ticker} ${order.side} ${order.price} (Remaining: ${order.quantity})")
        }

        // 3. Settlement & Price Update
        val settledMatches = mutableListOf<TradeMatch>()
            settledMatches.add(match)
            CompletableFuture.runAsync({
                try {
                    restTemplate.postForObject("$ledgerUrl/internal/settle", match, Map::class.java)
                    
                    // Update Market Price and Generate Candles
                    updateMarketPrice(match)
                    
                    // Publish trade update for real-time history
                    val tradeData = mapOf(
                        "ticker" to match.ticker,
                        "price" to match.price,
                        "quantity" to match.quantity,
                        "buyerId" to match.buyer_id,
                        "sellerId" to match.seller_id,
                        "timestamp" to System.currentTimeMillis()
                    )
                    redisTemplate.convertAndSend("trade_updates", objectMapper.writeValueAsString(tradeData))
                } catch (e: Exception) {
                    println("SETTLEMENT FAILED: match=$match | error=${e.message}")
                }
            }, asyncExecutor)

        val response = mapOf(
            "status" to "Order Processed",
            "orderId" to order.orderId,
            "matches" to settledMatches,
            "remaining_qty" to order.quantity
        )

        publishOrderBook(order.ticker)
        return response
    }

    fun cancelOrder(orderId: String, userId: Long): Map<String, Any> {
        var foundOrder: Order? = null
        var ticker: String? = null

        // Find the order in the books
        for ((t, book) in books) {
            val order = book.cancelOrder(orderId)
            if (order != null) {
                if (order.userId != userId) {
                    // Put the order back, it doesn't belong to the user
                    book.addOrder(order)
                    return mapOf("status" to "Error", "message" to "Order not found or does not belong to user")
                }
                foundOrder = order
                ticker = t
                break
            }
        }

        if (foundOrder == null || ticker == null) {
            return mapOf("status" to "Error", "message" to "Order not found or already filled")
        }

        // Unlock the funds/assets in the account server
        try {
            val unlockUrl = "$ledgerUrl/internal/unlock"
            val unlockReq = mapOf(
                "user_id" to foundOrder.userId,
                "ticker" to foundOrder.ticker,
                "side" to foundOrder.side,
                "price" to foundOrder.price,
                "quantity" to foundOrder.quantity // The remaining quantity
            )
            restTemplate.postForObject(unlockUrl, unlockReq, Map::class.java)
        } catch (e: Exception) {
            // If unlock fails, we should ideally put the order back in the book or handle it
            // For now, we log the error and proceed with cancellation locally
            println("LEDGER UNLOCK FAILED for order $orderId: ${e.message}")
            return mapOf("status" to "Error", "message" to "Ledger server error during unlock")
        }

        println("Cancelled Order: ${foundOrder.orderId} for user ${foundOrder.userId}")
        publishOrderBook(ticker)
        return mapOf("status" to "Success", "message" to "Order cancelled")
    }

    private fun publishOrderBook(ticker: String) {
        val book = getOrderBook(ticker)
        
        // Copy the book state while holding lock, then publish asynchronously
        val buysCopy: List<Map<String, Any>>
        val sellsCopy: List<Map<String, Any>>
        synchronized(book) {
            buysCopy = book.buys.map { mapOf("price" to it.key, "quantity" to it.value.sumOf { o -> o.quantity }) }
            sellsCopy = book.sells.map { mapOf("price" to it.key, "quantity" to it.value.sumOf { o -> o.quantity }) }
        }

        CompletableFuture.runAsync({
            try {
                val orderBookData = mapOf(
                    "type" to "order_book_updates",
                    "ticker" to ticker,
                    "buys" to buysCopy,
                    "sells" to sellsCopy
                )
                val jsonData = objectMapper.writeValueAsString(orderBookData)
                redisTemplate.convertAndSend("order_book_updates", jsonData)
            } catch (e: Exception) {
                println("Failed to publish order book for $ticker: ${e.message}")
            }
        }, asyncExecutor)
    }

    private fun updateMarketPrice(match: TradeMatch) {
        val ticker = match.ticker
        val executionPrice = match.price
        val timestamp = System.currentTimeMillis()
        
        try {
            val priceKey = "price:$ticker"
            val basePriceKey = "base_price:$ticker"
            
            val basePriceStr = redisTemplate.opsForValue().get(basePriceKey)
            val basePrice = basePriceStr?.toDouble() ?: executionPrice
            
            val totalChangePercent = if (basePrice != 0.0) ((executionPrice - basePrice) / basePrice) * 100.0 else 0.0
            
            val marketData = mapOf(
                "ticker" to ticker,
                "price" to match.price,
                "change_percent" to Math.round(totalChangePercent * 100.0) / 100.0,
                "timestamp" to timestamp
            )
            
            val jsonData = objectMapper.writeValueAsString(marketData)
            redisTemplate.opsForValue().set(priceKey, jsonData)
            redisTemplate.convertAndSend("market_prices", jsonData)

            updateCandles(ticker, executionPrice, match.quantity, timestamp)
            
        } catch (e: Exception) {
            println("Failed to update market price in Redis: ${e.message}")
        }
    }

    private fun updateCandles(ticker: String, price: Double, quantity: Int, timestamp: Long) {
        val intervals = listOf("1m" to 60000L, "1h" to 3600000L, "1d" to 86400000L)
        
        for ((name, duration) in intervals) {
            val candleTime = (timestamp / duration) * duration
            val candleKey = "candles:$ticker:$name"
            
            val lastCandleJson = secondaryRedisTemplate.opsForList().index(candleKey, -1)
            var candle: MutableMap<String, Any> = if (lastCandleJson != null) {
                val decoded = objectMapper.readValue(lastCandleJson, Map::class.java) as Map<String, Any>
                if ((decoded["timestamp"] as Long) == candleTime) {
                    decoded.toMutableMap()
                } else {
                    createNewCandle(price, candleTime)
                }
            } else {
                createNewCandle(price, candleTime)
            }

            candle["high"] = maxOf(candle["high"] as Double, price)
            candle["low"] = minOf(candle["low"] as Double, price)
            candle["close"] = price
            candle["volume"] = (candle["volume"] as Int) + quantity

            val updatedJson = objectMapper.writeValueAsString(candle)
            if (lastCandleJson != null && (objectMapper.readValue(lastCandleJson, Map::class.java)["timestamp"] as Long) == candleTime) {
                secondaryRedisTemplate.opsForList().set(candleKey, -1, updatedJson)
            } else {
                secondaryRedisTemplate.opsForList().rightPush(candleKey, updatedJson)
                secondaryRedisTemplate.opsForList().trim(candleKey, -200, -1)
            }
        }
    }

    private fun createNewCandle(price: Double, timestamp: Long): MutableMap<String, Any> {
        return mutableMapOf(
            "open" to price, "high" to price, "low" to price, "close" to price,
            "volume" to 0, "timestamp" to timestamp
        )
    }

    fun getOrderBook(ticker: String): OrderBook {
<<<<<<< HEAD
        val isUsStock = ticker.any { it.isLetter() }
        val isOpen = if (isUsStock) isUsMarketOpen else isKrMarketOpen
        
        val book = if (isOpen) {
            books.computeIfAbsent(ticker) { OrderBook(it) }
        } else {
            OrderBook(ticker)
        }
        println("Fetching Book for $ticker. Buys: ${book.buys.size}, Sells: ${book.sells.size}")
        return book
=======
        return books.computeIfAbsent(ticker) { OrderBook(it) }
>>>>>>> origin/feature/app-menu-dev
    }

    fun clearAllBooks() {
        books.clear()
        println("All order books cleared for market close.")
    }

    fun saveClosingPrices() {
        val keys = redisTemplate.keys("price:*") ?: emptySet()
        keys.forEach { key ->
            val ticker = key.removePrefix("price:")
            val priceDataRaw = redisTemplate.opsForValue().get(key)
            if (priceDataRaw != null) {
                try {
                    val priceData = objectMapper.readValue(priceDataRaw, Map::class.java)
                    val closingPrice = priceData["price"]
                    if (closingPrice != null) {
                        redisTemplate.opsForValue().set("base_price:$ticker", closingPrice.toString())
                    }
                } catch (e: Exception) {
                    println("Failed to parse price data for $ticker: ${e.message}")
                }
            }
        }
        println("Closing prices saved as base prices for tomorrow.")
    }

    fun getUserOrders(userId: Long): List<Map<String, Any>> {
        val result = mutableListOf<Map<String, Any>>()
        for ((_, book) in books) {
            synchronized(book) {
                book.buys.values.flatten().filter { it.userId == userId }.forEach { order ->
                    result.add(mapOf(
                        "orderId" to order.orderId, "ticker" to order.ticker, "price" to order.price,
                        "quantity" to order.quantity, "initialQuantity" to order.initialQuantity,
                        "side" to "BUY", "timestamp" to order.timestamp
                    ))
                }
                book.sells.values.flatten().filter { it.userId == userId }.forEach { order ->
                    result.add(mapOf(
                        "orderId" to order.orderId, "ticker" to order.ticker, "price" to order.price,
                        "quantity" to order.quantity, "initialQuantity" to order.initialQuantity,
                        "side" to "SELL", "timestamp" to order.timestamp
                    ))
                }
            }
        }
        return result
    }
}
