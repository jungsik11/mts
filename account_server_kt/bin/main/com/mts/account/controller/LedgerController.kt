package com.mts.account.controller

import com.mts.account.service.LedgerService
import org.springframework.web.bind.annotation.*

data class MarginCheckRequest(
    val user_id: Long,
    val ticker: String,
    val side: String,
    val price: Double,
    val quantity: Int
)

data class SettlementRequest(
    val buyer_id: Long,
    val seller_id: Long,
    val ticker: String,
    val price: Double,
    val quantity: Int
)

@RestController
@RequestMapping("/internal")
class LedgerController(private val ledgerService: LedgerService) {

    @PostMapping("/margin-check")
    fun marginCheck(@RequestBody req: MarginCheckRequest): Map<String, Any> {
        return ledgerService.marginCheck(req.user_id, req.ticker, req.side, req.price, req.quantity)
    }

    @PostMapping("/settle")
    fun settleTrade(@RequestBody req: SettlementRequest): Map<String, String> {
        ledgerService.settleTrade(req.buyer_id, req.seller_id, req.ticker, req.price, req.quantity)
        return mapOf("status" to "success")
    }
}
