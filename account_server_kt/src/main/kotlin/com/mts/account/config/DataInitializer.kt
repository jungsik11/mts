package com.mts.account.config

import com.mts.account.model.Account
import com.mts.account.model.User
import com.mts.account.repository.AccountRepository
import com.mts.account.repository.UserRepository
import org.springframework.boot.CommandLineRunner
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.security.crypto.password.PasswordEncoder

@Configuration
class DataInitializer {

    @Bean
    fun initData(userRepository: UserRepository, accountRepository: AccountRepository, passwordEncoder: PasswordEncoder): CommandLineRunner {
        return CommandLineRunner {
            if (userRepository.findByUsername("admin") == null) {
                val admin = User(username = "admin", passwordHash = passwordEncoder.encode("admin123"), email = "admin@example.com")
                userRepository.save(admin)
                accountRepository.save(Account(userId = admin.id, accountNumber = "123-456-7890", accountType = "ADMIN", balance = 10000000.0, isPrimary = true))
                println("Admin created")
            }
            
            // Create Bots
            val botNames = listOf("BOT_ALGO_ALPHA", "BOT_TREND_SETTER", "BOT_SCALPER_PRO", "BOT_WHALE_MOCK")
            botNames.forEachIndexed { index, name ->
                if (userRepository.findByUsername(name) == null) {
                    val bot = User(username = name, passwordHash = passwordEncoder.encode("bot123"), email = "$name@mts.bot")
                    val savedBot = userRepository.save(bot)
                    accountRepository.save(Account(
                        userId = savedBot.id,
                        accountNumber = "900-000-000${index + 1}",
                        accountType = "BOT",
                        balance = 1000000000.0,
                        isPrimary = true
                    ))
                    println("Bot created: $name")
                }
            }
        }
    }
}
