package com.mts.trading.controller

import com.mts.trading.service.TradeManager
import org.springframework.data.redis.core.StringRedisTemplate
import org.springframework.web.bind.annotation.*
import com.fasterxml.jackson.module.kotlin.jacksonObjectMapper
import com.fasterxml.jackson.module.kotlin.readValue
import java.lang.management.ManagementFactory
import com.sun.management.OperatingSystemMXBean

@RestController
@RequestMapping("/admin")
@CrossOrigin(origins = ["*"])
class AdminController(
    private val tradeManager: TradeManager,
    @org.springframework.beans.factory.annotation.Qualifier("primaryRedisTemplate") private val redisTemplate: StringRedisTemplate,
    @org.springframework.beans.factory.annotation.Qualifier("secondaryRedisTemplate") private val secondaryRedisTemplate: StringRedisTemplate
) {
    private val mapper = jacksonObjectMapper()

    private var lastPrimaryCpu = 0.0
    private var lastSecondaryCpu = 0.0
    private var lastPrimaryTime = System.currentTimeMillis()
    private var lastSecondaryTime = System.currentTimeMillis()

    @GetMapping("/system/metrics")
    fun getSystemMetrics(): Map<String, Any> {
        val osBean = ManagementFactory.getOperatingSystemMXBean() as OperatingSystemMXBean
        val runtime = Runtime.getRuntime()
        
        val cpuUsage = osBean.cpuLoad * 100
        val totalMemory = osBean.totalMemorySize
        val freeMemory = osBean.freeMemorySize
        val usedMemory = totalMemory - freeMemory
        
        val jvmTotalMemory = runtime.totalMemory()
        val jvmFreeMemory = runtime.freeMemory()
        val jvmUsedMemory = jvmTotalMemory - jvmFreeMemory

        // Health Checks
        val health = mutableMapOf<String, String>()
        
        // Redis Check
        try {
            redisTemplate.execute { connection -> connection.ping() }
            health["redis-primary"] = "UP"
        } catch (e: Exception) { health["redis-primary"] = "DOWN" }

        try {
            secondaryRedisTemplate.execute { connection -> connection.ping() }
            health["redis-secondary"] = "UP"
        } catch (e: Exception) { health["redis-secondary"] = "DOWN" }

        // Account Server Check (Ledger)
        try {
            val restTemplate = org.springframework.web.client.RestTemplate()
            val ledgerUrl = System.getenv("LEDGER_URL") ?: "http://100.91.106.15:9000"
            restTemplate.getForEntity("$ledgerUrl/admin/users", List::class.java)
            health["accountServer"] = "UP"
        } catch (e: Exception) { health["accountServer"] = "DOWN" }

        // Background Processes (Heartbeats)
        val heartbeats = mutableMapOf<String, Any>()
        listOf("price-generator", "trading-bot").forEach { proc ->
            val hbData = redisTemplate.opsForValue().get("heartbeat:$proc")
            if (hbData != null) {
                heartbeats[proc] = mapper.readValue<Map<String, Any>>(hbData)
            } else {
                heartbeats[proc] = mapOf("status" to "INACTIVE")
            }
        }

        // Fetch Redis System Info
        val redisPrimaryMetrics = try {
            val infoRaw = redisTemplate.execute { conn -> conn.info() }
            val metrics = parseRedisInfo(infoRaw)
            
            val currentCpu = (metrics["used_cpu_user"]?.toDouble() ?: 0.0) + (metrics["used_cpu_sys"]?.toDouble() ?: 0.0)
            val currentTime = System.currentTimeMillis()
            val deltaTime = (currentTime - lastPrimaryTime) / 1000.0
            val calculatedCpu = if (deltaTime > 0.5) {
                val diff = currentCpu - lastPrimaryCpu
                (diff / deltaTime) * 100.0
            } else 0.0
            
            if (deltaTime > 0.5) {
                lastPrimaryCpu = currentCpu
                lastPrimaryTime = currentTime
            }

            mapOf<String, Any>(
                "cpuUsage" to String.format("%.2f", if (calculatedCpu > 100.0) 99.99 else calculatedCpu),
                "usedMemory" to (metrics["used_memory"]?.toLong() ?: 0L),
                "totalMemory" to (metrics["total_system_memory"]?.toLong() ?: 1L),
                "jvm" to mapOf("used" to 0, "total" to 0),
                "availableProcessors" to 1,
                "systemLoadAverage" to 0.0
            )
        } catch (e: Exception) { emptyMap<String, Any>() }

        val redisSecondaryMetrics = try {
            val infoRaw = secondaryRedisTemplate.execute { conn -> conn.info() }
            val metrics = parseRedisInfo(infoRaw)
            
            val currentCpu = (metrics["used_cpu_user"]?.toDouble() ?: 0.0) + (metrics["used_cpu_sys"]?.toDouble() ?: 0.0)
            val currentTime = System.currentTimeMillis()
            val deltaTime = (currentTime - lastSecondaryTime) / 1000.0
            val calculatedCpu = if (deltaTime > 0.5) {
                val diff = currentCpu - lastSecondaryCpu
                (diff / deltaTime) * 100.0
            } else 0.0
            
            if (deltaTime > 0.5) {
                lastSecondaryCpu = currentCpu
                lastSecondaryTime = currentTime
            }

            mapOf<String, Any>(
                "cpuUsage" to String.format("%.2f", if (calculatedCpu > 100.0) 99.99 else calculatedCpu),
                "usedMemory" to (metrics["used_memory"]?.toLong() ?: 0L),
                "totalMemory" to (metrics["total_system_memory"]?.toLong() ?: 1L),
                "jvm" to mapOf("used" to 0, "total" to 0),
                "availableProcessors" to 1,
                "systemLoadAverage" to 0.0
            )
        } catch (e: Exception) { emptyMap<String, Any>() }

        return mapOf(
            "cpuUsage" to String.format("%.2f", cpuUsage),
            "totalMemory" to totalMemory,
            "usedMemory" to usedMemory,
            "freeMemory" to freeMemory,
            "memoryUsagePercent" to String.format("%.2f", (usedMemory.toDouble() / totalMemory.toDouble()) * 100),
            "jvm" to mapOf(
                "total" to jvmTotalMemory,
                "used" to jvmUsedMemory,
                "free" to jvmFreeMemory
            ),
            "health" to health,
            "heartbeats" to heartbeats,
            "redisPrimaryMetrics" to redisPrimaryMetrics,
            "redisSecondaryMetrics" to redisSecondaryMetrics,
            "availableProcessors" to osBean.availableProcessors,
            "systemLoadAverage" to osBean.systemLoadAverage
        )
    }

    @GetMapping("/tickers")
    fun getTickers(): List<Map<String, Any>> {
        val keys = mutableSetOf<String>()
        redisTemplate.execute { connection ->
            val options = org.springframework.data.redis.core.ScanOptions.scanOptions().match("price:*").count(1000).build()
            val cursor = connection.keyCommands().scan(options)
            while (cursor.hasNext()) {
                keys.add(String(cursor.next()))
            }
        }
        
        return keys.map { key ->
            val symbol = key.removePrefix("price:")
            val priceDataRaw = redisTemplate.opsForValue().get(key)
            val infoDataRaw = redisTemplate.opsForValue().get("ticker_info:$symbol")
            val basePrice = redisTemplate.opsForValue().get("base_price:$symbol") ?: "0"
            
            val priceData: Map<String, Any> = if (priceDataRaw != null) mapper.readValue<Map<String, Any>>(priceDataRaw) else emptyMap()
            val infoData: Map<String, String> = if (infoDataRaw != null) mapper.readValue<Map<String, String>>(infoDataRaw) else emptyMap()
            
            mapOf(
                "ticker" to symbol,
                "price" to (priceData["price"] ?: 0),
                "basePrice" to basePrice.toDouble().toInt(),
                "name" to (infoData["name"] ?: symbol),
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
        val name = req.name ?: ticker
        val sector = req.sector ?: "General"
        
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
            "name" to name,
            "sector" to sector
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

    private fun parseRedisInfo(infoRaw: Any?): Map<String, String> {
        val result = mutableMapOf<String, String>()
        when (infoRaw) {
            is java.util.Properties -> {
                infoRaw.stringPropertyNames().forEach { name ->
                    result[name] = infoRaw.getProperty(name)
                }
            }
            is String -> {
                infoRaw.lines().forEach { line ->
                    if (line.contains(":") && !line.startsWith("#")) {
                        val parts = line.split(":", limit = 2)
                        result[parts[0].trim()] = parts[1].trim()
                    }
                }
            }
        }
        return result
    }
}

data class AddTickerRequest(val ticker: String, val initialPrice: Int, val name: String? = null, val sector: String? = null)
data class UpdateTickerRequest(val price: Int)
data class UpdateTickerFullRequest(val ticker: String, val price: Int, val name: String, val sector: String)
