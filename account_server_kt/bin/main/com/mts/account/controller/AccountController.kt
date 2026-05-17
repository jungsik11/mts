package com.mts.account.controller

import com.mts.account.repository.AccountRepository
import com.mts.account.service.LedgerService
import org.springframework.web.bind.annotation.*

@RestController
@RequestMapping("/account")
class AccountController(
    private val userRepository: com.mts.account.repository.UserRepository,
    private val accountRepository: AccountRepository,
    private val ledgerService: LedgerService,
    private val accountService: com.mts.account.service.AccountService
) {
    @GetMapping("/profile/{userId}")
    fun getProfile(@PathVariable userId: Long): Map<String, Any?> {
        val user = userRepository.findById(userId).orElseThrow { Exception("User not found") }
        return mapOf(
            "userId" to user.id,
            "username" to user.username,
            "name" to user.name,
            "email" to user.email,
            "rrn" to user.rrn,
            "phone" to user.phone,
            "address" to user.address,
            "job" to user.job,
            "workplace" to user.workplace
        )
    }

    @GetMapping("/list/{userId}")
    fun listAccounts(@PathVariable userId: Long): List<Map<String, Any>> {
        return accountRepository.findByUserId(userId).map {
            mapOf(
                "id" to it.id,
                "accountNumber" to it.accountNumber,
                "accountType" to it.accountType,
                "balance" to it.balance,
                "usdBalance" to it.usdBalance,
                "isPrimary" to it.isPrimary
            )
        }
    }

    @PostMapping("/create")
    fun createAccount(@RequestBody req: CreateAccountRequest): Map<String, Any> {
        val account = accountService.createAccount(req.userId, req.accountType)
        return mapOf(
            "status" to "Success",
            "accountNumber" to account.accountNumber,
            "accountType" to account.accountType
        )
    }

    @PostMapping("/transfer")
    fun transfer(@RequestBody req: TransferRequest): Map<String, Any> {
        return ledgerService.transfer(req.fromAccountNumber, req.toAccountNumber, req.amount)
    }

    @GetMapping("/transfer/history/{accountNumber}")
    fun getTransferHistory(@PathVariable accountNumber: String): List<com.mts.account.model.TransferLog> {
        return ledgerService.getTransferHistory(accountNumber)
    }
}

data class TransferRequest(val fromAccountNumber: String, val toAccountNumber: String, val amount: Double)
data class CreateAccountRequest(val userId: Long, val accountType: String)
