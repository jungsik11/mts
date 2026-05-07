package com.mts.trading.config

import io.jsonwebtoken.Jwts
import io.jsonwebtoken.SignatureAlgorithm
import io.jsonwebtoken.security.Keys
import org.springframework.stereotype.Component
import java.util.*

@Component
class JwtUtils {
    // Shared secret with account-server
    private val secret = "v3ry-53cr3t-k3y-th4t-15-v3ry-l0ng-4nd-53cur3-v3ry-53cr3t-k3y-th4t-15-v3ry-l0ng-4nd-53cur3"
    private val key = Keys.hmacShaKeyFor(secret.toByteArray())

    fun getUserIdFromToken(token: String): Long? {
        return try {
            val claims = Jwts.parserBuilder().setSigningKey(key).build()
                .parseClaimsJws(token).body
            (claims["userId"] as? Number)?.toLong()
        } catch (e: Exception) {
            null
        }
    }

    fun validateToken(token: String): Boolean {
        return try {
            Jwts.parserBuilder().setSigningKey(key).build().parseClaimsJws(token)
            true
        } catch (e: Exception) {
            false
        }
    }
}
