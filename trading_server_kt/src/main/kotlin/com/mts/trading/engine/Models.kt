package com.mts.trading.engine

import java.util.UUID

data class Order(
    val orderId: String = UUID.randomUUID().toString(),
    val userId: Long,
    val ticker: String,
    val side: String, // BUY, SELL
    val price: Int,
    var quantity: Int,
    val initialQuantity: Int = quantity,
    val timestamp: Long = System.currentTimeMillis()
)

data class TradeMatch(
    val buyer_id: Long,
    val seller_id: Long,
    val ticker: String,
    val price: Int,
    val quantity: Int,
    val buyer_order_price: Int
)
