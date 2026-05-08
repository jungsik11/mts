package com.mts.account.model

import jakarta.persistence.*

@Entity
@Table(name = "users")
class User(
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long = 0,

    @Column(unique = true, nullable = false)
    var username: String,

    @Column(nullable = false)
    var passwordHash: String,

    @Column(nullable = false)
    var name: String = "",

    @Column(unique = true, nullable = true)
    var email: String? = null,

    @Column(nullable = true)
    var rrn: String? = null,

    @Column(nullable = true)
    var address: String? = null,

    @Column(nullable = true)
    var job: String? = null,

    @Column(nullable = true)
    var workplace: String? = null
)
