package com.mts.account.service

import com.mts.account.model.Account
import com.mts.account.repository.AccountRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional

@Service
class AccountService(
    private val accountRepository: AccountRepository
) {
    @Transactional
    fun createAccount(userId: Long, accountType: String): Account {
        val accountNumber = generateAccountNumber(accountType)
        val account = Account(
            userId = userId,
            accountNumber = accountNumber,
            accountType = accountType,
            balance = 0.0, // Default 0 KRW
            isPrimary = accountRepository.findByUserId(userId).isEmpty()
        )
        return accountRepository.save(account)
    }

    fun generateAccountNumber(type: String): String {
        val base = (10000000..99999999).random().toString()
        val code = when (type.uppercase()) {
            "CONSIGNMENT", "위탁계좌", "STOCK" -> "01"
            "CMA", "CMA 계좌" -> "21"
            "PENSION", "연금", "연금 계좌" -> "22"
            else -> "01"
        }
        return "$base-$code"
    }
}
