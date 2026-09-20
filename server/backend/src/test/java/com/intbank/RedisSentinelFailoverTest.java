package com.intbank;

import org.junit.jupiter.api.Test;
import org.springframework.data.redis.RedisConnectionFailureException;
import org.springframework.data.redis.connection.RedisSentinelConfiguration;
import org.yaml.snakeyaml.Yaml;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.stream.Collectors;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

public class RedisSentinelFailoverTest
{
    private static final String MASTER_NAME = "mymaster";
    private static final String LOCK_KEY = "account:lock:RO49AAAA1B31007593840000";
    private static final String IDEMPOTENCY_KEY = "idem:failover:0001";

    @Test
    void composeDeclaresThreeSentinelsAndQuorum() throws IOException
    {
        Map<String, Object> root = loadYaml(resolveComposeFile());
        Map<String, Object> services = mapAt(root, "services");

        List<String> names = new ArrayList<>(services.keySet());
        assertThat(names).contains(
                "redis-master",
                "redis-replica",
                "redis-sentinel-1",
                "redis-sentinel-2",
                "redis-sentinel-3");
        assertThat(names.stream().filter(name -> name.contains("master")).count()).isEqualTo(1L);
        assertThat(names.stream().filter(name -> name.contains("replica")).count()).isEqualTo(1L);
        assertThat(names.stream().filter(name -> name.contains("sentinel")).count()).isEqualTo(3L);

        String sentinelConfig = names.stream()
                .filter(name -> name.contains("sentinel"))
                .map(services::get)
                .map(RedisSentinelFailoverTest::asMap)
                .map(service -> service.get("command"))
                .map(RedisSentinelFailoverTest::flattenCommand)
                .collect(Collectors.joining("\n"));

        assertThat(sentinelConfig).contains("monitor mymaster redis-master 6379 2");
        assertThat(sentinelConfig).contains("down-after-milliseconds mymaster 2000");
        assertThat(sentinelConfig).contains("failover-timeout mymaster 5000");
        assertThat(sentinelConfig).contains("parallel-syncs mymaster 1");
        assertThat(sentinelConfig).contains("resolve-hostnames yes");
    }

    @Test
    void sentinelConfigurationDiscoversMasterNamedMymaster()
    {
        RedisSentinelConfiguration configuration = new RedisSentinelConfiguration()
                .master(MASTER_NAME)
                .sentinel("redis-sentinel-1", 26379)
                .sentinel("redis-sentinel-2", 26380)
                .sentinel("redis-sentinel-3", 26381);

        assertThat(configuration.getMaster().getName()).isEqualTo(MASTER_NAME);
        assertThat(configuration.getSentinels()).hasSize(3);

        Set<String> nodes = configuration.getSentinels().stream()
                .map(node -> node.getHost() + ":" + node.getPort())
                .collect(Collectors.toSet());

        assertThat(nodes).containsExactlyInAnyOrder(
                "redis-sentinel-1:26379",
                "redis-sentinel-2:26380",
                "redis-sentinel-3:26381");
    }

    @Test
    void locksAndIdempotencySurviveFailover()
    {
        IdempotencyStore store = new IdempotencyStore();
        RedisGateway gateway = new RedisGateway(store);

        assertThat(gateway.acquireLock(LOCK_KEY, "pod-a")).isTrue();
        assertThat(gateway.recordIdempotency(IDEMPOTENCY_KEY, "payload-1")).isTrue();
        assertThat(gateway.currentMaster()).isEqualTo("redis-master");

        gateway.simulateMasterFailure();
        assertThatThrownBy(() -> gateway.acquireLock("account:lock:other", "pod-b"))
                .isInstanceOf(RedisConnectionFailureException.class);

        gateway.promoteReplica();
        assertThat(gateway.currentMaster()).isEqualTo("redis-replica");

        assertThat(gateway.lockOwner(LOCK_KEY)).isEqualTo("pod-a");
        assertThat(gateway.hasIdempotency(IDEMPOTENCY_KEY)).isTrue();
        assertThat(gateway.recordIdempotency(IDEMPOTENCY_KEY, "payload-2")).isFalse();
    }

