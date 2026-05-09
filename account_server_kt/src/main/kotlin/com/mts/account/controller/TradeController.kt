package com.mts.account.controller

import com.mts.account.model.TradeLog
import com.mts.account.repository.TradeLogRepository
import org.springframework.web.bind.annotation.*

@RestController
@RequestMapping("/trades")
class TradeController(private val tradeLogRepository: TradeLogRepository) {

    @GetMapping("/user/{userId}")
    fun getUserTrades(@PathVariable userId: Long): List<TradeLog> {
        return tradeLogRepository.findByBuyerIdOrSellerIdOrderByTimestampDesc(userId, userId)
    }

    @GetMapping("/user/{userId}/{ticker}")
    fun getUserTradesForTicker(@PathVariable userId: Long, @PathVariable ticker: String): List<TradeLog> {
        // Filter in memory for simplicity or add repository method
        return tradeLogRepository.findByBuyerIdOrSellerIdOrderByTimestampDesc(userId, userId)
            .filter { it.ticker == ticker }
    }
}
