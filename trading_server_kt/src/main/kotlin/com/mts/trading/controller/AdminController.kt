package com.mts.trading.controller

import com.mts.trading.service.TradeManager
import org.springframework.data.redis.core.StringRedisTemplate
import org.springframework.web.bind.annotation.*

@RestController
@RequestMapping("/admin")
@CrossOrigin(origins = ["*"])
class AdminController(
    private val tradeManager: TradeManager,
    private val redisTemplate: StringRedisTemplate
) {
    @GetMapping("/tickers")
    fun getTickers(): List<Map<String, Any>> {
        val keys = redisTemplate.keys("price:*") ?: emptySet()
        return keys.map { key ->
            val ticker = key.removePrefix("price:")
            val data = redisTemplate.opsForValue().get(key)
            mapOf(
                "ticker" to ticker,
                "data" to (data ?: "{}")
            )
        }
    }

    @PostMapping("/ticker/add")
    fun addTicker(@RequestBody req: AddTickerRequest): Map<String, Any> {
        val ticker = req.ticker
        val initialPrice = req.initialPrice
        
        // Initialize in Redis
        val priceKey = "price:$ticker"
        val basePriceKey = "base_price:$ticker"
        
        redisTemplate.opsForValue().set(basePriceKey, initialPrice.toString())
        redisTemplate.opsForValue().set(priceKey, "{\"ticker\":\"$ticker\",\"price\":$initialPrice,\"change_percent\":0.0}")
        
        return mapOf("status" to "Success", "message" to "Ticker $ticker added")
    }

    @PostMapping("/ticker/remove")
    fun removeTicker(@RequestParam ticker: String): Map<String, Any> {
        redisTemplate.delete("price:$ticker")
        redisTemplate.delete("base_price:$ticker")
        return mapOf("status" to "Success", "message" to "Ticker $ticker removed")
    }
}

data class AddTickerRequest(val ticker: String, val initialPrice: Int)
