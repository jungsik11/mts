package com.mts.account.controller

import com.mts.account.model.TradeLog
import com.mts.account.repository.TradeLogRepository
import org.springframework.web.bind.annotation.*

@RestController
@RequestMapping("/market")
@CrossOrigin(origins = ["*"])
class MarketDataController(private val tradeLogRepository: TradeLogRepository) {

    @GetMapping("/trades/{ticker}")
    fun getMarketTrades(@PathVariable ticker: String): List<TradeLog> {
        return tradeLogRepository.findByTickerOrderByTimestampDesc(ticker).take(50)
    }
}
