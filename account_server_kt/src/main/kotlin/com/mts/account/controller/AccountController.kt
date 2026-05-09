package com.mts.account.controller

import com.mts.account.repository.AccountRepository
import com.mts.account.service.LedgerService
import org.springframework.web.bind.annotation.*

@RestController
@RequestMapping("/account")
class AccountController(
    private val accountRepository: AccountRepository,
    private val ledgerService: LedgerService,
    private val accountService: com.mts.account.service.AccountService
) {
    @GetMapping("/list/{userId}")
    fun listAccounts(@PathVariable userId: Long): List<Map<String, Any>> {
        return accountRepository.findByUserId(userId).map {
            mapOf(
                "id" to it.id,
                "accountNumber" to it.accountNumber,
                "accountType" to it.accountType,
                "balance" to it.balance,
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
}

data class TransferRequest(val fromAccountNumber: String, val toAccountNumber: String, val amount: Double)
data class CreateAccountRequest(val userId: Long, val accountType: String)