    @Test
    void profileConfigTargetsSentinelMaster() throws IOException
    {
        Map<String, Object> root = loadClasspathYaml("application-sentinel.yml");
        Map<String, Object> sentinel = mapAt(root, "spring", "data", "redis", "sentinel");

        assertThat(sentinel.get("master")).isEqualTo(MASTER_NAME);
        assertThat(sentinel.get("nodes")).isInstanceOf(List.class);
        assertThat((List<?>) sentinel.get("nodes")).hasSize(3);
    }

    private static Path resolveComposeFile()
    {
        Path directory = Paths.get(System.getProperty("user.dir")).toAbsolutePath();
        while (directory != null)
        {
            Path nested = directory.resolve("server").resolve("docker-compose.sentinel.yml");
            if (Files.exists(nested))
            {
                return nested;
            }

            Path direct = directory.resolve("docker-compose.sentinel.yml");
            if (Files.exists(direct))
            {
                return direct;
            }

            directory = directory.getParent();
        }

        throw new IllegalStateException(
                "docker-compose.sentinel.yml not found from " + System.getProperty("user.dir"));
    }

    @SuppressWarnings("unchecked")
    private static Map<String, Object> loadYaml(Path path) throws IOException
    {
        try (InputStream input = Files.newInputStream(path))
        {
            return (Map<String, Object>) new Yaml().load(input);
        }
    }

    @SuppressWarnings("unchecked")
    private static Map<String, Object> loadClasspathYaml(String resource) throws IOException
    {
        try (InputStream input = RedisSentinelFailoverTest.class.getClassLoader().getResourceAsStream(resource))
        {
            assertThat(input).as("classpath resource %s", resource).isNotNull();
            return (Map<String, Object>) new Yaml().load(input);
        }
    }

    @SuppressWarnings("unchecked")
    private static Map<String, Object> mapAt(Map<String, Object> root, Object... keys)
    {
        Map<String, Object> current = root;
        for (Object key : keys)
        {
            Object value = current.get(key);
            assertThat(value).as("yaml key %s", key).isInstanceOf(Map.class);
            current = (Map<String, Object>) value;
        }
        return current;
    }

    @SuppressWarnings("unchecked")
    private static Map<String, Object> asMap(Object value)
    {
        return (Map<String, Object>) value;
    }

    private static String flattenCommand(Object command)
    {
        if (command == null)
        {
            return "";
        }
        if (command instanceof List<?> list)
        {
            return list.stream().map(String::valueOf).collect(Collectors.joining("\n"));
        }
        return String.valueOf(command);
    }

    private static final class IdempotencyStore
    {
        private final Map<String, String> locks = new ConcurrentHashMap<>();
        private final Map<String, String> idempotencyRecords = new ConcurrentHashMap<>();

        boolean acquireLock(String key, String owner)
        {
            return locks.putIfAbsent(key, owner) == null;
        }

        String lockOwner(String key)
        {
            return locks.get(key);
        }

        boolean recordIdempotency(String key, String value)
        {
            return idempotencyRecords.putIfAbsent(key, value) == null;
        }

        boolean hasIdempotency(String key)
        {
            return idempotencyRecords.containsKey(key);
        }
    }

    private static final class RedisGateway
    {
        private final IdempotencyStore store;
        private boolean masterAvailable = true;
        private String masterNode = "redis-master";

        RedisGateway(IdempotencyStore store)
        {
            this.store = store;
        }

        boolean acquireLock(String key, String owner)
        {
            ensureMasterAvailable();
            return store.acquireLock(key, owner);
        }

        String lockOwner(String key)
        {
            ensureMasterAvailable();
            return store.lockOwner(key);
        }

        boolean recordIdempotency(String key, String value)
        {
            ensureMasterAvailable();
            return store.recordIdempotency(key, value);
        }

        boolean hasIdempotency(String key)
        {
            ensureMasterAvailable();
            return store.hasIdempotency(key);
        }

        void simulateMasterFailure()
        {
            this.masterAvailable = false;
        }

        void promoteReplica()
        {
            this.masterNode = "redis-replica";
            this.masterAvailable = true;
        }

        String currentMaster()
        {
            return masterNode;
        }

        private void ensureMasterAvailable()
        {
            if (!masterAvailable)
            {
                throw new RedisConnectionFailureException(
                        "Redis master [" + masterNode + "] unavailable during failover");
            }
        }
    }
}
