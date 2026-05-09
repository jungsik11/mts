package com.mts.account.model

import jakarta.persistence.*
import java.time.LocalDateTime

@Entity
@Table(name = "transfer_logs")
data class TransferLog(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long = 0,

    @Column(name = "from_account_number", nullable = false)
    val fromAccountNumber: String,

    @Column(name = "to_account_number", nullable = false)
    val toAccountNumber: String,

    @Column(nullable = false)
    val amount: Double,

    @Column(nullable = false)
    val timestamp: LocalDateTime = LocalDateTime.now()
)
