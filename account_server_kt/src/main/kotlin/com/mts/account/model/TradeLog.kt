package com.mts.account.model

import jakarta.persistence.*
import java.time.LocalDateTime

@Entity
@Table(name = "trade_logs")
class TradeLog(
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long = 0,

    @Column(nullable = false)
    val buyerId: Long,

    @Column(nullable = false)
    val sellerId: Long,

    @Column(nullable = false)
    val ticker: String,

    @Column(nullable = false)
    val price: Double,

    @Column(nullable = false)
    val quantity: Int,

    @Column(nullable = false)
    val timestamp: LocalDateTime = LocalDateTime.now()
)
