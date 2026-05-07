package com.mts.trading.controller

import com.mts.trading.config.JwtUtils
import com.mts.trading.engine.Order
import com.mts.trading.service.TradeManager
import org.springframework.web.bind.annotation.*

data class OrderRequest(
    val ticker: String,
    val quantity: Int,
    val price: Int,
    val side: String
)

@RestController
@RequestMapping("/order")
class OrderController(
    private val tradeManager: TradeManager,
    private val jwtUtils: JwtUtils
) {

    @PostMapping
    fun placeOrder(
        @RequestHeader("Authorization") authHeader: String?,
        @RequestBody req: OrderRequest
    ): Map<String, Any> {
        // 1. JWT Validation
        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            return mapOf("status" to "Error", "message" to "Missing or invalid Authorization header")
        }

        val token = authHeader.substring(7)
        val userId = jwtUtils.getUserIdFromToken(token) ?: return mapOf("status" to "Error", "message" to "Invalid or expired token")

        // 2. Process Order
        val order = Order(
            userId = userId, // Authenticated User ID
            ticker = req.ticker,
            quantity = req.quantity,
            price = req.price,
            side = req.side
        )
        return tradeManager.placeOrder(order)
    }

    @GetMapping("/book/{ticker}")
    fun getBook(@PathVariable ticker: String): Map<String, Any> {
        val book = tradeManager.getOrderBook(ticker)
        return mapOf(
            "buys" to book.buys.map { mapOf("price" to it.key, "quantity" to it.value.sumOf { o -> o.quantity }) },
            "sells" to book.sells.map { mapOf("price" to it.key, "quantity" to it.value.sumOf { o -> o.quantity }) }
        )
    }
}
