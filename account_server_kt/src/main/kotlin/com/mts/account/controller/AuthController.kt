package com.mts.account.controller

import com.mts.account.config.JwtUtils
import com.mts.account.model.Account
import com.mts.account.model.User
import com.mts.account.repository.AccountRepository
import com.mts.account.repository.UserRepository
import org.springframework.security.crypto.password.PasswordEncoder
import org.springframework.web.bind.annotation.*

data class LoginRequest(val username: String, val password: String)
data class RegisterRequest(
    val username: String, 
    val password: String, 
    val name: String,
    val accountType: String,
    val email: String? = null,
    val rrn: String? = null,
    val phone: String? = null,
    val address: String? = null,
    val job: String? = null,
    val workplace: String? = null
)
data class AuthResponse(val token: String, val username: String, val userId: Long)

@RestController
@RequestMapping("/auth")
class AuthController(
    private val userRepository: UserRepository,
    private val accountRepository: AccountRepository,
    private val passwordEncoder: PasswordEncoder,
    private val jwtUtils: JwtUtils
) {

    @PostMapping("/register")
    fun register(@RequestBody req: RegisterRequest): Map<String, Any> {
        try {
            if (userRepository.findByUsername(req.username) != null) {
                return mapOf("status" to "Failure", "reason" to "USER_ALREADY_EXISTS", "message" to "Username is already taken.")
            }
            if (!req.email.isNullOrBlank() && userRepository.findAll().any { it.email == req.email }) {
                return mapOf("status" to "Failure", "reason" to "EMAIL_ALREADY_EXISTS", "message" to "Email is already registered.")
            }
            if (req.rrn.isNullOrBlank()) {
                return mapOf("status" to "Failure", "reason" to "RRN_REQUIRED", "message" to "Resident Registration Number is required.")
            }
            if (req.phone.isNullOrBlank()) {
                return mapOf("status" to "Failure", "reason" to "PHONE_REQUIRED", "message" to "Phone number is required.")
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
                accountNumber = generateAccountNumber(req.accountType),
                accountType = req.accountType,
                balance = 0.0, // Default 0 KRW
                isPrimary = true
            )
            accountRepository.save(account)

            return mapOf("status" to "Success", "message" to "User registered", "account_number" to account.accountNumber)
        } catch (e: Exception) {
            return mapOf("status" to "Failure", "reason" to "SERVER_ERROR", "message" to (e.message ?: "Unknown error"))
        }
    }

    private fun generateAccountNumber(type: String): String {
        val rand = java.util.Random()
        val base = (10000000..99999999).random().toString()
        val code = when (type.uppercase()) {
            "CONSIGNMENT", "위탁계좌" -> "01"
            "CMA", "CMA 계좌" -> "21"
            "PENSION", "연금", "연금 계좌" -> "22"
            else -> "01"
        }
        return "$base-$code"
    }

    @PostMapping("/login")
    fun login(@RequestBody req: LoginRequest): Any {
        val user = userRepository.findByUsername(req.username)
        if (user == null || !passwordEncoder.matches(req.password, user.passwordHash)) {
            return mapOf("status" to "Error", "message" to "Invalid credentials")
        }

        val token = jwtUtils.generateToken(user.username, user.id)
        return AuthResponse(token, user.username, user.id)
    }
}
