package com.mts.account.repository

import com.mts.account.model.User
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.stereotype.Repository

@Repository
interface UserRepository : JpaRepository<User, Long> {
    fun findByUsername(username: String): User?

    @org.springframework.data.jpa.repository.Query(value = "SELECT pg_database_size(current_database())", nativeQuery = true)
    fun getDatabaseSize(): Long
}
