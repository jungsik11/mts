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
    private val tradeLogRepository: TradeLogRepository
) {
    fun marginCheck(userId: Long, ticker: String, side: String, price: Double, quantity: Int): Map<String, Any> {
        val account = accountRepository.findByUserIdAndIsPrimaryTrue(userId) 
            ?: return mapOf("allowed" to false, "reason" to "Primary account not found")
        
        if (account.accountType !in listOf("CONSIGNMENT", "BOT", "ADMIN")) {
            return mapOf("allowed" to false, "reason" to "Only Consignment, Bot, or Admin accounts can trade. Current: ${account.accountType}")
        }

        if (side == "BUY") {
            val totalCost = price * quantity
            if (account.balance < totalCost) {
                return mapOf("allowed" to false, "reason" to "Insufficient balance in consignment account")
            }
        } else { // SELL
            val asset = assetRepository.findByAccountIdAndTicker(account.id, ticker)
            if (asset == null || asset.quantity < quantity) {
                return mapOf("allowed" to false, "reason" to "Insufficient stock holdings")
            }
        }
        return mapOf("allowed" to true)
    }

    @Transactional
    fun settleTrade(buyerId: Long, sellerId: Long, ticker: String, price: Double, quantity: Int) {
        println("Settling Trade: Buyer($buyerId) -> Seller($sellerId) | $ticker: $quantity@$price")
        val totalCost = price * quantity

        val buyerAccount = accountRepository.findByUserIdAndIsPrimaryTrue(buyerId)!!
        buyerAccount.balance -= totalCost
        accountRepository.save(buyerAccount)

        val buyerAsset = assetRepository.findByAccountIdAndTicker(buyerAccount.id, ticker)
        if (buyerAsset != null) {
            val newQty = buyerAsset.quantity + quantity
            buyerAsset.avgPrice = ((buyerAsset.avgPrice * buyerAsset.quantity) + totalCost) / newQty
            buyerAsset.quantity = newQty
            assetRepository.save(buyerAsset)
        } else {
            assetRepository.save(Asset(accountId = buyerAccount.id, ticker = ticker, quantity = quantity, avgPrice = price))
        }

        val sellerAccount = accountRepository.findByUserIdAndIsPrimaryTrue(sellerId)!!
        sellerAccount.balance += totalCost
        accountRepository.save(sellerAccount)

        val sellerAsset = assetRepository.findByAccountIdAndTicker(sellerAccount.id, ticker)
        if (sellerAsset != null) {
            sellerAsset.quantity -= quantity
            if (sellerAsset.quantity <= 0) {
                assetRepository.delete(sellerAsset)
            } else {
                assetRepository.save(sellerAsset)
            }
        }

        tradeLogRepository.save(TradeLog(
            buyerId = buyerId,
            sellerId = sellerId,
            ticker = ticker,
            price = price.toInt(),
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

        return mapOf("status" to "Success", "message" to "Transfer complete")
    }
}
