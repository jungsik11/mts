package com.mts.trading

import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.runApplication
import org.springframework.scheduling.annotation.EnableScheduling

@SpringBootApplication
@EnableScheduling
class TradingApplication

fun main(args: Array<String>) {
    runApplication<TradingApplication>(*args)
}
