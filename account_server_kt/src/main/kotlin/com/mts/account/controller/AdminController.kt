package com.mts.account.controller

import com.mts.account.model.User
import com.mts.account.model.Account
import com.mts.account.model.Asset
import com.mts.account.repository.AccountRepository
import com.mts.account.repository.UserRepository
import com.mts.account.repository.AssetRepository
import com.mts.account.repository.TradeLogRepository
import com.mts.account.model.TradeLog
import org.springframework.web.bind.annotation.*
import org.springframework.transaction.annotation.Transactional
import org.springframework.http.ResponseEntity
import org.springframework.security.crypto.password.PasswordEncoder
import java.lang.management.ManagementFactory
import com.sun.management.OperatingSystemMXBean

@RestController
@RequestMapping("/admin")
@CrossOrigin(origins = ["*"])
class AdminController(
    private val userRepository: UserRepository,
    private val accountRepository: AccountRepository,
    private val assetRepository: AssetRepository,
    private val tradeLogRepository: TradeLogRepository,
    private val passwordEncoder: PasswordEncoder
) {
    @GetMapping("/system/metrics")
    fun getSystemMetrics(): Map<String, Any> {
        val osBean = ManagementFactory.getOperatingSystemMXBean() as OperatingSystemMXBean
        val runtime = Runtime.getRuntime()
        
        val cpuUsage = osBean.cpuLoad * 100
        val totalMemory = osBean.totalMemorySize
        val freeMemory = osBean.freeMemorySize
        val usedMemory = totalMemory - freeMemory
        
        val jvmTotalMemory = runtime.totalMemory()
        val jvmFreeMemory = runtime.freeMemory()
        val jvmUsedMemory = jvmTotalMemory - jvmFreeMemory

        // Health Checks
        val health = mutableMapOf<String, String>()
        
        // PostgreSQL Check
        try {
            // Check if we can perform a simple query
            userRepository.count() 
            health["postgreSQL (User DB)"] = "UP"
        } catch (e: Exception) { health["postgreSQL (User DB)"] = "DOWN" }

        val dbMetrics = try {
            val size = userRepository.getDatabaseSize()
            mapOf<String, Any>(
                "cpuUsage" to "0.00",
                "usedMemory" to size,
                "totalMemory" to 1024L * 1024L * 1024L, // 1GB mock limit
                "jvm" to mapOf("used" to 0, "total" to 0),
                "availableProcessors" to 1,
                "systemLoadAverage" to 0.0
            )
        } catch (e: Exception) {
            println("DB metrics error: ${e.message}")
            emptyMap<String, Any>()
        }

        return mapOf(
            "cpuUsage" to String.format("%.2f", cpuUsage),
            "totalMemory" to totalMemory,
            "usedMemory" to usedMemory,
            "freeMemory" to freeMemory,
            "memoryUsagePercent" to String.format("%.2f", (usedMemory.toDouble() / totalMemory.toDouble()) * 100),
            "jvm" to mapOf(
                "total" to jvmTotalMemory,
                "used" to jvmUsedMemory,
                "free" to jvmFreeMemory
            ),
            "health" to health,
            "dbMetrics" to dbMetrics,
            "availableProcessors" to osBean.availableProcessors,
            "systemLoadAverage" to osBean.systemLoadAverage
        )
    }

    @GetMapping("/bots/ids")
    fun getBotUserIds(): List<Long> {
        return userRepository.findAll()
            .filter { it.username.startsWith("BOT_") }
            .map { it.id }
    }

    @GetMapping("/users")
    fun getAllUsers(): List<Map<String, Any?>> {
        return userRepository.findAll().map { user ->
            val accounts = accountRepository.findByUserId(user.id)
            mapOf(
                "id" to user.id,
                "username" to user.username,
                "email" to user.email,
                "name" to user.name,
                "rrn" to user.rrn,
                "phone" to user.phone,
                "address" to user.address,
                "job" to user.job,
                "workplace" to user.workplace,
                "accounts" to accounts.map { acc ->
                    val assets = assetRepository.findByAccountId(acc.id)
                    mapOf(
                        "id" to acc.id,
                        "accountNumber" to acc.accountNumber,
                        "accountType" to acc.accountType,
                        "balance" to acc.balance,
                        "isPrimary" to acc.isPrimary,
                        "assets" to assets.map {
                            mapOf(
                                "ticker" to it.ticker,
                                "quantity" to it.quantity,
                                "avgPrice" to it.avgPrice
                            )
                        }
                    )
                }
            )
        }
    }

    @PutMapping("/users/{id}/full")
    @Transactional
    fun updateUserFull(@PathVariable id: Long, @RequestBody req: UpdateUserFullRequest): Map<String, Any> {
        val user = userRepository.findById(id).orElse(null)
            ?: return mapOf("status" to "Failure", "message" to "User not found")
        
        // 1. Update basic info
        user.username = req.username
        user.email = if (req.email.isNullOrBlank()) null else req.email
        user.name = req.name
        user.rrn = req.rrn
        user.phone = req.phone
        user.address = req.address
        user.job = req.job
        user.workplace = req.workplace
        
        // Update password if provided
        if (!req.password.isNullOrBlank()) {
            user.passwordHash = passwordEncoder.encode(req.password)
        }
        
        userRepository.save(user)

        // 2. Handle Accounts
        val existingAccounts = accountRepository.findByUserId(id)
        val incomingAccNums = req.accounts.map { it.accountNumber }.toSet()
        
        // Delete accounts not in request
        existingAccounts.filter { it.accountNumber !in incomingAccNums }.forEach { acc ->
            assetRepository.deleteAll(assetRepository.findByAccountId(acc.id))
            accountRepository.delete(acc)
        }

        req.accounts.forEach { accReq ->
            var account = accountRepository.findByAccountNumber(accReq.accountNumber)
            if (account == null) {
                // Create new account
                account = Account(
                    userId = id,
                    accountNumber = accReq.accountNumber,
                    accountType = accReq.accountType ?: "CONSIGNMENT",
                    balance = accReq.balance,
                    isPrimary = accReq.isPrimary ?: false
                )
            } else if (account.userId == id) {
                account.balance = accReq.balance
                account.accountType = accReq.accountType ?: account.accountType
                account.isPrimary = accReq.isPrimary ?: account.isPrimary
            }
            val savedAcc = accountRepository.save(account!!)

            // 3. Handle Assets for this account
            val existingAssets = assetRepository.findByAccountId(savedAcc.id)
            assetRepository.deleteAll(existingAssets)
            
            accReq.assets.forEach { assetReq ->
                assetRepository.save(Asset(
                    accountId = savedAcc.id,
                    ticker = assetReq.ticker,
                    quantity = assetReq.quantity,
                    avgPrice = assetReq.avgPrice
                ))
            }
        }

        return mapOf("status" to "Success", "message" to "User, accounts, and per-account assets updated")
    }

    @PostMapping("/users")
    @Transactional
    fun createUser(@RequestBody req: CreateUserRequest): Map<String, Any> {
        try {
            if (userRepository.findByUsername(req.username) != null) {
                return mapOf("status" to "Failure", "message" to "Username already exists")
            }

            val user = User(
                username = req.username,
                passwordHash = passwordEncoder.encode(req.password),
                name = req.name,
                email = if (req.email.isNullOrBlank()) null else req.email,
                rrn = req.rrn,
                phone = req.phone,
                address = req.address,
                job = req.job,
                workplace = req.workplace
            )
            val savedUser = userRepository.save(user)

            val account = Account(
                userId = savedUser.id,
                accountNumber = generateAccountNumber(req.accountType ?: "CONSIGNMENT"),
                accountType = req.accountType ?: "CONSIGNMENT",
                balance = req.initialBalance,
                isPrimary = true
            )
            accountRepository.save(account)

            return mapOf(
                "status" to "Success", 
                "message" to "User created", 
                "userId" to savedUser.id,
                "accountNumber" to account.accountNumber
            )
        } catch (e: Exception) {
            return mapOf("status" to "Failure", "message" to (e.message ?: "Unknown error"))
        }
    }

    private fun generateAccountNumber(type: String): String {
        val base = (10000000..99999999).random().toString()
        val code = when (type.uppercase()) {
            "CONSIGNMENT", "위탁계좌" -> "01"
            "CMA", "CMA 계좌" -> "21"
            "PENSION", "연금", "연금 계좌" -> "22"
            else -> "01"
        }
        return "$base-$code"
    }

    @PostMapping("/account/update-balance")
    fun updateBalance(@RequestBody req: UpdateBalanceRequest): Map<String, Any> {
        val account = accountRepository.findByAccountNumber(req.accountNumber)
            ?: return mapOf("status" to "Failure", "message" to "Account not found")
        
        account.balance = req.newBalance
        accountRepository.save(account)
        return mapOf("status" to "Success", "message" to "Balance updated")
    }

    @PostMapping("/account/deposit")
    fun deposit(@RequestBody req: DepositRequest): Map<String, Any> {
        val account = accountRepository.findByAccountNumber(req.accountNumber)
            ?: return mapOf("status" to "Failure", "message" to "Account not found")
        
        account.balance += req.amount
        accountRepository.save(account)
        return mapOf("status" to "Success", "message" to "₩${req.amount} deposited. New balance: ₩${account.balance}")
    }

    @PutMapping("/users/{id}")
    fun updateUser(@PathVariable id: Long, @RequestBody req: UpdateUserRequest): Map<String, Any> {
        val user = userRepository.findById(id).orElse(null)
            ?: return mapOf("status" to "Failure", "message" to "User not found")
        
        user.username = req.username
        user.email = req.email
        userRepository.save(user)
        return mapOf("status" to "Success", "message" to "User updated")
    }

    @DeleteMapping("/users/{id}")
    @Transactional
    fun deleteUser(@PathVariable id: Long): ResponseEntity<Map<String, Any>> {
        val user = userRepository.findById(id).orElse(null)
            ?: return ResponseEntity.notFound().build()
        
        // Delete associated accounts and their assets
        val accounts = accountRepository.findByUserId(id)
        accounts.forEach { acc ->
            assetRepository.deleteAll(assetRepository.findByAccountId(acc.id))
        }
        accountRepository.deleteAll(accounts)
        userRepository.delete(user)
        
        return ResponseEntity.ok(mapOf("status" to "Success", "message" to "User and all associated data deleted"))
    }

    @GetMapping("/trades")
    fun getTradeLogs(
        @RequestParam(defaultValue = "0") page: Int,
        @RequestParam(defaultValue = "50") size: Int
    ): List<TradeLog> {
        val pageable = org.springframework.data.domain.PageRequest.of(page, size, org.springframework.data.domain.Sort.by("timestamp").descending())
        return tradeLogRepository.findAll(pageable).content
    }
}

data class UpdateBalanceRequest(val accountNumber: String, val newBalance: Double)
data class DepositRequest(val accountNumber: String, val amount: Double)
data class UpdateUserRequest(val username: String, val email: String)

data class UpdateUserFullRequest(
    val username: String,
    val email: String? = null,
    val name: String,
    val password: String? = null,
    val rrn: String? = null,
    val phone: String? = null,
    val address: String? = null,
    val job: String? = null,
    val workplace: String? = null,
    val accounts: List<AccountUpdateRequest>
)

data class AccountUpdateRequest(
    val accountNumber: String, 
    val balance: Double, 
    val accountType: String? = null,
    val isPrimary: Boolean? = null,
    val assets: List<AssetUpdateRequest> = emptyList()
)
data class AssetUpdateRequest(val ticker: String, val quantity: Int, val avgPrice: Double)

data class CreateUserRequest(
    val username: String,
    val password: String,
    val name: String,
    val email: String? = null,
    val rrn: String? = null,
    val phone: String? = null,
    val address: String? = null,
    val job: String? = null,
    val workplace: String? = null,
    val accountType: String? = null,
    val initialBalance: Double = 0.0
)
