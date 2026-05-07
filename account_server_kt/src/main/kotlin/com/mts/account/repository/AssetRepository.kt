package com.mts.account.repository

import com.mts.account.model.Asset
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.stereotype.Repository

@Repository
interface AssetRepository : JpaRepository<Asset, Long> {
    fun findByUserId(userId: Long): List<Asset>
    fun findByUserIdAndTicker(userId: Long, ticker: String): Asset?
}
