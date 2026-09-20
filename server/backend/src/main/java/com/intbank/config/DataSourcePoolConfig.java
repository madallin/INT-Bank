package com.intbank.config;

import com.zaxxer.hikari.HikariDataSource;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.autoconfigure.jdbc.DataSourceProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;
import org.springframework.jdbc.datasource.LazyConnectionDataSourceProxy;
import org.springframework.jdbc.datasource.lookup.AbstractRoutingDataSource;
import org.springframework.transaction.support.TransactionSynchronizationManager;

import javax.sql.DataSource;
import java.util.HashMap;
import java.util.Map;

@Configuration
public class DataSourcePoolConfig
{
    public static final int MAXIMUM_POOL_SIZE = 20;
    public static final int MINIMUM_IDLE = 5;
    public static final long CONNECTION_TIMEOUT_MS = 5000L;
    public static final long LEAK_DETECTION_THRESHOLD_MS = 10000L;
    public static final long VALIDATION_TIMEOUT_MS = 3000L;
    public static final long IDLE_TIMEOUT_MS = 300000L;
    public static final long MAX_LIFETIME_MS = 1200000L;

    public static final int READ_MAXIMUM_POOL_SIZE = 10;
    public static final int READ_MINIMUM_IDLE = 2;

    public static final String ROUTING_KEY_READ = "read";
    public static final String ROUTING_KEY_WRITE = "write";

    public static final String WRITE_POOL_NAME = "intbank-write-pool";
    public static final String READ_POOL_NAME = "intbank-read-pool";

    @Bean
    public DataSource dataSource(DataSourceProperties properties)
    {
        HikariDataSource dataSource = properties.initializeDataSourceBuilder()
                .type(HikariDataSource.class)
                .build();
        applyWritePoolSettings(dataSource);
        return dataSource;
    }

    @Bean
    public HikariDataSource readOnlyDataSource(DataSourceProperties properties)
    {
        HikariDataSource dataSource = properties.initializeDataSourceBuilder()
                .type(HikariDataSource.class)
                .build();
        applyReadPoolSettings(dataSource);
        return dataSource;
    }

    @Bean
    @Primary
    public DataSource routingDataSource(
            @Qualifier("dataSource") DataSource writeDataSource,
            @Qualifier("readOnlyDataSource") DataSource readDataSource)
    {
        AbstractRoutingDataSource routingDataSource = buildRoutingDataSource(writeDataSource, readDataSource);
        return new LazyConnectionDataSourceProxy(routingDataSource);
    }

    public AbstractRoutingDataSource buildRoutingDataSource(DataSource writeDataSource, DataSource readDataSource)
    {
        ReadWriteRoutingDataSource routingDataSource = new ReadWriteRoutingDataSource();
        Map<Object, Object> targetDataSources = new HashMap<>();
        targetDataSources.put(ROUTING_KEY_WRITE, writeDataSource);
        targetDataSources.put(ROUTING_KEY_READ, readDataSource);
        routingDataSource.setTargetDataSources(targetDataSources);
        routingDataSource.setDefaultTargetDataSource(writeDataSource);
        routingDataSource.afterPropertiesSet();
        return routingDataSource;
    }

    public static void applyWritePoolSettings(HikariDataSource dataSource)
    {
        dataSource.setPoolName(WRITE_POOL_NAME);
        dataSource.setMaximumPoolSize(MAXIMUM_POOL_SIZE);
        dataSource.setMinimumIdle(MINIMUM_IDLE);
        dataSource.setConnectionTimeout(CONNECTION_TIMEOUT_MS);
        dataSource.setLeakDetectionThreshold(LEAK_DETECTION_THRESHOLD_MS);
        dataSource.setValidationTimeout(VALIDATION_TIMEOUT_MS);
        dataSource.setIdleTimeout(IDLE_TIMEOUT_MS);
        dataSource.setMaxLifetime(MAX_LIFETIME_MS);
    }

    public static void applyReadPoolSettings(HikariDataSource dataSource)
    {
        dataSource.setPoolName(READ_POOL_NAME);
        dataSource.setMaximumPoolSize(READ_MAXIMUM_POOL_SIZE);
        dataSource.setMinimumIdle(READ_MINIMUM_IDLE);
        dataSource.setConnectionTimeout(CONNECTION_TIMEOUT_MS);
        dataSource.setLeakDetectionThreshold(LEAK_DETECTION_THRESHOLD_MS);
        dataSource.setValidationTimeout(VALIDATION_TIMEOUT_MS);
        dataSource.setIdleTimeout(IDLE_TIMEOUT_MS);
        dataSource.setMaxLifetime(MAX_LIFETIME_MS);
    }

    public static class ReadWriteRoutingDataSource extends AbstractRoutingDataSource
    {
        @Override
        protected Object determineCurrentLookupKey()
        {
            return TransactionSynchronizationManager.isCurrentTransactionReadOnly()
                    ? ROUTING_KEY_READ
                    : ROUTING_KEY_WRITE;
        }

        public Object resolveLookupKey()
        {
            return determineCurrentLookupKey();
        }
    }
}
