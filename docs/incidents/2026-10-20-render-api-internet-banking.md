# Incident review: Render deployment failures — 2026-10-20

**Service:** `api-internet-banking` (`srv-d8hfnrj7uimc73cvg51g`)  
**Scope:** Read-only investigation of two Render failure notifications and their GitHub commits; no application changes and no deploy/retry actions.  
**Evidence limit:** The Render deployment-log pages require authenticated Render access and could not be inspected through the available connection. Attempts to fetch historical GitHub job logs returned HTTP 410; no workflow artifacts were available. Do not treat the hypotheses below as verified Render root causes.

## Correlation and timeline (UTC)

| Evidence | Commit `3a775e8c` | Commit `a4eda68b` |
| --- | --- | --- |
| Render deploy | [`dep-dbbq3g17lnhs73fljgjg`](https://dashboard.render.com/web/srv-d8hfnrj7uimc73cvg51g/deploys/dep-dbbq3g17lnhs73fljgjg) | [`dep-dbbr41cs728c73cohsd0`](https://dashboard.render.com/web/srv-d8hfnrj7uimc73cvg51g/deploys/dep-dbbr41cs728c73cohsd0) |
| Render failure-email timestamp | 2026-10-20 17:21:58 | 2026-10-20 18:29:31 |
| GitHub Actions push CI | [run 39464522732](https://github.com/madallin/INT-Bank/actions/runs/39464522732): **failed** | [run 39474553326](https://github.com/madallin/INT-Bank/actions/runs/39474553326): **passed** |
| Backend tests and coverage | Pass | Pass |
| Flutter analysis/tests/coverage; Helm; secret scan | Pass | Pass |
| Dependency (filesystem) vulnerability scan | Pass | Pass |
| Backend image build + Trivy report | Pass | Pass |
| Trivy **built-image gate** | **Fail** | **Pass** |
| Render deploy result | **Failed** | **Failed** |

There was a **separate** Render alert at **17:25:28 UTC** stating `Exited with status 1` for the service. This establishes an instance exit, **not** which of these deploy IDs produced it or why. Both deployment-failure messages state only that deployment failed, not the failing build/start/health-check stage.

## Confirmed GitHub findings

1. At `3a775e8c`, the `Backend image vulnerabilities` job ran for approximately **4m10s** (17:17:01–17:21:11 UTC). Image **build** and the report-mode Trivy scan passed; `Trivy image scan (gate)` failed. Therefore the evidence is a failing **image-security quality gate**, not a Docker compilation failure. [Job](https://github.com/madallin/INT-Bank/actions/runs/39464522732/job/118772926062)
2. [PR #19](https://github.com/madallin/INT-Bank/pull/19) documents **14 fixable HIGH/CRITICAL Java-library findings** (notably Spring MVC, Tomcat, Netty and Jackson) and **three HIGH findings** in the `pebble` binary of the then-current base image. This is retrospective PR documentation; individual CVEs could not be independently reconstructed from the now-unavailable job log/report.
3. Between the two commits, [comparison](https://github.com/madallin/INT-Bank/compare/3a775e8c2a6d7d1349fc1ef11d6ebd551a956988...a4eda68b2193e88097942849597ed0afce6a844d) shows six changed files (10 intervening commits). The runtime base moved from `eclipse-temurin:21-jre` to `eclipse-temurin:21-jre-alpine`, with `apk upgrade` and Alpine runtime utilities. Maven moved from Spring Boot **3.5.16** to **4.1.1**, plus patched dependencies, changed starter modules and test imports. See [Dockerfile](https://github.com/madallin/INT-Bank/blob/a4eda68b2193e88097942849597ed0afce6a844d/server/backend/Dockerfile), [POM](https://github.com/madallin/INT-Bank/blob/a4eda68b2193e88097942849597ed0afce6a844d/server/backend/pom.xml), and [PR #20](https://github.com/madallin/INT-Bank/pull/20).
4. At `a4eda68b`, **all six CI jobs passed**, including the Trivy image gate. This shows that the updated CI-built image passed the configured threshold on that run. It does **not** establish successful startup on Render.
5. Both commits use the same [CI workflow](https://github.com/madallin/INT-Bank/blob/a4eda68b2193e88097942849597ed0afce6a844d/.github/workflows/ci.yml) and the same comment-only [`.trivyignore`](https://github.com/madallin/INT-Bank/blob/a4eda68b2193e88097942849597ed0afce6a844d/.trivyignore). The image gate continues to block fixable HIGH/CRITICAL `os,library` findings (`ignore-unfixed: true`, `exit-code: '1'`); no CVE ignore entry was added.
6. The application configuration contains `server.port: ${PORT:8443}`, while the Docker `HEALTHCHECK` uses `${PORT:-8080}` and `EXPOSE 8080`. This **pre-existing** mismatch matters **only when `PORT` is unset**; Render normally supplies `PORT` (default 10000). It is not evidence of the observed error. [Spring configuration](https://github.com/madallin/INT-Bank/blob/a4eda68b2193e88097942849597ed0afce6a844d/server/backend/src/main/resources/application.yml) · [Dockerfile](https://github.com/madallin/INT-Bank/blob/a4eda68b2193e88097942849597ed0afce6a844d/server/backend/Dockerfile)

## What is *not* established

- The Trivy failure **does not establish** the cause of the first Render deployment failure. GitHub Actions and Render are separate systems; the Render notification supplies no failure stage or traceback.
- The successful Trivy scan **does not establish** the cause of the second Render deployment failure. A Docker image may build/scan cleanly but fail to start or pass health checks.
- The `Exited with status 1` alert cannot be attributed to either exact deployment without the corresponding Render event/log correlation.
- We did **not** read Render service settings or secrets, test a live endpoint, modify the app, or reproduce a failure locally.

## Ranked hypotheses (require confirmation)

| Hypothesis | Why it is plausible | Smallest differentiating observation |
| --- | --- | --- |
| **A. Runtime startup or missing/misconfigured environment/dependency** | The service emitted an exit-code-1 alert. [`application.yml`](https://github.com/madallin/INT-Bank/blob/a4eda68b2193e88097942849597ed0afce6a844d/server/backend/src/main/resources/application.yml) depends on PostgreSQL, Redis, Kafka and security-related configuration. | First fatal exception + 15–30 preceding lines in each deploy's Render **runtime** log; compare error class and missing variable **name only**. |
| **B. Spring Boot 4 runtime compatibility/regression for the second commit** | `a4eda68b` changes framework major version, starter modules and dependency graph; CI tests do not prove the Render environment starts. | Check if the second log contains a new class/method/bean/configuration exception absent from the first. |
| **C. Render build/configuration discrepancy** | Render may build with different Docker context/path or environment than GitHub CI; the actual Render settings are unavailable. | Read the failure stage and inspect Render's read-only build context, Dockerfile path and root directory against CI's `context: server`, `file: server/backend/Dockerfile`. |
| **D. Port/health-check mismatch or startup timeout** | Defaults differ when `PORT` is absent, and startup could be delayed by dependencies/migrations. | Read Render's bound-port and health-check error, `PORT` **presence/value**, and configured health path; do not change values yet. |

These are candidates, **not diagnoses**. In particular, A and B cannot be reliably ranked against an unseen Render exception.

## Minimum safe next verification (no deployment or repository change)

1. Open each [deployment A](https://dashboard.render.com/web/srv-d8hfnrj7uimc73cvg51g/deploys/dep-dbbq3g17lnhs73fljgjg) and [deployment B](https://dashboard.render.com/web/srv-d8hfnrj7uimc73cvg51g/deploys/dep-dbbr41cs728c73cohsd0) in Render. Identify whether it failed at **Docker build**, **process startup** or **health check**. Capture the **first error** and nearby context in each, with credentials, database URLs, tokens and certificates redacted.
2. If the messages differ, compare the first exception type and phase; for example, `BeanCreationException`, `Unable to connect`, `Port scan timeout reached`, `HTTP health check failed`, or `exited with status 1`. These are **examples to search for**, not observed errors.
3. If the first errors are identical or absent, perform a **read-only** check of Render service settings: Dockerfile path/context/root, `PORT` value or absence, HTTP health-check path, and **presence only** of required environment keys (`PGHOST`, `PGPORT`, `PGDATABASE`, `PGUSER`, `PGPASSWORD`, `CARD_ENCRYPTION_KEY`, Kafka and Redis settings). Never copy secret values into an issue or PR.
4. If Render logs are unavailable but local Docker is available, a local-only reproduction can use an **isolated worktree**, build each SHA with the **same CI context and Dockerfile**, and inspect startup logs with **non-production test credentials**. This is a larger second step; do not start here, because the Render failure may be configuration-specific.

**Stop criterion:** A clear first failing stage/exception for each deploy is enough to decide whether the incidents share a failure mode, whether the Spring Boot 4 change introduces a new one, or whether Render configuration must be inspected. No deploy retry is needed to make that distinction.

**Operational safeguards:** Keep Trivy's HIGH/CRITICAL gate enabled. Do not merge a prospective runtime fix or restart Render until the failure is identified. This document introduces **no application changes**.

### Source links

- [PR #19 — remaining image vulnerabilities](https://github.com/madallin/INT-Bank/pull/19)
- [PR #20 — remediation and CI results](https://github.com/madallin/INT-Bank/pull/20)
- [GitHub CI A](https://github.com/madallin/INT-Bank/actions/runs/39464522732) and [GitHub CI B](https://github.com/madallin/INT-Bank/actions/runs/39474553326)
- [Render: troubleshooting deploys](https://render.com/docs/troubleshooting-deploys), [Render: port binding](https://render.com/docs/web-services), [Render: auto-deploy settings](https://render.com/docs/deploys)
