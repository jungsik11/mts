package com.mts.account.config

import com.mts.account.model.Account
import com.mts.account.model.User
import com.mts.account.model.Asset
import com.mts.account.repository.AccountRepository
import com.mts.account.repository.UserRepository
import com.mts.account.repository.AssetRepository
import org.springframework.boot.CommandLineRunner
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.security.crypto.password.PasswordEncoder

@Configuration
class DataInitializer {

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
            // assetRepository.deleteByTickerNotIn(allSeedTickers) // Dangerous if not careful, keep it commented or use wisely
            
            createTestUsers(userRepository, accountRepository, passwordEncoder)
            createNewBots(userRepository, accountRepository, assetRepository, passwordEncoder, allSeedTickers, allUsTickers)

            println("Data initialization finished successfully.")
        }
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
        val adminUsername = System.getenv("INITIAL_ADMIN_USERNAME") ?: "admin"
        val adminPassword = System.getenv("INITIAL_ADMIN_PASSWORD") ?: "admin123"
        if (userRepository.findByUsername(adminUsername) == null) {
            val admin = User(username = adminUsername, passwordHash = passwordEncoder.encode(adminPassword), name = "System Administrator")
            val savedAdmin = userRepository.save(admin)
            accountRepository.save(Account(userId = savedAdmin.id, accountNumber = "10000000-01", accountType = "ADMIN", balance = 10000000.0, isPrimary = true))
        }
    }

    private fun createTestUsers(userRepository: UserRepository, accountRepository: AccountRepository, passwordEncoder: PasswordEncoder) {
        val testUser = System.getenv("INITIAL_TEST_USER") ?: "user1"
        val testPassword = System.getenv("INITIAL_TEST_PASSWORD") ?: "user123"
        if (userRepository.findByUsername(testUser) == null) {
            val user = userRepository.save(User(username = testUser, passwordHash = passwordEncoder.encode(testPassword), name = "Test User 1", email = "user1@example.com"))
            accountRepository.save(Account(userId = user.id, accountNumber = "11111111-01", accountType = "CONSIGNMENT", balance = 50000000.0, usdBalance = 10000.0, isPrimary = true))
        }
    }

    private fun createNewBots(userRepository: UserRepository, accountRepository: AccountRepository, assetRepository: AssetRepository, passwordEncoder: PasswordEncoder, allSeedTickers: List<String>, allUsTickers: List<String>) {
        val existingBotUsernames = userRepository.findUsernamesByUsernameStartingWith("BOT_").toHashSet()
        if (existingBotUsernames.size >= 10000) {
            println("Existing bots found (${existingBotUsernames.size}), skipping massive creation.")
            return
        }

        println("Creating bots and seeding assets...")
        val krTickers = allSeedTickers.filter { it.all { c -> c.isDigit() } }
        val encodedBotPassword = passwordEncoder.encode("bot123")

        for (i in 1..10000) { 
            val name = "BOT_${String.format("%04d", i)}"
            if (!existingBotUsernames.contains(name)) {
                val bot = userRepository.save(User(username = name, passwordHash = encodedBotPassword, email = "$name@mts.bot", name = "Trading Bot $i"))
                val acc = accountRepository.save(Account(userId = bot.id, accountNumber = "9${String.format("%07d", i)}-01", accountType = "BOT", balance = (10_000_000..100_000_000).random().toDouble(), usdBalance = (1_000..50_000).random().toDouble(), isPrimary = true))
                
                // Seed KR Stocks
                krTickers.shuffled().take((3..7).random()).forEach { ticker ->
                    assetRepository.save(Asset(accountId = acc.id, ticker = ticker, quantity = (10..500).random(), avgPrice = (10000..100000).random().toDouble()))
                }
                // Seed US Stocks
                allUsTickers.shuffled().take((2..5).random()).forEach { ticker ->
                    assetRepository.save(Asset(accountId = acc.id, ticker = ticker, quantity = (5..100).random(), avgPrice = (50..500).random().toDouble()))
                }
            }
        }
        println("Bot creation finished.")
    }
}
