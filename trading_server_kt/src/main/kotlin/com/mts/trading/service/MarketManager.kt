package com.mts.trading.service

import org.springframework.scheduling.annotation.Scheduled
import org.springframework.stereotype.Service
import java.time.LocalDateTime
import java.time.ZoneId

@Service
class MarketManager(private val tradeManager: TradeManager) {

    private val seoulZone = ZoneId.of("Asia/Seoul")

    @Scheduled(cron = "0 0 20 * * *", zone = "Asia/Seoul")
    fun closeKrMarket() {
        tradeManager.isKrMarketOpen = false
        tradeManager.saveClosingPrices()
        // tradeManager.clearAllBooks() // Keep books or clear based on policy
        println("KR Market Closed at ${LocalDateTime.now(seoulZone)}")
    }

    @Scheduled(cron = "0 0 8 * * *", zone = "Asia/Seoul")
    fun openKrMarket() {
        tradeManager.isKrMarketOpen = true
        println("KR Market Opened at ${LocalDateTime.now(seoulZone)}")
    }

    @Scheduled(cron = "0 0 17 * * *", zone = "Asia/Seoul")
    fun openUsMarket() {
        tradeManager.isUsMarketOpen = true
        println("US Market Opened at ${LocalDateTime.now(seoulZone)}")
    }

    @Scheduled(cron = "0 0 7 * * *", zone = "Asia/Seoul")
    fun closeUsMarket() {
        tradeManager.isUsMarketOpen = false
        tradeManager.saveClosingPrices()
        println("US Market Closed at ${LocalDateTime.now(seoulZone)}")
    }
    
    // For initialization: check current time and set status
    init {
        val now = LocalDateTime.now(seoulZone)
        tradeManager.isKrMarketOpen = now.hour in 8..19
        tradeManager.isUsMarketOpen = now.hour >= 17 || now.hour < 7
        println("Initial KR Market Status: ${if (tradeManager.isKrMarketOpen) "OPEN" else "CLOSED"}")
        println("Initial US Market Status: ${if (tradeManager.isUsMarketOpen) "OPEN" else "CLOSED"}")
    }
}
