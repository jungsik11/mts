package com.mts.account.repository

import com.mts.account.model.Asset
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.stereotype.Repository

@Repository
interface AssetRepository : JpaRepository<Asset, Long> {
    fun findByAccountId(accountId: Long): List<Asset>
    fun findByAccountIdAndTicker(accountId: Long, ticker: String): Asset?
}
