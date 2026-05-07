package com.mts.account.controller

import com.mts.account.config.JwtUtils
import com.mts.account.model.Account
import com.mts.account.model.User
import com.mts.account.repository.AccountRepository
import com.mts.account.repository.UserRepository
import org.springframework.security.crypto.password.PasswordEncoder
import org.springframework.web.bind.annotation.*

data class LoginRequest(val username: String, val password: String)
data class RegisterRequest(val username: String, val password: String, val email: String, val accountType: String)
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
            if (userRepository.findAll().any { it.email == req.email }) {
                return mapOf("status" to "Failure", "reason" to "EMAIL_ALREADY_EXISTS", "message" to "Email is already registered.")
            }

            val user = User(
                username = req.username,
                passwordHash = passwordEncoder.encode(req.password),
                email = req.email
            )
            val savedUser = userRepository.save(user)

            val account = Account(
                userId = savedUser.id,
                accountNumber = generateAccountNumber(),
                accountType = req.accountType,
                balance = 1000000.0, // Default 1M KRW
                isPrimary = true
            )
            accountRepository.save(account)

            return mapOf("status" to "Success", "message" to "User registered", "account_number" to account.accountNumber)
        } catch (e: Exception) {
            return mapOf("status" to "Failure", "reason" to "SERVER_ERROR", "message" to (e.message ?: "Unknown error"))
        }
    }

    private fun generateAccountNumber(): String {
        val rand = java.util.Random()
        return "${rand.nextInt(900) + 100}-${rand.nextInt(900) + 100}-${rand.nextInt(9000) + 1000}"
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
