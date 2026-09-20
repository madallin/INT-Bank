package com.intbank;

import com.intbank.config.DataSourcePoolConfig;
import com.zaxxer.hikari.HikariConfig;
import com.zaxxer.hikari.HikariDataSource;
import org.junit.jupiter.api.Test;
import org.springframework.boot.autoconfigure.jdbc.DataSourceProperties;
import org.springframework.jdbc.datasource.lookup.AbstractRoutingDataSource;
import org.springframework.transaction.support.TransactionSynchronizationManager;

import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.SQLException;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

public class DataSourcePoolConfigTest
{
    private static final String JDBC_URL = "jdbc:postgresql://localhost:1/intbank";
    private static final String USERNAME = "intbank_user";
    private static final String PASSWORD = "secret";

    private final DataSourcePoolConfig config = new DataSourcePoolConfig();

    private DataSourceProperties properties()
    {
        DataSourceProperties properties = new DataSourceProperties();
        properties.setUrl(JDBC_URL);
        properties.setUsername(USERNAME);
        properties.setPassword(PASSWORD);
        return properties;
    }

    @Test
    void hikariConfigUsesHardenedPoolParameters()
    {
        HikariDataSource dataSource = (HikariDataSource) config.dataSource(properties());
        try
        {
            assertThat(dataSource.getMaximumPoolSize()).isEqualTo(20);
            assertThat(dataSource.getMinimumIdle()).isEqualTo(5);
            assertThat(dataSource.getConnectionTimeout()).isEqualTo(5000L);
            assertThat(dataSource.getLeakDetectionThreshold()).isEqualTo(10000L);
        }
        finally
        {
            dataSource.close();
        }
    }

    @Test
    void poolExhaustionFailsFastWithoutHanging()
    {
        HikariConfig hikariConfig = new HikariConfig();
        hikariConfig.setPoolName("intbank-fail-fast-test");
        hikariConfig.setJdbcUrl(JDBC_URL);
        hikariConfig.setUsername(USERNAME);
        hikariConfig.setPassword(PASSWORD);
        hikariConfig.setDriverClassName("org.postgresql.Driver");
        hikariConfig.setMaximumPoolSize(DataSourcePoolConfig.MAXIMUM_POOL_SIZE);
        hikariConfig.setMinimumIdle(1);
        hikariConfig.setConnectionTimeout(250L);
        hikariConfig.setInitializationFailTimeout(-1L);

        HikariDataSource dataSource = new HikariDataSource(hikariConfig);
        try
        {
            long start = System.nanoTime();
            assertThatThrownBy(dataSource::getConnection).isInstanceOf(SQLException.class);
            long elapsedMillis = (System.nanoTime() - start) / 1_000_000L;
            assertThat(elapsedMillis).isLessThan(5000L);
        }
        finally
        {
            dataSource.close();
        }
    }

    @Test
    void readOnlyTransactionsRouteToReadPool()
    {
        DataSourcePoolConfig.ReadWriteRoutingDataSource routingDataSource =
                new DataSourcePoolConfig.ReadWriteRoutingDataSource();
        try
        {
            TransactionSynchronizationManager.setCurrentTransactionReadOnly(true);
            assertThat(routingDataSource.resolveLookupKey()).isEqualTo(DataSourcePoolConfig.ROUTING_KEY_READ);
            assertThat(routingDataSource.resolveLookupKey()).isEqualTo("read");

            TransactionSynchronizationManager.setCurrentTransactionReadOnly(false);
            assertThat(routingDataSource.resolveLookupKey()).isEqualTo(DataSourcePoolConfig.ROUTING_KEY_WRITE);
            assertThat(routingDataSource.resolveLookupKey()).isEqualTo("write");
        }
        finally
        {
            TransactionSynchronizationManager.setCurrentTransactionReadOnly(false);
        }
    }

    @Test
    void routingDataSourceDispatchesToCorrectUnderlyingPool() throws SQLException
    {
        DataSource readDataSource = mock(DataSource.class);
        DataSource writeDataSource = mock(DataSource.class);
        Connection readConnection = mock(Connection.class);
        Connection writeConnection = mock(Connection.class);
        when(readDataSource.getConnection()).thenReturn(readConnection);
        when(writeDataSource.getConnection()).thenReturn(writeConnection);

        AbstractRoutingDataSource routingDataSource =
                config.buildRoutingDataSource(writeDataSource, readDataSource);
        try
        {
            TransactionSynchronizationManager.setCurrentTransactionReadOnly(true);
            Connection read = routingDataSource.getConnection();
            assertThat(read).isSameAs(readConnection);
            verify(readDataSource).getConnection();
            verify(writeDataSource, never()).getConnection();

            TransactionSynchronizationManager.setCurrentTransactionReadOnly(false);
            Connection write = routingDataSource.getConnection();
            assertThat(write).isSameAs(writeConnection);
            verify(writeDataSource).getConnection();
        }
        finally
        {
            TransactionSynchronizationManager.setCurrentTransactionReadOnly(false);
        }
    }

    @Test
    void readPoolIsSmallerThanWritePool()
    {
        HikariDataSource writeDataSource = (HikariDataSource) config.dataSource(properties());
        HikariDataSource readDataSource = config.readOnlyDataSource(properties());
        try
        {
            assertThat(readDataSource.getMaximumPoolSize()).isLessThan(writeDataSource.getMaximumPoolSize());
            assertThat(readDataSource.getConnectionTimeout()).isEqualTo(5000L);
            assertThat(writeDataSource.getConnectionTimeout()).isEqualTo(5000L);
            assertThat(readDataSource.getLeakDetectionThreshold()).isEqualTo(10000L);
            assertThat(writeDataSource.getLeakDetectionThreshold()).isEqualTo(10000L);
        }
        finally
        {
            writeDataSource.close();
            readDataSource.close();
        }
    }
}
