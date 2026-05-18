package com.mts.account.service

import com.mts.account.model.Asset
import com.mts.account.model.TradeLog
import com.mts.account.repository.AccountRepository
import com.mts.account.repository.AssetRepository
import com.mts.account.repository.TradeLogRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import org.slf4j.LoggerFactory

@Service
class LedgerService(
    private val accountRepository: AccountRepository,
    private val assetRepository: AssetRepository,
    private val tradeLogRepository: TradeLogRepository,
    private val transferLogRepository: com.mts.account.repository.TransferLogRepository
) {
    private val logger = LoggerFactory.getLogger(LedgerService::class.java)

    @Transactional
    fun marginCheck(userId: Long, ticker: String, side: String, price: Double, quantity: Int): Map<String, Any> {
        val account = accountRepository.findByUserIdAndIsPrimaryTrue(userId)
            ?: return mapOf("allowed" to false, "reason" to "Primary account not found")

        if (account.accountType !in listOf("CONSIGNMENT", "BOT", "ADMIN")) {
            return mapOf("allowed" to false, "reason" to "Only Consignment, Bot, or Admin accounts can trade.")
        }

        if (side == "BUY") {
            val totalCost = price * quantity
            if (account.balance < totalCost) {
                return mapOf("allowed" to false, "reason" to "Insufficient balance: Needed $totalCost, Available ${account.balance}")
            }
            account.balance -= totalCost
            account.lockedBalance += totalCost
            accountRepository.save(account)
            logger.info("Locked balance for User $userId: $totalCost | New Available: ${account.balance}")
        } else { // SELL
            val asset = assetRepository.findByAccountIdAndTicker(account.id, ticker)
            if (asset == null || asset.quantity < quantity) {
                return mapOf("allowed" to false, "reason" to "Insufficient stock holdings for $ticker")
            }
            asset.quantity -= quantity
            asset.lockedQuantity += quantity
            assetRepository.save(asset)
            logger.info("Locked assets for User $userId: $quantity of $ticker | New Available: ${asset.quantity}")
        }
        return mapOf("allowed" to true)
    }

    @Transactional
    fun unlockOrder(userId: Long, ticker: String, side: String, price: Double, quantity: Int) {
        val account = accountRepository.findByUserIdAndIsPrimaryTrue(userId)
            ?: run {
                logger.error("Cannot unlock order: Primary account not found for user $userId")
                return
            }

        if (side == "BUY") {
            val totalCost = price * quantity
            if (account.lockedBalance < totalCost) {
                logger.warn("Unlock warning: Locked balance (${account.lockedBalance}) is less than unlock amount ($totalCost) for user $userId.")
            }
            account.lockedBalance -= totalCost
            account.balance += totalCost
            accountRepository.save(account)
            logger.info("Unlocked balance for User $userId: $totalCost | New Available: ${account.balance}")
        } else { // SELL
            val asset = assetRepository.findByAccountIdAndTicker(account.id, ticker)
            if (asset == null) {
                 logger.warn("Unlock warning: Asset $ticker not found for user $userId, creating it to unlock.")
                 assetRepository.save(Asset(accountId = account.id, ticker = ticker, quantity = quantity, lockedQuantity = 0, avgPrice = 0.0))
            } else {
                if (asset.lockedQuantity < quantity) {
                    logger.warn("Unlock warning: Locked quantity (${asset.lockedQuantity}) is less than unlock quantity ($quantity) for $ticker on user $userId.")
                }
                asset.lockedQuantity -= quantity
                asset.quantity += quantity
                assetRepository.save(asset)
                logger.info("Unlocked assets for User $userId: $quantity of $ticker | New Available: ${asset.quantity}")
            }
        }
    }

    @Transactional
    fun settleTrade(buyerId: Long, sellerId: Long, ticker: String, price: Double, quantity: Int, buyerOrderPrice: Double) {
        logger.info("Settling Trade: Buyer($buyerId) -> Seller($sellerId) | $ticker: $quantity@$price")
        val totalMatchValue = price * quantity
        val buyerTotalLockedValue = buyerOrderPrice * quantity

        // 1. Update Seller
        val sellerAccount = accountRepository.findByUserIdAndIsPrimaryTrue(sellerId)!!
        val sellerAsset = assetRepository.findByAccountIdAndTicker(sellerAccount.id, ticker)!!

        sellerAccount.balance += totalMatchValue
        sellerAsset.lockedQuantity -= quantity
        
        accountRepository.save(sellerAccount)
        if (sellerAsset.quantity == 0 && sellerAsset.lockedQuantity == 0) {
            assetRepository.delete(sellerAsset)
        } else {
            assetRepository.save(sellerAsset)
        }

        // 2. Update Buyer
        val buyerAccount = accountRepository.findByUserIdAndIsPrimaryTrue(buyerId)!!
        val buyerAsset = assetRepository.findByAccountIdAndTicker(buyerAccount.id, ticker)

        buyerAccount.lockedBalance -= buyerTotalLockedValue
        val refund = buyerTotalLockedValue - totalMatchValue
        if (refund > 0) {
            buyerAccount.balance += refund
        }
        
        if (buyerAsset != null) {
            val newQty = buyerAsset.quantity + quantity
            val currentTotalValue = buyerAsset.avgPrice * buyerAsset.quantity
            buyerAsset.avgPrice = (currentTotalValue + totalMatchValue) / newQty
            buyerAsset.quantity = newQty
            assetRepository.save(buyerAsset)
        } else {
            assetRepository.save(Asset(accountId = buyerAccount.id, ticker = ticker, quantity = quantity, avgPrice = price))
        }
        accountRepository.save(buyerAccount)

        // 3. Log Trade
        tradeLogRepository.save(TradeLog(
            buyerId = buyerId,
            sellerId = sellerId,
            ticker = ticker,
            price = price.toInt(),
            quantity = quantity
        ))
    }
    
    // Other methods remain the same
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
