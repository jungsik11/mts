package com.mts.account.repository

import com.mts.account.model.Asset
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.stereotype.Repository

@Repository
interface AssetRepository : JpaRepository<Asset, Long> {
    fun findByAccountId(accountId: Long): List<Asset>
    fun findByAccountIdAndTicker(accountId: Long, ticker: String): Asset?

    @org.springframework.data.jpa.repository.Modifying
    @org.springframework.transaction.annotation.Transactional
    @org.springframework.data.jpa.repository.Query("DELETE FROM Asset a WHERE a.accountId IN :accountIds AND a.ticker NOT IN :tickers")
    fun deleteByAccountIdInAndTickerNotIn(accountIds: List<Long>, tickers: List<String>)
}
