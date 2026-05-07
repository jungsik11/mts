package com.mts.trading.controller

import com.mts.trading.service.TradeManager
import org.springframework.data.redis.core.StringRedisTemplate
import org.springframework.web.bind.annotation.*
import com.fasterxml.jackson.module.kotlin.jacksonObjectMapper
import com.fasterxml.jackson.module.kotlin.readValue

@RestController
@RequestMapping("/admin")
@CrossOrigin(origins = ["*"])
class AdminController(
    private val tradeManager: TradeManager,
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
                "name" to (infoData["name"] ?: symbol), // Default to symbol if name missing
                "sector" to (infoData["sector"] ?: "Unknown"),
                "raw" to (priceDataRaw ?: "{}")
            )
        }
    }

    @PutMapping("/tickers/{oldTicker}/full")
    fun updateTickerFull(
        @PathVariable oldTicker: String,
        @RequestBody req: UpdateTickerFullRequest
    ): Map<String, Any> {
        val newTicker = req.ticker
        val price = req.price
        val name = req.name
        val sector = req.sector

        // 1. If ticker changed, migrate data
        if (oldTicker != newTicker) {
            redisTemplate.delete("price:$oldTicker")
            redisTemplate.delete("base_price:$oldTicker")
            redisTemplate.delete("ticker_info:$oldTicker")
            // Also need to update order books in TradeManager if necessary, 
            // but for simple admin tool, we focus on Redis state here.
        }

        // 2. Set Price Data
        val priceKey = "price:$newTicker"
        val basePriceKey = "base_price:$newTicker"
        redisTemplate.opsForValue().set(basePriceKey, price.toString())
        redisTemplate.opsForValue().set(priceKey, mapper.writeValueAsString(mapOf(
            "ticker" to newTicker,
            "price" to price,
            "change_percent" to 0.0
        )))

        // 3. Set Info Data
        val infoKey = "ticker_info:$newTicker"
        redisTemplate.opsForValue().set(infoKey, mapper.writeValueAsString(mapOf(
            "name" to name,
            "sector" to sector
        )))

        return mapOf("status" to "Success", "message" to "Ticker $newTicker updated successfully")
    }

    @PostMapping("/ticker/add")
    fun addTicker(@RequestBody req: AddTickerRequest): Map<String, Any> {
        val ticker = req.ticker
        val initialPrice = req.initialPrice
        
        val priceKey = "price:$ticker"
        val basePriceKey = "base_price:$ticker"
        val infoKey = "ticker_info:$ticker"
        
        redisTemplate.opsForValue().set(basePriceKey, initialPrice.toString())
        redisTemplate.opsForValue().set(priceKey, mapper.writeValueAsString(mapOf(
            "ticker" to ticker,
            "price" to initialPrice,
            "change_percent" to 0.0
        )))
        
        redisTemplate.opsForValue().set(infoKey, mapper.writeValueAsString(mapOf(
            "name" to ticker,
            "sector" to "General"
        )))
        
        return mapOf("status" to "Success", "message" to "Ticker $ticker added")
    }

    @PostMapping("/ticker/remove")
    fun removeTicker(@RequestParam ticker: String): Map<String, Any> {
        redisTemplate.delete("price:$ticker")
        redisTemplate.delete("base_price:$ticker")
        redisTemplate.delete("ticker_info:$ticker")
        return mapOf("status" to "Success", "message" to "Ticker $ticker removed")
    }

    @PutMapping("/tickers/{ticker}")
    fun updateTicker(@PathVariable ticker: String, @RequestBody req: UpdateTickerRequest): Map<String, Any> {
        val priceKey = "price:$ticker"
        val basePriceKey = "base_price:$ticker"
        redisTemplate.opsForValue().set(basePriceKey, req.price.toString())
        redisTemplate.opsForValue().set(priceKey, mapper.writeValueAsString(mapOf(
            "ticker" to ticker,
            "price" to req.price,
            "change_percent" to 0.0
        )))
        return mapOf("status" to "Success", "message" to "Ticker $ticker updated")
    }
}

data class AddTickerRequest(val ticker: String, val initialPrice: Int)
data class UpdateTickerRequest(val price: Int)
data class UpdateTickerFullRequest(val ticker: String, val price: Int, val name: String, val sector: String)
