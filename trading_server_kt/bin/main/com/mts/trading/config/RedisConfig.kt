package com.mts.trading.config

import com.mts.trading.controller.MarketDataHandler
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.data.redis.connection.RedisConnectionFactory
import org.springframework.data.redis.listener.PatternTopic
import org.springframework.data.redis.listener.RedisMessageListenerContainer
import org.springframework.data.redis.listener.adapter.MessageListenerAdapter

@Configuration
class RedisConfig {

    @Bean
    fun container(
        connectionFactory: RedisConnectionFactory,
        listenerAdapter: MessageListenerAdapter
    ): RedisMessageListenerContainer {
        val container = RedisMessageListenerContainer()
        container.setConnectionFactory(connectionFactory)
        container.addMessageListener(listenerAdapter, PatternTopic("market_prices"))
        container.addMessageListener(listenerAdapter, PatternTopic("trade_updates"))
        container.addMessageListener(listenerAdapter, PatternTopic("order_book_updates"))
        return container
    }

    @Bean
    fun listenerAdapter(subscriber: RedisSubscriber): MessageListenerAdapter {
        return MessageListenerAdapter(subscriber, "onMessage")
    }
}

@Configuration
class RedisSubscriber(private val marketDataHandler: MarketDataHandler) {
    fun onMessage(message: String, channel: String) {
        marketDataHandler.broadcast(channel, message)
    }
}
