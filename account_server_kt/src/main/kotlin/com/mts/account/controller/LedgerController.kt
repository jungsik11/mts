package com.mts.account.controller

import com.mts.account.service.LedgerService
import org.springframework.web.bind.annotation.*
import com.fasterxml.jackson.annotation.JsonProperty

data class MarginCheckRequest(
    @JsonProperty("user_id") val userId: Long,
    val ticker: String,
    val side: String,
    val price: Double,
    val quantity: Int
)

data class SettlementRequest(
    @JsonProperty("buyer_id") val buyerId: Long,
    @JsonProperty("seller_id") val sellerId: Long,
    val ticker: String,
    val price: Double,
    val quantity: Int
)

@RestController
@RequestMapping("/internal")
class LedgerController(private val ledgerService: LedgerService) {

    @PostMapping("/margin-check")
    fun marginCheck(@RequestBody req: MarginCheckRequest): Map<String, Any> {
        return ledgerService.marginCheck(req.userId, req.ticker, req.side, req.price, req.quantity)
    }

    @PostMapping("/settle")
    fun settleTrade(@RequestBody req: SettlementRequest): Map<String, String> {
        ledgerService.settleTrade(req.buyerId, req.sellerId, req.ticker, req.price, req.quantity)
        return mapOf("status" to "success")
    }
}
