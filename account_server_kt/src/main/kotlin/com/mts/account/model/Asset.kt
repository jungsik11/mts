package com.mts.account.model

import jakarta.persistence.*
import jakarta.persistence.UniqueConstraint

@Entity
@Table(name = "assets", uniqueConstraints = [UniqueConstraint(columnNames = ["accountId", "ticker"])])
class Asset(
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long = 0,

    @Column(nullable = false)
    val accountId: Long,

    @Column(nullable = false)
    val ticker: String,

    @Column(nullable = false)
    var quantity: Int, // Available quantity

    @Column(nullable = false)
    var lockedQuantity: Int = 0, // For open sell orders

    @Column(nullable = false)
    var avgPrice: Double
)
