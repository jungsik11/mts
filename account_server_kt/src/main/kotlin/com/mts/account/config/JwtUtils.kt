package com.mts.account.config

import io.jsonwebtoken.Jwts
import io.jsonwebtoken.SignatureAlgorithm
import io.jsonwebtoken.security.Keys
import org.springframework.stereotype.Component
import java.util.*

@Component
class JwtUtils {
    // In production, this should be in application.properties/secrets
    private val secret = "v3ry-53cr3t-k3y-th4t-15-v3ry-l0ng-4nd-53cur3-v3ry-53cr3t-k3y-th4t-15-v3ry-l0ng-4nd-53cur3"
    private val key = Keys.hmacShaKeyFor(secret.toByteArray())
    private val expirationMs = 3600000 * 24 // 24 hours

    fun generateToken(username: String, userId: Long): String {
        return Jwts.builder()
            .setSubject(username)
            .claim("userId", userId)
            .setIssuedAt(Date())
            .setExpiration(Date(Date().time + expirationMs))
            .signWith(key, SignatureAlgorithm.HS256)
            .compact()
    }

    fun getUsernameFromToken(token: String): String {
        return Jwts.parserBuilder().setSigningKey(key).build()
            .parseClaimsJws(token).body.subject
    }

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
