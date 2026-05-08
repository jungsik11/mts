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
    fun initData(userRepository: UserRepository, accountRepository: AccountRepository, assetRepository: AssetRepository, passwordEncoder: PasswordEncoder): CommandLineRunner {
        return CommandLineRunner {
            // 1. Data Migration: Update existing accounts to new format (XXXXXXXX-YY)
            val allAccounts = accountRepository.findAll()
            val existingNumbers = allAccounts.map { it.accountNumber }.toMutableSet()
            
            allAccounts.forEach { acc ->
                if (!acc.accountNumber.matches(Regex("\\d{8}-\\d{2}"))) {
                    println("Migrating account: ${acc.accountNumber}")
                    var newAccNum: String
                    do {
                        val base = (10000000..99999999).random().toString()
                        val code = when (acc.accountType.uppercase()) {
                            "CMA" -> "21"
                            "PENSION", "연금", "연금 계좌" -> "22"
                            else -> "01" // CONSIGNMENT, ADMIN, BOT
                        }
                        newAccNum = "$base-$code"
                    } while (existingNumbers.contains(newAccNum))
                    
                    val oldNum = acc.accountNumber
                    acc.accountNumber = newAccNum
                    accountRepository.save(acc)
                    existingNumbers.remove(oldNum)
                    existingNumbers.add(newAccNum)
                    println("Account $oldNum migrated to $newAccNum")
                }
            }

            if (userRepository.findByUsername("admin") == null) {
                val admin = User(username = "admin", passwordHash = passwordEncoder.encode("admin123"), email = "admin@example.com", name = "System Administrator")
                userRepository.save(admin)
                accountRepository.save(Account(userId = admin.id, accountNumber = "10000000-01", accountType = "ADMIN", balance = 10000000.0, isPrimary = true))
                println("Admin created")
            }
            
            // Create 100 Bots
            for (i in 1..100) {
                val name = "BOT_${String.format("%02d", i)}"
                if (userRepository.findByUsername(name) == null) {
                    val bot = User(
                        username = name, 
                        passwordHash = passwordEncoder.encode("bot123"), 
                        email = "$name@mts.bot", 
                        name = "Trading Bot $i"
                    )
                    val savedBot = userRepository.save(bot)
                    
                    // Random balance between 100M and 1B KRW
                    val randomBalance = (100_000_000..1_000_000_000).random().toDouble()
                    
                    val savedAcc = accountRepository.save(Account(
                        userId = savedBot.id,
                        accountNumber = "9000${String.format("%04d", i)}-01",
                        accountType = "BOT",
                        balance = randomBalance,
                        isPrimary = true
                    ))
                    
                    // Seed random holdings (5-10 tickers per bot)
                    val allSeedTickers = listOf(
                        "005930", "000660", "035420", "035720", "005380", "068270", "000270", "005490", "051910", "105560",
                        "055550", "012330", "000810", "033780", "003550", "066570", "015760", "032830", "003670", "010130",
                        "069500", "122630", "114800", "252670" // Including some ETFs for bots too
                    )
                    val botTickers = allSeedTickers.shuffled().take((5..12).random())
                    
                    botTickers.forEach { ticker ->
                        assetRepository.save(Asset(
                            accountId = savedAcc.id,
                            ticker = ticker,
                            quantity = (100..5000).random(),
                            avgPrice = (10000..100000).random().toDouble()
                        ))
                    }
                    println("Bot $name created with ${botTickers.size} seed tickers and balance: $randomBalance")
                }
            }
        }
    }
}
