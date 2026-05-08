package com.mts.trading.controller

import org.springframework.stereotype.Component
import org.springframework.web.socket.TextMessage
import org.springframework.web.socket.WebSocketSession
import org.springframework.web.socket.handler.TextWebSocketHandler
import java.util.concurrent.CopyOnWriteArrayList

@Component
class MarketDataHandler : TextWebSocketHandler() {
    private val sessions = CopyOnWriteArrayList<WebSocketSession>()

    override fun afterConnectionEstablished(session: WebSocketSession) {
        sessions.add(session)
    }

    override fun afterConnectionClosed(session: WebSocketSession, status: org.springframework.web.socket.CloseStatus) {
        sessions.remove(session)
    }

    fun broadcast(channel: String, data: String) {
        val payload = """{"channel": "$channel", "data": $data}"""
        sessions.forEach {
            if (it.isOpen) {
                synchronized(it) {
                    if (it.isOpen) {
                        it.sendMessage(TextMessage(payload))
                    }
                }
            }
        }
    }
}
