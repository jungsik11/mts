package com.mts.account.config

import com.mts.account.model.Account
import com.mts.account.model.Asset
import com.mts.account.model.User
import com.mts.account.repository.AccountRepository
import com.mts.account.repository.AssetRepository
import com.mts.account.repository.UserRepository
import org.slf4j.LoggerFactory
import org.springframework.boot.CommandLineRunner
import org.springframework.security.crypto.password.PasswordEncoder
import org.springframework.stereotype.Component
import org.springframework.transaction.annotation.Transactional
import java.util.concurrent.ThreadLocalRandom

@Component
class DataInitializer(
    private val userRepository: UserRepository,
    private val accountRepository: AccountRepository,
    private val assetRepository: AssetRepository,
    private val passwordEncoder: PasswordEncoder
) : CommandLineRunner {

    private val logger = LoggerFactory.getLogger(DataInitializer::class.java)

    private val sampleTickers = listOf(
        "005930", "000660", "373220", "207940", "005380", "000270", "005490", "051910", "035420", "006400",
        "068270", "105560", "055550", "035720", "012330", "003670", "010130", "086790", "034730", "018260"
    )

    @Transactional
    override fun run(vararg args: String?) {
        if (userRepository.existsById(2L)) {
            logger.info("Bot user data already initialized. Skipping.")
            return
        }

        logger.info("Start initializing bot user data...")

        // 1. Create Bot Users
        val hashedPassword = passwordEncoder.encode("password")
        val users = (2L..10001L).map { userId ->
            User(
                id = userId,
                username = "bot$userId",
                passwordHash = hashedPassword,
                name = "Bot $userId",
                email = "bot$userId@mts.com"
            )
        }
        userRepository.saveAll(users)
        logger.info("${users.size} bot users created.")

        // 2. Create Accounts with Cash
        val accounts = users.map { user ->
            Account(
                userId = user.id!!,
                accountNumber = generateBotAccountNumber(user.id!!),
                accountType = "BOT",
                balance = 1_000_000_000.0, // 10억 KRW
                isPrimary = true
            )
        }
        val savedAccounts = accountRepository.saveAll(accounts)
        logger.info("${savedAccounts.size} bot accounts created with initial cash.")

        // 3. Create Initial Asset Holdings
        val assetsToSave = mutableListOf<Asset>()
        for (account in savedAccounts) {
            // Grant stocks to about 50% of bots
            if (ThreadLocalRandom.current().nextDouble() < 0.5) {
                val numberOfStocks = ThreadLocalRandom.current().nextInt(3, 6)
                sampleTickers.shuffled().take(numberOfStocks).forEach { ticker ->
                    val quantity = ThreadLocalRandom.current().nextInt(10, 101)
                    val avgPrice = ThreadLocalRandom.current().nextDouble(50000.0, 200000.0)
                    
                    assetsToSave.add(
                        Asset(
                            accountId = account.id!!,
                            ticker = ticker,
                            quantity = quantity,
                            avgPrice = avgPrice
                        )
                    )
                }
            }
        }
        
        assetRepository.saveAll(assetsToSave)
        logger.info("${assetsToSave.size} initial asset holdings distributed to bots.")
        logger.info("Bot user data initialization complete.")
    }

    private fun generateBotAccountNumber(userId: Long): String {
        return "11-BOT-${userId.toString().padStart(8, '0')}"
    }
}
