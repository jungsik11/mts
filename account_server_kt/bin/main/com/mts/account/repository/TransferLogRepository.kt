package com.mts.account.repository

import com.mts.account.model.TransferLog
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.stereotype.Repository

@Repository
interface TransferLogRepository : JpaRepository<TransferLog, Long> {
    fun findByFromAccountNumberOrToAccountNumberOrderByTimestampDesc(
        from: String, to: String
    ): List<TransferLog>
}
