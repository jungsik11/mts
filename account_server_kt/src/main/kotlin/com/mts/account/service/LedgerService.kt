package com.mts.account.service

import com.mts.account.model.Asset
import com.mts.account.model.TradeLog
import com.mts.account.repository.AccountRepository
import com.mts.account.repository.AssetRepository
import com.mts.account.repository.TradeLogRepository
import com.mts.account.repository.UserRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional

@Service
class LedgerService(
    private val userRepository: UserRepository,
    private val accountRepository: AccountRepository,
    private val assetRepository: AssetRepository,
    private val tradeLogRepository: TradeLogRepository,
    private val transferLogRepository: com.mts.account.repository.TransferLogRepository
) {
    @Transactional
    fun marginCheck(userId: Long, ticker: String, side: String, price: Double, quantity: Int): Map<String, Any> {
        val isUsStock = ticker.any { it.isLetter() }
        val targetCurrency = if (isUsStock) "USD" else "KRW"
        
        val account = accountRepository.findByUserIdAndIsPrimaryTrue(userId)
            ?: return mapOf("allowed" to false, "reason" to "Account not found")
        
        if (account.accountType !in listOf("CONSIGNMENT", "BOT", "ADMIN")) {
            return mapOf("allowed" to false, "reason" to "Only Consignment, Bot, or Admin accounts can trade.")
        }

        if (side == "BUY") {
            val totalCost = price * quantity
            if (targetCurrency == "USD") {
                if (account.usdBalance < totalCost) {
                    return mapOf("allowed" to false, "reason" to "Insufficient USD balance: Needed $totalCost, Available ${account.usdBalance}")
                }
                account.usdBalance -= totalCost
                accountRepository.save(account)
                println("Margin Locked for User $userId: -$totalCost USD | New USD Balance: ${account.usdBalance}")
            } else {
                if (account.balance < totalCost) {
                    return mapOf("allowed" to false, "reason" to "Insufficient balance: Needed $totalCost, Available ${account.balance}")
                }
                account.balance -= totalCost
                accountRepository.save(account)
                println("Margin Locked for User $userId: -$totalCost | New Balance: ${account.balance}")
            }
        } else { // SELL
            val asset = assetRepository.findByAccountIdAndTicker(account.id, ticker)
            if (asset == null || asset.quantity < quantity) {
                return mapOf("allowed" to false, "reason" to "Insufficient stock holdings")
            }
            // Asset Locking: Deduct shares immediately upon order placement
            asset.quantity -= quantity
            if (asset.quantity == 0) {
                assetRepository.delete(asset)
            } else {
                assetRepository.save(asset)
            }
            println("Asset Locked for User $userId: -$quantity $ticker | Remaining: ${asset.quantity}")
        }
        return mapOf("allowed" to true)
    }

    @Transactional
    fun settleTrade(buyerId: Long, sellerId: Long, ticker: String, price: Double, quantity: Int) {
        println("Settling Trade: Buyer($buyerId) -> Seller($sellerId) | $ticker: $quantity@$price")
        val totalMatchValue = price * quantity
        val isUsStock = ticker.any { it.isLetter() }
        val targetCurrency = if (isUsStock) "USD" else "KRW"

        // 1. Update Seller Balance
        val sellerAccount = accountRepository.findByUserIdAndIsPrimaryTrue(sellerId)!!
        if (targetCurrency == "USD") {
            sellerAccount.usdBalance += totalMatchValue
        } else {
            sellerAccount.balance += totalMatchValue
        }
        accountRepository.save(sellerAccount)

        // 2. Update Buyer Assets
        val buyerAccount = accountRepository.findByUserIdAndIsPrimaryTrue(buyerId)!!
        val buyerAsset = assetRepository.findByAccountIdAndTicker(buyerAccount.id, ticker)
        if (buyerAsset != null) {
            val newQty = buyerAsset.quantity + quantity
            buyerAsset.avgPrice = ((buyerAsset.avgPrice * buyerAsset.quantity) + totalMatchValue) / newQty
            buyerAsset.quantity = newQty
            assetRepository.save(buyerAsset)
        } else {
            assetRepository.save(Asset(accountId = buyerAccount.id, ticker = ticker, quantity = quantity, avgPrice = price))
        }

        // 3. Buyer Refund (If match price is lower than the price locked during marginCheck)
        // Since we don't know the original order price here, we'd need to pass it or just settle at match price.
        // For simplicity in this simulation, we assume the marginCheck locked exactly what was needed.
        // In a real system, the 'price' passed to marginCheck is the limit price, and 'price' here is match price.

        tradeLogRepository.save(TradeLog(
            buyerId = buyerId,
            sellerId = sellerId,
            ticker = ticker,
            price = price,
            quantity = quantity
        ))
    }

    @Transactional
    fun transfer(fromAccountNumber: String, toAccountNumber: String, amount: Double): Map<String, Any> {
        val fromAccount = accountRepository.findByAccountNumber(fromAccountNumber)
            ?: return mapOf("status" to "Failure", "message" to "Source account not found")
        val toAccount = accountRepository.findByAccountNumber(toAccountNumber)
            ?: return mapOf("status" to "Failure", "message" to "Destination account not found")

        if (fromAccount.balance < amount) {
            return mapOf("status" to "Failure", "message" to "Insufficient funds")
        }

        fromAccount.balance -= amount
        toAccount.balance += amount

        accountRepository.save(fromAccount)
        accountRepository.save(toAccount)

        transferLogRepository.save(com.mts.account.model.TransferLog(
            fromAccountNumber = fromAccountNumber,
            toAccountNumber = toAccountNumber,
            amount = amount
        ))

        return mapOf("status" to "Success", "message" to "Transfer complete")
    }

    fun getTransferHistory(accountNumber: String): List<com.mts.account.model.TransferLog> {
        return transferLogRepository.findByFromAccountNumberOrToAccountNumberOrderByTimestampDesc(accountNumber, accountNumber)
    }
}
