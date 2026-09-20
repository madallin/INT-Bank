package com.intbank;

import org.junit.jupiter.api.Test;

import java.io.IOException;
import java.io.InputStream;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Stream;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

public class ZeroDowntimeMigrationTest
{

    private static final String MIGRATION_RESOURCE =
            "db/migration/V7__expand_contract_zero_downtime.sql";

    private static final Pattern VERSION_PATTERN =
            Pattern.compile("^V(\\d+)__.*\\.sql$", Pattern.CASE_INSENSITIVE);

    private static final Pattern ADD_COLUMN_NOT_NULL_PATTERN =
            Pattern.compile("add\\s+column[^;]*not\\s+null", Pattern.CASE_INSENSITIVE);

    @Test
    void migrationFileIsOnClasspath() throws IOException
    {
        String sql = readClasspathResource(MIGRATION_RESOURCE);

        assertNotNull(sql, "V7 migration must be loadable from the classpath");
        assertFalse(sql.isBlank(), "V7 migration must not be empty");
    }

    @Test
    void migrationVersionsAreUniqueAndOrdered() throws Exception
    {
        URL directoryUrl = getClass().getClassLoader().getResource("db/migration");
        assertNotNull(directoryUrl, "db/migration classpath directory must exist");

        Path directory = Paths.get(directoryUrl.toURI());
        assertTrue(Files.isDirectory(directory), "db/migration must be a directory on the test classpath");

        List<String> files = new ArrayList<>();
        try (Stream<Path> stream = Files.list(directory))
        {
            stream.filter(Files::isRegularFile)
                    .map(path -> path.getFileName().toString())
                    .forEach(files::add);
        }

        List<Integer> versions = new ArrayList<>();
        for (String file : files)
        {
            Matcher matcher = VERSION_PATTERN.matcher(file);
            if (matcher.matches())
            {
                versions.add(Integer.parseInt(matcher.group(1)));
            }
        }

        long v7Count = versions.stream().filter(version -> version == 7).count();
        assertEquals(1L, v7Count, "Migration version V7 must exist exactly once: " + files);

        Set<Integer> uniqueVersions = new HashSet<>(versions);
        assertEquals(versions.size(), uniqueVersions.size(),
                "Migration versions must be unique, found duplicates in: " + versions);
    }

    @Test
    void containsAllThreePhases() throws IOException
    {
        String sql = readClasspathResource(MIGRATION_RESOURCE).toLowerCase(Locale.ROOT);

        assertTrue(sql.contains("phase 1"), "Phase 1 EXPAND must be documented");
        assertTrue(sql.contains("add column") && sql.contains("balance_minor"),
                "Phase 1 must add the balance_minor column");
        assertTrue(sql.contains("create trigger"),
                "Phase 1 must create the dual-write trigger");

        assertTrue(sql.contains("phase 2"), "Phase 2 BACKFILL must be documented");
        assertTrue(sql.contains("procedure backfill_accounts_balance_minor"),
                "Phase 2 must define the batched backfill procedure");
        assertTrue(sql.contains("batch_size"),
                "Phase 2 batching must be parameterised by batch_size");
        assertTrue(sql.contains("limit"),
                "Phase 2 batching must use LIMIT to chunk the backfill");

        assertTrue(sql.contains("phase 3"), "Phase 3 CONTRACT must be documented");
        assertTrue(sql.contains("validate constraint"),
                "Phase 3 must validate the NOT VALID constraint");
        assertTrue(sql.contains("comment on column") && sql.contains("deprecated"),
                "Phase 3 must deprecate the legacy column via COMMENT ON COLUMN");
    }

    @Test
    void usesNonBlockingOrLockSafeDdl() throws IOException
    {
        String sql = readClasspathResource(MIGRATION_RESOURCE).toLowerCase(Locale.ROOT);

        assertTrue(sql.contains("lock_timeout"),
                "lock_timeout must be set to bound DDL lock waits");
        assertTrue(sql.contains("statement_timeout"),
                "statement_timeout must be set to bound statement runtime");

        assertFalse(sql.contains("create index concurrently"),
                "CREATE INDEX CONCURRENTLY must not be used because it breaks Flyway transactions");
        assertFalse(sql.contains("vacuum"),
                "VACUUM must not be used because it breaks Flyway transactions");

        assertFalse(ADD_COLUMN_NOT_NULL_PATTERN.matcher(sql).find(),
                "ADD COLUMN must be nullable (no NOT NULL) to avoid a full table rewrite");
    }

    @Test
    void dualWriteTriggerKeepsSoldAndBalanceMinorInSync() throws IOException
    {
        String sql = readClasspathResource(MIGRATION_RESOURCE).toLowerCase(Locale.ROOT);

        int functionStart = sql.indexOf("create or replace function sync_accounts_balance_minor");
        assertTrue(functionStart >= 0,
                "The dual-write trigger function must be created with CREATE OR REPLACE FUNCTION");

        int functionEnd = sql.indexOf("$$;", functionStart);
        assertTrue(functionEnd > functionStart,
                "The trigger function body must be delimited by dollar quoting");

        String functionBody = sql.substring(functionStart, functionEnd);
        assertTrue(functionBody.contains("balance_minor"),
                "The trigger function must reference balance_minor");
        assertTrue(functionBody.contains("new.sold"),
                "The trigger function must reference the legacy sold balance column");
        assertTrue(functionBody.contains("new.balance_minor"),
                "The trigger function must synchronise the NEW row balance_minor value");
    }

    private String readClasspathResource(String resource) throws IOException
    {
        ClassLoader classLoader = getClass().getClassLoader();
        try (InputStream stream = classLoader.getResourceAsStream(resource))
        {
            assertNotNull(stream, "Classpath resource not found: " + resource);
            return new String(stream.readAllBytes(), StandardCharsets.UTF_8);
        }
    }
}
