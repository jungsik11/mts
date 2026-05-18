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

<<<<<<< HEAD
    @Bean
    fun initData(
        userRepository: UserRepository, 
        accountRepository: AccountRepository, 
        assetRepository: AssetRepository, 
        passwordEncoder: PasswordEncoder
    ): CommandLineRunner {
        return CommandLineRunner {
            migrateAccounts(accountRepository)
            createAdmin(userRepository, accountRepository, passwordEncoder)
            
            val baseTickers = listOf("005930", "000660", "035420", "035720", "005380", "005490", "000270", "068270", "006400", "051910")
            val krMockTickers = (100..999).map { "K$it" }
            val allUsTickers = TickerData.getUsTickers()
            val allSeedTickers = (baseTickers + krMockTickers + allUsTickers).distinct()

            println("Performing global asset cleanup...")
            assetRepository.deleteByTickerNotIn(allSeedTickers)
            
            createNewBots(userRepository, accountRepository, assetRepository, passwordEncoder, allSeedTickers, allUsTickers)

            println("Data initialization finished successfully.")
=======
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
>>>>>>> origin/feature/app-menu-dev
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

    private fun migrateAccounts(accountRepository: AccountRepository) {
        val allAccounts = accountRepository.findAll()
        val accountsToMigrate = allAccounts.filter { !it.accountNumber.matches(Regex("\\d{8}-\\d{2}")) }
        if (accountsToMigrate.isNotEmpty()) {
            val existingNumbers = allAccounts.map { it.accountNumber }.toMutableSet()
            accountsToMigrate.forEach { acc ->
                var newAccNum: String
                do {
                    val base = (10000000..99999999).random().toString()
                    val code = when (acc.accountType.uppercase()) {
                        "CMA" -> "21"
                        "PENSION", "연금" -> "22"
                        else -> "01"
                    }
                    newAccNum = "$base-$code"
                } while (existingNumbers.contains(newAccNum))
                acc.accountNumber = newAccNum
                accountRepository.save(acc)
                existingNumbers.add(newAccNum)
            }
        }
    }

    private fun createAdmin(userRepository: UserRepository, accountRepository: AccountRepository, passwordEncoder: PasswordEncoder) {
        if (userRepository.findByUsername("admin") == null) {
            val admin = User(username = "admin", passwordHash = passwordEncoder.encode("admin123"), name = "System Administrator")
            val savedAdmin = userRepository.save(admin)
            accountRepository.save(Account(userId = savedAdmin.id, accountNumber = "10000000-01", accountType = "ADMIN", balance = 10000000.0, isPrimary = true))
        }
    }

    private fun createNewBots(userRepository: UserRepository, accountRepository: AccountRepository, assetRepository: AssetRepository, passwordEncoder: PasswordEncoder, allSeedTickers: List<String>, allUsTickers: List<String>) {
        val existingBots = userRepository.findAll().filter { it.username.startsWith("BOT_") }.map { it.username }.toSet()
        var createdCount = 0
        for (i in 1..10000) {
            val name = "BOT_${String.format("%04d", i)}"
            if (!existingBots.contains(name)) {
                val bot = userRepository.save(User(username = name, passwordHash = passwordEncoder.encode("bot123"), email = "$name@mts.bot", name = "Trading Bot $i"))
                val acc = accountRepository.save(Account(userId = bot.id, accountNumber = "9${String.format("%07d", i)}-01", accountType = "BOT", balance = (100_000_000..1_000_000_000).random().toDouble(), usdBalance = (50_000..500_000).random().toDouble(), isPrimary = true))
                
                allSeedTickers.filter { it.all { c -> c.isDigit() } }.shuffled().take((5..15).random()).forEach { ticker ->
                    assetRepository.save(Asset(accountId = acc.id, ticker = ticker, quantity = (100..5000).random(), avgPrice = (10000..100000).random().toDouble()))
                }
                allUsTickers.shuffled().take((3..8).random()).forEach { ticker ->
                    assetRepository.save(Asset(accountId = acc.id, ticker = ticker, quantity = (10..500).random(), avgPrice = (50..400).random().toDouble()))
                }
                createdCount++
            }
        }
        if (createdCount > 0) println("$createdCount new bots created.")
    }
}
