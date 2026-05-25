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
                account.lockedUsdBalance += totalCost
                accountRepository.save(account)
                println("Margin Locked for User $userId: -$totalCost USD | New USD Balance: ${account.usdBalance}")
            } else {
                if (account.balance < totalCost) {
                    return mapOf("allowed" to false, "reason" to "Insufficient balance: Needed $totalCost, Available ${account.balance}")
                }
                account.balance -= totalCost
                account.lockedBalance += totalCost
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
            asset.lockedQuantity += quantity
            if (asset.quantity == 0 && asset.lockedQuantity == 0) {
                assetRepository.delete(asset)
            } else {
                assetRepository.save(asset)
            }
            println("Asset Locked for User $userId: -$quantity $ticker | Remaining: ${asset.quantity}")
        }
        return mapOf("allowed" to true)
    }

    @Transactional
    fun settleTrade(buyerId: Long, sellerId: Long, ticker: String, price: Double, quantity: Int, buyerOrderPrice: Double) {
        println("Settling Trade: Buyer($buyerId) -> Seller($sellerId) | $ticker: $quantity@$price (Buyer Order Price: $buyerOrderPrice)")
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

        // 2. Update Buyer Assets and Unlock Margin
        val buyerAccount = accountRepository.findByUserIdAndIsPrimaryTrue(buyerId)!!
        
        val lockedCost = buyerOrderPrice * quantity
        if (targetCurrency == "USD") {
            buyerAccount.lockedUsdBalance -= lockedCost
        } else {
            buyerAccount.lockedBalance -= lockedCost
        }

        val buyerAsset = assetRepository.findByAccountIdAndTicker(buyerAccount.id, ticker)
        if (buyerAsset != null) {
            val newQty = buyerAsset.quantity + quantity
            buyerAsset.avgPrice = ((buyerAsset.avgPrice * buyerAsset.quantity) + totalMatchValue) / newQty
            buyerAsset.quantity = newQty
            assetRepository.save(buyerAsset)
        } else {
            assetRepository.save(Asset(accountId = buyerAccount.id, ticker = ticker, quantity = quantity, avgPrice = price))
        }

        // 3. Buyer Refund (Match price lower than locked price)
        if (buyerOrderPrice > price) {
            val refundAmount = (buyerOrderPrice - price) * quantity
            if (targetCurrency == "USD") {
                buyerAccount.usdBalance += refundAmount
            } else {
                buyerAccount.balance += refundAmount
            }
            println("Refunded $refundAmount $targetCurrency to Buyer $buyerId")
        }
        accountRepository.save(buyerAccount)

        // 4. Update Seller Locked Quantity
        val sellerAsset = assetRepository.findByAccountIdAndTicker(sellerAccount.id, ticker)
        if (sellerAsset != null) {
            sellerAsset.lockedQuantity -= quantity
            if (sellerAsset.quantity == 0 && sellerAsset.lockedQuantity == 0) {
                assetRepository.delete(sellerAsset)
            } else {
                assetRepository.save(sellerAsset)
            }
        }

        tradeLogRepository.save(TradeLog(
            buyerId = buyerId,
            sellerId = sellerId,
            ticker = ticker,
            price = price,
            quantity = quantity
        ))
    }

    @Transactional
    fun unlockOrder(userId: Long, ticker: String, side: String, price: Double, quantity: Int) {
        val isUsStock = ticker.any { it.isLetter() }
        val targetCurrency = if (isUsStock) "USD" else "KRW"
        val account = accountRepository.findByUserIdAndIsPrimaryTrue(userId) ?: return

        if (side == "BUY") {
            val amountToUnlock = price * quantity
            if (targetCurrency == "USD") {
                account.usdBalance += amountToUnlock
                account.lockedUsdBalance -= amountToUnlock
            } else {
                account.balance += amountToUnlock
                account.lockedBalance -= amountToUnlock
            }
            accountRepository.save(account)
            println("Unlocked $amountToUnlock $targetCurrency for User $userId (Order Cancelled/Expired)")
        } else {
            val asset = assetRepository.findByAccountIdAndTicker(account.id, ticker)
            if (asset != null) {
                asset.quantity += quantity
                asset.lockedQuantity -= quantity
                assetRepository.save(asset)
            } else {
                // Technically if asset was deleted, we recreate it, though it shouldn't be deleted if lockedQuantity > 0
                val newAsset = Asset(accountId = account.id, ticker = ticker, quantity = quantity, avgPrice = price)
                assetRepository.save(newAsset)
            }
            println("Unlocked $quantity shares of $ticker for User $userId (Order Cancelled/Expired)")
        }
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
