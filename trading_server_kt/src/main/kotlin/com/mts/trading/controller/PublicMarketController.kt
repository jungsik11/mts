package com.mts.trading.controller

import com.fasterxml.jackson.module.kotlin.jacksonObjectMapper
import com.fasterxml.jackson.module.kotlin.readValue
import org.springframework.data.redis.core.StringRedisTemplate
import org.springframework.web.bind.annotation.*

@RestController
@RequestMapping("/market")
@CrossOrigin(origins = ["*"])
class PublicMarketController(
    private val redisTemplate: StringRedisTemplate
) {
    private val mapper = jacksonObjectMapper()

    @GetMapping("/tickers")
    fun getTickers(): List<Map<String, Any>> {
        val keys = redisTemplate.keys("price:*") ?: emptySet()
        return keys.map { key ->
            val symbol = key.removePrefix("price:")
            val priceDataRaw = redisTemplate.opsForValue().get(key)
            val infoDataRaw = redisTemplate.opsForValue().get("ticker_info:$symbol")
            
            val priceData: Map<String, Any> = if (priceDataRaw != null) mapper.readValue(priceDataRaw) else emptyMap()
            val infoData: Map<String, String> = if (infoDataRaw != null) mapper.readValue(infoDataRaw) else emptyMap()
            
            mapOf(
                "ticker" to symbol,
                "price" to (priceData["price"] ?: 0),
                "change_percent" to (priceData["change_percent"] ?: 0.0),
                "name" to (infoData["name"] ?: symbol),
                "sector" to (infoData["sector"] ?: "Unknown")
            )
        }
    }
}
