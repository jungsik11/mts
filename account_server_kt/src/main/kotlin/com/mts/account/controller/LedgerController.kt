package com.mts.account.controller

import com.mts.account.service.LedgerService
import org.springframework.web.bind.annotation.*

@RestController
@RequestMapping("/internal")
class LedgerController(private val ledgerService: LedgerService) {

    @PostMapping("/margin-check")
    fun marginCheck(@RequestBody req: Map<String, Any>): Map<String, Any> {
        val userId = (req["user_id"] as Number).toLong()
        val ticker = req["ticker"] as String
        val side = req["side"] as String
        val price = (req["price"] as Number).toDouble()
        val quantity = (req["quantity"] as Number).toInt()
        return ledgerService.marginCheck(userId, ticker, side, price, quantity)
    }

    @PostMapping("/unlock")
    fun unlockOrder(@RequestBody req: Map<String, Any>): Map<String, String> {
        val userId = (req["user_id"] as Number).toLong()
        val ticker = req["ticker"] as String
        val side = req["side"] as String
        val price = (req["price"] as Number).toDouble()
        val quantity = (req["quantity"] as Number).toInt()
        ledgerService.unlockOrder(userId, ticker, side, price, quantity)
        return mapOf("status" to "success")
    }

    @PostMapping("/settle")
    fun settleTrade(@RequestBody req: Map<String, Any>): Map<String, String> {
        val buyerId = (req["buyer_id"] as Number).toLong()
        val sellerId = (req["seller_id"] as Number).toLong()
        val ticker = req["ticker"] as String
        val price = (req["price"] as Number).toDouble()
        val quantity = (req["quantity"] as Number).toInt()
        val buyerOrderPrice = (req["buyer_order_price"] as Number).toDouble()
        ledgerService.settleTrade(buyerId, sellerId, ticker, price, quantity, buyerOrderPrice)
        return mapOf("status" to "success")
    }
}
