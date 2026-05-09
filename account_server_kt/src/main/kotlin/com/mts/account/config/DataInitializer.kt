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
            val allAccounts = accountRepository.findAll()
            val accountsToMigrate = allAccounts.filter { !it.accountNumber.matches(Regex("\\d{8}-\\d{2}")) }
            
            if (accountsToMigrate.isNotEmpty()) {
                val existingNumbers = allAccounts.map { it.accountNumber }.toMutableSet()
                println("Migrating ${accountsToMigrate.size} accounts...")
                accountsToMigrate.forEach { acc ->
                    var newAccNum: String
                    do {
                        val base = (10000000..99999999).random().toString()
                        val code = when (acc.accountType.uppercase()) {
                            "CMA" -> "21"
                            "PENSION", "연금", "연금 계좌" -> "22"
                            else -> "01"
                        }
                        newAccNum = "$base-$code"
                    } while (existingNumbers.contains(newAccNum))
                    
                    acc.accountNumber = newAccNum
                    accountRepository.save(acc)
                    existingNumbers.add(newAccNum)
                }
                println("Migration complete.")
            }

            if (userRepository.findByUsername("admin") == null) {
                val admin = User(username = "admin", passwordHash = passwordEncoder.encode("admin123"), email = "admin@example.com", name = "System Administrator")
                userRepository.save(admin)
                accountRepository.save(Account(userId = admin.id, accountNumber = "10000000-01", accountType = "ADMIN", balance = 10000000.0, isPrimary = true))
                println("Admin created")
            }
            
            // Create 100 Bots
            val allSeedTickers = listOf(
                "005930", "000660", "373220", "207940", "005380", "000270", "005490", "051910", "035420", "006400",
                "068270", "105560", "055550", "035720", "012330", "000810", "033780", "003550", "066570", "015760",
                "032830", "003670", "010130", "086790", "028260", "011780", "010950", "009150", "034730", "018260",
                "000100", "036570", "009540", "034220", "017670", "024110", "000720", "051900", "011200", "005940",
                "047050", "251270", "021240", "001450", "000120", "004020", "071050", "097950", "006800", "011070",
                "011170", "007070", "023530", "004800", "000080", "008770", "128940", "000990", "090430", "064350",
                "001040", "030200", "042660", "001740", "005830", "010620", "039490", "002380", "000210", "000240",
                "247540", "086520", "068760", "263750", "293480", "028300", "112040", "035900", "253450", "058470",
                "196170", "214150", "278280", "036930", "041510", "067310", "145020", "056190", "084990", "096530",
                "039030", "277810", "214430", "121600", "034230", "036810", "053030", "089010", "048410", "131970",
                "069500", "122630", "114800", "252670", "229200", "233740", "251340", "305720", "277630", "152330",
                "272580", "261220"
            )

            // Create 100 Bots
            val existingBots = userRepository.findAll().filter { it.username.startsWith("BOT_") }.map { it.username }.toSet()
            var createdCount = 0
            
            for (i in 1..1000) {
                val name = "BOT_${String.format("%02d", i)}"
                if (!existingBots.contains(name)) {
                    val bot = User(
                        username = name, 
                        passwordHash = passwordEncoder.encode("bot123"), 
                        email = "$name@mts.bot", 
                        name = "Trading Bot $i"
                    )
                    val savedBot = userRepository.save(bot)
                    val randomBalance = (100_000_000..1_000_000_000).random().toDouble()
                    
                    val savedAcc = accountRepository.save(Account(
                        userId = savedBot.id,
                        accountNumber = "9000${String.format("%04d", i)}-01",
                        accountType = "BOT",
                        balance = randomBalance,
                        isPrimary = true
                    ))
                    
                    val botTickers = allSeedTickers.shuffled().take((5..12).random())
                    botTickers.forEach { ticker ->
                        assetRepository.save(Asset(
                            accountId = savedAcc.id,
                            ticker = ticker,
                            quantity = (100..5000).random(),
                            avgPrice = (10000..100000).random().toDouble()
                        ))
                    }
                    createdCount++
                }
            }
            if (createdCount > 0) println("$createdCount new bots created.")

            // Cleanup: Remove foreign assets from existing bots using bulk delete
            val botAccountIds = accountRepository.findByAccountType("BOT").map { it.id }
            if (botAccountIds.isNotEmpty()) {
                assetRepository.deleteByAccountIdInAndTickerNotIn(botAccountIds, allSeedTickers)
            }
            println("Cleanup complete.")
        }
    }
}
