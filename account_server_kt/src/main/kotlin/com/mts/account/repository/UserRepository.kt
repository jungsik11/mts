package com.mts.account.repository

import com.mts.account.model.User
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.stereotype.Repository

@Repository
interface UserRepository : JpaRepository<User, Long> {
    fun findByUsername(username: String): User?

    @org.springframework.data.jpa.repository.Query(value = "SELECT sum(pg_relation_size(quote_ident(schemaname) || '.' || quote_ident(relname))) FROM pg_stat_user_tables", nativeQuery = true)
    fun getDatabaseSize(): Long
}
