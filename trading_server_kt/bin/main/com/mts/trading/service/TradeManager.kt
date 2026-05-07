package com.mts.trading.service

import com.mts.trading.engine.Order
import com.mts.trading.engine.OrderBook
import com.mts.trading.engine.TradeMatch
import com.fasterxml.jackson.databind.ObjectMapper
import org.springframework.beans.factory.annotation.Value
import org.springframework.data.redis.core.StringRedisTemplate
import org.springframework.stereotype.Service
import org.springframework.web.client.RestTemplate
import java.util.concurrent.ConcurrentHashMap

@Service
class TradeManager(
    @Value("\${ledger.url}") private val ledgerUrl: String,
    private val redisTemplate: StringRedisTemplate,
    private val objectMapper: ObjectMapper
) {
    private val books = ConcurrentHashMap<String, OrderBook>()
    private val restTemplate = RestTemplate()

    fun placeOrder(order: Order): Map<String, Any> {
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
                return mapOf("status" to "Rejected", "reason" to (res?.get("reason") ?: "Unknown"))
            }
        } catch (e: Exception) {
            return mapOf("status" to "Error", "reason" to "Ledger server unavailable")
        }

        // 2. Matching
        val book = books.computeIfAbsent(order.ticker) { OrderBook(it) }
        val matches = book.addOrder(order)

        // 3. Settlement & Price Update
        val settledMatches = mutableListOf<TradeMatch>()
        for (match in matches) {
            try {
                restTemplate.postForObject("$ledgerUrl/internal/settle", match, Map::class.java)
                settledMatches.add(match)
                
                // Update Market Price in Redis
                updateMarketPrice(match)
            } catch (e: Exception) {
                println("Settlement failed for match: $match, error: ${e.message}")
            }
        }

        return mapOf(
            "status" to "Order Processed",
            "matches" to settledMatches,
            "remaining_qty" to order.quantity
        )
    }

    private fun updateMarketPrice(match: TradeMatch) {
        val ticker = match.ticker
        val executionPrice = match.price
        
        try {
            val priceKey = "price:$ticker"
            val basePriceKey = "base_price:$ticker"
            
            // Get base price (previous day close) from Redis
            val basePriceStr = redisTemplate.opsForValue().get(basePriceKey)
            val basePrice = basePriceStr?.toDouble() ?: executionPrice.toDouble()
            
            var totalChangePercent = 0.0
            if (basePrice != 0.0) {
                totalChangePercent = ((executionPrice - basePrice) / basePrice) * 100.0
            }
            
            val marketData = mapOf(
                "ticker" to ticker,
                "price" to executionPrice,
                "change_percent" to Math.round(totalChangePercent * 100.0) / 100.0
            )
            
            val jsonData = objectMapper.writeValueAsString(marketData)
            redisTemplate.opsForValue().set(priceKey, jsonData)
            redisTemplate.convertAndSend("market_prices", jsonData)
            
        } catch (e: Exception) {
            println("Failed to update market price in Redis: ${e.message}")
        }
    }

    fun getOrderBook(ticker: String): OrderBook {
        return books.computeIfAbsent(ticker) { OrderBook(it) }
    }
}
