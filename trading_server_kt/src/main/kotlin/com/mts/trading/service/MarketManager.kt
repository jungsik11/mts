package com.mts.trading.service

import org.springframework.scheduling.annotation.Scheduled
import org.springframework.stereotype.Service
import java.time.LocalDateTime
import java.time.ZoneId

@Service
class MarketManager(private val tradeManager: TradeManager) {

    private val seoulZone = ZoneId.of("Asia/Seoul")

    @Scheduled(cron = "0 0 20 * * *", zone = "Asia/Seoul")
    fun closeMarket() {
        tradeManager.isMarketOpen = false
        tradeManager.saveClosingPrices()
        tradeManager.clearAllBooks()
        println("Market Closed at ${LocalDateTime.now(seoulZone)}")
    }

    @Scheduled(cron = "0 0 8 * * *", zone = "Asia/Seoul")
    fun openMarket() {
        tradeManager.isMarketOpen = true
        println("Market Opened at ${LocalDateTime.now(seoulZone)}")
    }
    
    // For initialization: check current time and set status
    init {
        val now = LocalDateTime.now(seoulZone)
        tradeManager.isMarketOpen = now.hour in 8..19
        println("Initial Market Status: ${if (tradeManager.isMarketOpen) "OPEN" else "CLOSED"}")
    }
}
