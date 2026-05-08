package com.mts.account.config

import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.security.config.annotation.web.builders.HttpSecurity
import org.springframework.security.web.SecurityFilterChain
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder
import org.springframework.security.crypto.password.PasswordEncoder
import org.springframework.web.cors.CorsConfiguration
import org.springframework.web.cors.UrlBasedCorsConfigurationSource
import org.springframework.web.cors.CorsConfigurationSource
import org.springframework.security.config.Customizer
import org.springframework.security.web.util.matcher.AntPathRequestMatcher

@Configuration
class SecurityConfig {

    @Bean
    fun passwordEncoder(): PasswordEncoder {
        return BCryptPasswordEncoder()
    }

    @Bean
    fun securityFilterChain(http: HttpSecurity): SecurityFilterChain {
        http
            .csrf { csrf -> csrf.disable() }
            .cors(Customizer.withDefaults())
            .authorizeHttpRequests { auth ->
                auth.requestMatchers(AntPathRequestMatcher("/auth/**")).permitAll()
                auth.requestMatchers(AntPathRequestMatcher("/account/**")).permitAll()
                auth.requestMatchers(AntPathRequestMatcher("/admin/**")).permitAll()
                auth.requestMatchers(AntPathRequestMatcher("/assets/**")).permitAll()
                auth.requestMatchers(AntPathRequestMatcher("/internal/**")).permitAll()
                auth.anyRequest().authenticated()
            }
        return http.build()
    }

    @Bean
    fun corsConfigurationSource(): CorsConfigurationSource {
        val configuration = CorsConfiguration()
        configuration.setAllowedOrigins(listOf("http://localhost:3000", "http://127.0.0.1:3000", "http://100.91.106.15:3000"))
        configuration.setAllowedMethods(listOf("GET", "POST", "PUT", "DELETE", "OPTIONS"))
        configuration.setAllowedHeaders(listOf("*"))
        configuration.setAllowCredentials(true)
        val source = UrlBasedCorsConfigurationSource()
        source.registerCorsConfiguration("/**", configuration)
        return source
    }
}
