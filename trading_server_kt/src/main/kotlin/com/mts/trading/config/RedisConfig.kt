package com.mts.trading.config

import com.mts.trading.controller.MarketDataHandler
import org.springframework.beans.factory.annotation.Value
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.data.redis.connection.RedisConnectionFactory
import org.springframework.data.redis.connection.lettuce.LettuceConnectionFactory
import org.springframework.data.redis.connection.RedisStandaloneConfiguration
import org.springframework.data.redis.core.StringRedisTemplate
import org.springframework.data.redis.listener.PatternTopic
import org.springframework.data.redis.listener.RedisMessageListenerContainer
import org.springframework.data.redis.listener.adapter.MessageListenerAdapter

@Configuration
class RedisConfig(
    @Value("\${REDIS_SECONDARY_HOST:localhost}") private val secondaryHost: String,
    @Value("\${REDIS_SECONDARY_PORT:6379}") private val secondaryPort: Int
) {

    @Bean
    fun secondaryRedisConnectionFactory(): RedisConnectionFactory {
        return LettuceConnectionFactory(RedisStandaloneConfiguration(secondaryHost, secondaryPort))
    }

    @Bean("secondaryRedisTemplate")
    fun secondaryRedisTemplate(secondaryRedisConnectionFactory: RedisConnectionFactory): StringRedisTemplate {
        return StringRedisTemplate(secondaryRedisConnectionFactory)
    }

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
