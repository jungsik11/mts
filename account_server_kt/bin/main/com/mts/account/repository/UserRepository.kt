package com.mts.account.repository

import com.mts.account.model.User
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.stereotype.Repository

@Repository
interface UserRepository : JpaRepository<User, Long> {
    fun findByUsername(username: String): User?
    fun countByUsernameStartingWith(prefix: String): Long

    @org.springframework.data.jpa.repository.Query("SELECT u.id FROM User u WHERE u.username LIKE CONCAT(:prefix, '%')")
    fun findIdsByUsernameStartingWith(prefix: String): List<Long>

    @org.springframework.data.jpa.repository.Query(value = "SELECT pg_database_size(current_database())", nativeQuery = true)
    fun getDatabaseSize(): Long

    @org.springframework.data.jpa.repository.Query(value = "SELECT count(*) FROM pg_stat_activity WHERE state = 'active'", nativeQuery = true)
    fun getActiveConnections(): Int

    @org.springframework.data.jpa.repository.Query(value = "SELECT sum(xact_commit + xact_rollback) FROM pg_stat_database WHERE datname = current_database()", nativeQuery = true)
    fun getTransactionCount(): Long
}
