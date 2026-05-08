package com.mts.account.repository

import com.mts.account.model.TradeLog
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.stereotype.Repository

@Repository
interface TradeLogRepository : JpaRepository<TradeLog, Long> {
    fun findByBuyerIdOrSellerIdOrderByTimestampDesc(buyerId: Long, sellerId: Long): List<TradeLog>
    fun findByTickerOrderByTimestampDesc(ticker: String): List<TradeLog>
}
