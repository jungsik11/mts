package com.mts.trading.controller

import com.mts.trading.config.JwtUtils
import com.mts.trading.engine.Order
import com.mts.trading.service.TradeManager
import org.springframework.web.bind.annotation.*

import com.fasterxml.jackson.annotation.JsonProperty

data class OrderRequest(
    val ticker: String,
    val quantity: Int,
    val price: Int,
    val side: String,
    @JsonProperty("user_id") val userId: Long? = null // Match simulation bot payload
)

@RestController
@RequestMapping("/order")
class OrderController(
    private val tradeManager: TradeManager,
    private val jwtUtils: JwtUtils
) {

    @PostMapping
    fun placeOrder(
        @RequestHeader("Authorization", required = false) authHeader: String?,
        @RequestHeader("X-Internal-Secret", required = false) internalSecret: String?,
        @RequestBody req: OrderRequest
    ): Map<String, Any> {
        val userId = if (internalSecret == "mts-simulation-secret" && req.userId != null) {
            req.userId
        } else {
            // 1. JWT Validation
            if (authHeader == null || !authHeader.startsWith("Bearer ")) {
                return mapOf("status" to "Error", "message" to "Missing or invalid Authorization header")
            }

            val token = authHeader.substring(7)
            jwtUtils.getUserIdFromToken(token) ?: return mapOf("status" to "Error", "message" to "Invalid or expired token")
        }

        // 2. Process Order
        val order = Order(
            userId = userId,
            ticker = req.ticker,
            quantity = req.quantity,
            price = req.price,
            side = req.side
        )
        return tradeManager.placeOrder(order)
    }

    @DeleteMapping("/{orderId}")
    fun cancelOrder(
        @PathVariable orderId: String,
        @RequestHeader("Authorization") authHeader: String
    ): Map<String, Any> {
        val token = authHeader.substring(7)
        val userId = jwtUtils.getUserIdFromToken(token) ?: return mapOf("status" to "Error", "message" to "Invalid or expired token")
        
        return tradeManager.cancelOrder(orderId, userId)
    }

    @GetMapping("/book/{ticker}")
    fun getBook(@PathVariable ticker: String): Map<String, Any> {
        val book = tradeManager.getOrderBook(ticker)
        synchronized(book) {
            return mapOf(
                "buys" to book.buys.map { mapOf("price" to it.key, "quantity" to it.value.sumOf { o -> o.quantity }) },
                "sells" to book.sells.map { mapOf("price" to it.key, "quantity" to it.value.sumOf { o -> o.quantity }) }
            )
        }
    }

    @GetMapping("/user")
    fun getUserOrders(
        @RequestHeader("Authorization") authHeader: String
    ): List<Map<String, Any>> {
        if (!authHeader.startsWith("Bearer ")) return emptyList()
        val token = authHeader.substring(7)
        val userId = jwtUtils.getUserIdFromToken(token) ?: return emptyList()
        return tradeManager.getUserOrders(userId)
    }
}
