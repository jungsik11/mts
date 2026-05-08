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
        val accounts = accountRepository.findByUserId(userId)
        val primaryAccount = accounts.find { it.isPrimary } ?: accounts.firstOrNull()
        
        // Aggregate assets from all accounts for the overall view
        val allAssets = accounts.flatMap { assetRepository.findByAccountId(it.id) }
        val aggregatedHoldings = allAssets.groupBy { it.ticker }.map { (ticker, assets) ->
            val totalQty = assets.sumOf { it.quantity }
            val avgPrice = if (totalQty > 0) assets.sumOf { it.avgPrice * it.quantity } / totalQty else 0.0
            mapOf(
                "ticker" to ticker,
                "quantity" to totalQty,
                "avg_price" to avgPrice
            )
        }
        
        return mapOf(
            "cash_balance" to (primaryAccount?.balance ?: 0.0),
            "holdings" to aggregatedHoldings
        )
    }
}
