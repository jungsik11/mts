package com.mts.account.controller

import com.mts.account.repository.AccountRepository
import com.mts.account.repository.AssetRepository
import com.mts.account.repository.UserRepository
import org.springframework.web.bind.annotation.*

@RestController
@RequestMapping("/assets")
class AssetController(
    private val userRepository: UserRepository,
    private val accountRepository: AccountRepository,
    private val assetRepository: AssetRepository
) {
    @GetMapping("/{userId}")
    fun getUserAssets(@PathVariable userId: Long): Map<String, Any> {
        val user = userRepository.findById(userId).orElse(null) ?: return mapOf("error" to "User not found")
        val primaryAccount = accountRepository.findByUserIdAndIsPrimaryTrue(userId)
        val assets = assetRepository.findByUserId(userId)
        
        return mapOf(
            "cash_balance" to (primaryAccount?.balance ?: 0.0),
            "holdings" to assets.map { 
                mapOf(
                    "ticker" to it.ticker,
                    "quantity" to it.quantity,
                    "avg_price" to it.avgPrice
                )
            }
        )
    }
}
