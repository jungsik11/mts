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
            "availableProcessors" to osBean.availableProcessors,
            "systemLoadAverage" to osBean.systemLoadAverage
        )
    }

    @GetMapping("/users")
    fun getAllUsers(): List<Map<String, Any>> {
        return userRepository.findAll().map { user ->
            val accounts = accountRepository.findByUserId(user.id)
            val assets = assetRepository.findByUserId(user.id)
            mapOf(
                "id" to user.id,
                "username" to user.username,
                "email" to user.email,
                "accounts" to accounts.map { 
                    mapOf(
                        "accountNumber" to it.accountNumber,
                        "accountType" to it.accountType,
                        "balance" to it.balance
                    )
                },
                "assets" to assets.map {
                    mapOf(
                        "ticker" to it.ticker,
                        "quantity" to it.quantity,
                        "avgPrice" to it.avgPrice
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
        user.email = req.email
        
        // Update password if provided
        if (!req.password.isNullOrBlank()) {
            user.passwordHash = passwordEncoder.encode(req.password)
        }
        
        userRepository.save(user)

        // 2. Update balances
        req.accounts.forEach { accReq ->
            val account = accountRepository.findByAccountNumber(accReq.accountNumber)
            if (account != null && account.userId == id) {
                account.balance = accReq.balance
                accountRepository.save(account)
            }
        }

        // 3. Update assets (Holdings)
        // For simplicity, we clear existing assets and re-add them
        val existingAssets = assetRepository.findByUserId(id)
        assetRepository.deleteAll(existingAssets)
        
        req.assets.forEach { assetReq ->
            val newAsset = Asset(
                userId = id,
                ticker = assetReq.ticker,
                quantity = assetReq.quantity,
                avgPrice = assetReq.avgPrice
            )
            assetRepository.save(newAsset)
        }

        return mapOf("status" to "Success", "message" to "User, accounts, and assets updated")
    }

    @PostMapping("/account/update-balance")
    fun updateBalance(@RequestBody req: UpdateBalanceRequest): Map<String, Any> {
        val account = accountRepository.findByAccountNumber(req.accountNumber)
            ?: return mapOf("status" to "Failure", "message" to "Account not found")
        
        account.balance = req.newBalance
        accountRepository.save(account)
        return mapOf("status" to "Success", "message" to "Balance updated")
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
        
        // Delete associated accounts and assets
        accountRepository.deleteAll(accountRepository.findByUserId(id))
        assetRepository.deleteAll(assetRepository.findByUserId(id))
        userRepository.delete(user)
        
        return ResponseEntity.ok(mapOf("status" to "Success", "message" to "User and all associated data deleted"))
    }

    @GetMapping("/trades")
    fun getTradeLogs(): List<TradeLog> {
        return tradeLogRepository.findAll().sortedByDescending { it.timestamp }.take(50)
    }
}

data class UpdateBalanceRequest(val accountNumber: String, val newBalance: Double)
data class UpdateUserRequest(val username: String, val email: String)

data class UpdateUserFullRequest(
    val username: String,
    val email: String,
    val password: String? = null,
    val accounts: List<AccountUpdateRequest>,
    val assets: List<AssetUpdateRequest>
)

data class AccountUpdateRequest(val accountNumber: String, val balance: Double)
data class AssetUpdateRequest(val ticker: String, val quantity: Int, val avgPrice: Double)
