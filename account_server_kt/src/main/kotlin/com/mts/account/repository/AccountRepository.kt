package com.mts.account.repository

import com.mts.account.model.Account
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.stereotype.Repository

@Repository
interface AccountRepository : JpaRepository<Account, Long> {
    fun findByUserId(userId: Long): List<Account>
    fun findByAccountNumber(accountNumber: String): Account?
    fun findByUserIdAndIsPrimaryTrue(userId: Long): Account?
}
