package com.mts.account.model

import jakarta.persistence.*
import jakarta.persistence.UniqueConstraint

@Entity
@Table(name = "assets", uniqueConstraints = [UniqueConstraint(columnNames = ["userId", "ticker"])])
class Asset(
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long = 0,

    @Column(nullable = false)
    val userId: Long,

    @Column(nullable = false)
    val ticker: String,

    @Column(nullable = false)
    var quantity: Int,

    @Column(nullable = false)
    var avgPrice: Double
)
