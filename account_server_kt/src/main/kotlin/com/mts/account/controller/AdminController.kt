package com.mts.account.controller

import com.mts.account.model.User
import com.mts.account.model.Account
import com.mts.account.repository.AccountRepository
import com.mts.account.repository.UserRepository
import org.springframework.web.bind.annotation.*

@RestController
@RequestMapping("/admin")
@CrossOrigin(origins = ["*"]) // 어드민 웹앱 접속 허용
class AdminController(
    private val userRepository: UserRepository,
    private val accountRepository: AccountRepository
) {
    @GetMapping("/users")
    fun getAllUsers(): List<Map<String, Any>> {
        return userRepository.findAll().map { user ->
            val accounts = accountRepository.findByUserId(user.id)
            mapOf(
                "id" to user.id,
                "username" to user.username,
                "email" to user.email,
                "accounts" to accounts.map { 
                    mapOf(
                        "accountNumber" to it.accountNumber,
                        "accountType" to it.accountType,
                        "balance" to it.balance
                    )
                }
            )
        }
    }

    @PostMapping("/account/update-balance")
    fun updateBalance(@RequestBody req: UpdateBalanceRequest): Map<String, Any> {
        val account = accountRepository.findByAccountNumber(req.accountNumber)
            ?: return mapOf("status" to "Failure", "message" to "Account not found")
        
        account.balance = req.newBalance
        accountRepository.save(account)
        return mapOf("status" to "Success", "message" to "Balance updated")
    }
}

data class UpdateBalanceRequest(val accountNumber: String, val newBalance: Double)
