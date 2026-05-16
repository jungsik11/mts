package com.mts.account.model

import jakarta.persistence.*

@Entity
@Table(name = "accounts")
class Account(
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long = 0,

    @Column(nullable = false)
    val userId: Long,

    @Column(unique = true, nullable = false)
    var accountNumber: String,

    @Column(nullable = false)
    var accountType: String, // "CMA", "CONSIGNMENT"

    @Column(nullable = false)
    var balance: Double = 0.0,

    @Column(nullable = false)
    var currency: String = "KRW", // "KRW", "USD"

    @Column(nullable = false)
    var isPrimary: Boolean = false
)
