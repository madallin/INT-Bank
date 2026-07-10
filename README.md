<p align="center">
  <img width="400" alt="INT Bank Logo" src="https://github.com/user-attachments/assets/427b0234-cc2e-4cbd-a225-1fe652104d38" />
</p>

<p align="center">
  <h3 align="center">Secure Internet Banking Platform</h3>
</p>

<p align="center">
  A modern, event-driven Internet Banking application built with <strong>Flutter</strong> and <strong>Spring Boot</strong>, featuring real-time transactions via <strong>Apache Kafka</strong>, SMS-based two-factor authentication, and a hexagonal architecture backend.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/build-passing-brightgreen?style=flat-square" alt="Build Status" />
  <img src="https://img.shields.io/badge/coverage-85%25-brightgreen?style=flat-square" alt="Coverage" />
  <img src="https://img.shields.io/badge/license-Proprietary-red?style=flat-square" alt="License" />
  <img src="https://img.shields.io/badge/version-1.0.0-blue?style=flat-square" alt="Version" />
  <img src="https://img.shields.io/badge/Java-21-orange?style=flat-square" alt="Java" />
  <img src="https://img.shields.io/badge/Dart-3.9%2B-0175C2?style=flat-square" alt="Dart" />
</p>

---

## 📋 Table of Contents

- [Key Features](#-key-features)
- [Architecture & Tech Stack](#-architecture--tech-stack)
- [Project Structure](#-project-structure)
- [Prerequisites](#-prerequisites)
- [Getting Started](#-getting-started)
- [API Endpoints](#-api-endpoints)
- [Security Measures](#-security-measures)
- [Testing](#-testing)
- [Contributing](#-contributing)
- [License](#-license)

---

## ✨ Key Features

### 🔐 Secure Authentication
- **Phone-based login** with SMS OTP via Twilio Verify
- **Two-Factor Authentication (2FA)** with configurable retry limits and cooldown periods
- **JWT-based client tokens** with short-lived access tokens (5 min) and refresh token rotation
- **Token blacklisting** in Redis on logout or expiry
- **Rate limiting** on sensitive endpoints (OTP resend: 1‑min cooldown)

### 👤 User Registration & Onboarding
- Multi-step registration flow with Romanian national fields (CNP, county, locality)
- Address geocoding integration for accurate location data
- Terms & conditions acceptance tracking
- Admin approval workflow for new accounts

### 💸 Transfers & Payments
- **IBAN-to-IBAN transfers** with beneficiary and sender metadata
- **Asynchronous processing** via Apache Kafka with the **Saga orchestration pattern** for distributed consistency
- **Outbox pattern** with dead-letter queue (DLQ) for reliable message delivery
- Real-time transfer status updates via WebSocket push notifications
- **Kafka UI** dashboard for monitoring message queues

### 📊 Account Management
- Multi-currency account balances with Redis-backed cache
- Exchange rate lookups with configurable refresh intervals
- Transaction history with filtering and pagination

### 🛡️ Admin Dashboard
- Outbox statistics and dead-message reprocessing
- DLQ monitoring and manual intervention endpoints
- Read-model projector health checks
- Balance cache operational status

### 🎨 User Experience
- Modern **Material 3** design with Google Fonts (Inter)
- Custom PIN pad for secure numeric input
- Step indicators for multi-step flows
- Romanian-language interface with localized error messages

---

## 🏗 Architecture & Tech Stack

| Layer | Technology | Purpose |
|---|---|---|
| **Frontend** | Flutter 3.x, Dart SDK ^3.9.2 | Cross-platform mobile & web UI |
| **State Management** | Riverpod (`flutter_riverpod`) | Reactive, compile-safe state management |
| **Routing** | GoRouter v14 | Declarative, type-safe navigation |
| **HTTP Client** | Dio v5 + `http` | REST API communication |
| **Real-Time** | `web_socket_channel` | Live transfer status updates |
| **Secure Storage** | `flutter_secure_storage` | On-device credential persistence |
| **Backend** | Spring Boot 3.3.3, Java 21 | REST API & business logic |
| **Architecture** | Hexagonal (Ports & Adapters) | Clean separation of domain, application, and infrastructure |
| **Database** | PostgreSQL 16 | ACID-compliant relational persistence |
| **Cache** | Redis 7 | Token blacklisting, rate limiting, balance cache |
| **Messaging** | Apache Kafka 7.6.0 (Confluent) | Async transfer processing, Saga orchestration, Outbox pattern |
| **Coordination** | Zookeeper | Kafka cluster metadata management |
| **Auth** | JWT (jjwt 0.12.6), Twilio Verify | Client tokens, SMS OTP 2FA |
| **Rate Limiting** | Bucket4j v8 | Per-endpoint throttling |
| **TLS** | Self-signed certs (`certs/`) | HTTPS with TLS 1.2+ |
| **Logging** | Logstash Logback Encoder | Structured JSON logging |
| **Containerization** | Docker Compose (6 services) | Reproducible local & CI environments |
| **Monitoring** | Kafka UI (`provectuslabs/kafka-ui`) | Broker, topic, and consumer group visualization |

### Hexagonal Architecture (Backend)

```
com.intbank
├── application/          → Use cases, Saga orchestrator
├── core/
│   ├── domain/           → Domain entities, value objects
│   └── port/             → Input/output port interfaces
├── infrastructure/
│   ├── rest/             → Controllers & DTOs (primary adapters)
│   ├── persistence/      → JPA entities & repositories (secondary)
│   ├── messaging/        → Kafka producers/consumers (secondary)
│   ├── security/         → JWT filters, CORS config
│   ├── websocket/        → WebSocket handlers
│   └── exception/        → Global error handling
├── service/              → Domain services (crypto, currency, outbox, retry)
└── config/               → Spring bean configurations
```

---

## 📁 Project Structure

```
INTBank/
├── internet_banking/           # Flutter frontend
│   ├── lib/
│   │   ├── config/             # App configuration
│   │   ├── core/               # Network, storage, utilities
│   │   ├── data/models/        # JSON-serializable models
│   │   ├── features/           # Feature modules (auth, home, transfers, etc.)
│   │   ├── providers/          # Riverpod state providers
│   │   ├── router/             # GoRouter configuration
│   │   ├── services/           # API, JWT, currency services
│   │   └── widgets/            # Reusable UI components
│   ├── assets/                 # Images, fonts, JSON data
│   ├── test/                   # Unit & widget tests
│   └── pubspec.yaml
├── server/
│   ├── docker-compose.yml      # Full stack orchestration
│   ├── .env                    # Environment variables
│   ├── certs/                  # TLS certificates
│   └── backend/                # Spring Boot backend
│       ├── Dockerfile
│       ├── pom.xml
│       └── src/
│           ├── main/java/com/intbank/
│           └── test/java/com/intbank/
├── .gitignore
├── LICENSE.md
└── README.md
```

---

## 📦 Prerequisites

| Tool | Minimum Version | Purpose |
|---|---|---|
| **Git** | 2.x | Clone the repository |
| **Flutter SDK** | 3.x (Dart ^3.9.2) | Build and run the frontend |
| **Java JDK** | 21 | Compile and run the Spring Boot backend |
| **Maven** | 3.9+ | Backend dependency management & build |
| **Docker** | 24+ | Run PostgreSQL, Redis, Kafka, and Zookeeper |
| **Docker Compose** | 2.x | Orchestrate multi-container infrastructure |

> **Optional:** [Android Studio](https://developer.android.com/studio) or [Xcode](https://developer.apple.com/xcode/) for mobile emulation.

---

## 🚀 Getting Started

### 1. Clone the Repository

```bash
git clone https://github.com/madallin/INTBank.git
cd INTBank
```

### 2. Configure Environment Variables

Create the required `.env` files for both the server and the Flutter app.

#### Server: `server/.env`

```env
# Database
DB_PASSWORD=your_secure_password

# Twilio (SMS OTP)
TWILIO_ACCOUNT_SID=your_account_sid
TWILIO_AUTH_TOKEN=your_auth_token
TWILIO_SERVICE_SID=your_verify_service_sid

# JWT
JWT_SECRET=your_256_bit_base64_encoded_secret

# Kafka
KAFKA_BROKERS=localhost:9092
```

#### Flutter: `internet_banking/.env`

```env
API_BASE_URL=https://YOUR_LOCAL_IP:8443
WS_BASE_URL=wss://YOUR_LOCAL_IP:8443/ws
```

> **⚠️ Important:** The Flutter app communicates over HTTPS/TLS. The `API_BASE_URL` should use your machine's **local network IP address** (not `localhost` or `127.0.0.1`) when testing on physical devices or emulators. Example: `https://192.168.1.100:8443`.

### 3. Start Infrastructure Services (PostgreSQL, Redis, Kafka)

```bash
cd server
docker compose up -d postgres redis zookeeper kafka kafka-ui
```

Wait for all services to become healthy:

```bash
docker compose ps
```

Kafka UI dashboard will be available at [http://localhost:8080](http://localhost:8080).

### 4. Run the Backend

#### Option A: Maven (Development)

```bash
cd server/backend
./mvnw spring-boot:run -Dspring-boot.run.profiles=dev
```

The backend starts on **port 8443** with TLS enabled.

#### Option B: Docker (via Docker Compose)

```bash
cd server
DB_PASSWORD=your_password docker compose --profile full up -d backend
```

Verify the backend is running:

```bash
curl -k https://localhost:8443/health
# → {"status":"ok"}
```

### 5. Run the Frontend

```bash
cd internet_banking
flutter pub get
flutter run
```

Or launch on a specific device:

```bash
# List available devices
flutter devices

# Run on Chrome (web)
flutter run -d chrome

# Run on Android emulator
flutter run -d emulator-5554

# Run on iOS simulator (macOS only)
flutter run -d iPhone-15
```

### 6. Full Stack via Docker Compose (One Command)

```bash
cd server

# Set the DB password environment variable
export DB_PASSWORD=your_secure_password

# Start everything
docker compose --profile full up -d
```

This starts: PostgreSQL → Redis → Zookeeper → Kafka → Kafka UI → Backend (Spring Boot).

---

## 🔌 API Endpoints

### Authentication & Verification

| Method | Endpoint | Description | Auth Required |
|---|---|---|---|
| `POST` | `/auth/get-client-token` | Obtain a short-lived JWT client token for a device | No |
| `POST` | `/auth/refresh-client-token` | Refresh an expired client token using a refresh token | Refresh Token |
| `POST` | `/auth/send-otp-sms` | Send an OTP code via SMS to a phone number | Client Token |
| `POST` | `/2fa/request` | Request a 2FA verification code (SMS) | Client Token |
| `POST` | `/2fa/verify` | Verify the 2FA code received via SMS | Client Token |

### User Management

| Method | Endpoint | Description | Auth Required |
|---|---|---|---|
| `POST` | `/login` | Check if a user exists by phone number; returns approval status | Client Token |
| `POST` | `/register` | Register a new bank account with personal and address details | Client Token |

### Transfers

| Method | Endpoint | Description | Auth Required |
|---|---|---|---|
| `POST` | `/transfers` | Initiate an IBAN-to-IBAN transfer (async processing via Kafka) | Client Token |

**Sample Transfer Request:**

```json
{
  "fromIban": "RO49AAAA1B31007593840000",
  "toIban": "RO49BBBB1B31007593841111",
  "amount": 250.00,
  "currency": "RON",
  "reason": "Chirie luna iulie",
  "beneficiaryName": "Ion Popescu",
  "senderName": "Maria Ionescu"
}
```

**Sample Response (202 Accepted):**

```json
{
  "status": 202,
  "trackingId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "message": "Transfer initiated successfully",
  "transferStatus": "PENDING"
}
```

### Admin

| Method | Endpoint | Description | Auth Required |
|---|---|---|---|
| `GET` | `/admin/outbox/stats` | Get outbox table statistics (pending, processed, dead) | Admin |
| `POST` | `/admin/outbox/reprocess-dead` | Requeue all dead-letter messages for reprocessing | Admin |
| `POST` | `/admin/outbox/process-now` | Trigger immediate outbox processing | Admin |
| `GET` | `/admin/dlq/stats` | Get dead-letter queue statistics | Admin |
| `GET` | `/admin/balances` | Check read-model projector and balance cache status | Admin |

### Health

| Method | Endpoint | Description | Auth Required |
|---|---|---|---|
| `GET` | `/health` | Health check endpoint for orchestrator liveness probes | No |

---

## 🔒 Security Measures

This banking platform implements defense-in-depth security across multiple layers:

### Authentication & Authorization
- **JWT (JSON Web Tokens):** HMAC-SHA256 signed tokens with 5-minute TTL for client sessions. Refresh tokens are cryptographically random 32-byte values stored in Redis.
- **Two-Factor Authentication (2FA):** SMS-based OTP codes delivered via **Twilio Verify v2**. Enforced cooldown (1 minute) between resend attempts and maximum verification attempts before lockout.
- **Token Blacklisting:** Compromised or logged-out tokens are immediately blacklisted in Redis with TTL equal to the token's remaining lifetime.

### Transport & Data Protection
- **TLS 1.2+:** All communication between the Flutter client and Spring Boot backend is encrypted using TLS. Certificates are stored in the `server/certs/` directory.
- **Flutter Secure Storage:** On-device tokens and sensitive data are stored using platform-native secure storage (Keychain on iOS, EncryptedSharedPreferences on Android).

### Attack Surface Reduction
- **Bucket4j Rate Limiting:** Token-based rate limiting on authentication and 2FA endpoints to prevent brute-force and SMS pumping attacks.
- **CORS Configuration:** Strict `WebConfig` with explicit allowed origins, methods, and headers. No wildcard (`*`) origins in production.
- **Input Validation:** All DTOs use Jakarta Bean Validation (`@Valid`) with constraints. Registration, login, and transfer payloads are validated server-side.
- **Duplicate Record Prevention:** Database unique constraints on email and CNP (Romanian national ID) prevent duplicate registrations.

### Infrastructure Security
- **Isolated Docker Network:** All services communicate over `intbank-network` (bridge driver), not exposed on host interfaces unless explicitly mapped.
- **Health Checks:** Every container has health checks with retries, ensuring dependent services only start when their prerequisites are healthy.
- **Non-Root Containers:** PostgreSQL and Redis use Alpine-based images with minimal attack surface.

---

## 🧪 Testing

### Backend (Spring Boot)

```bash
cd server/backend

# Run all unit and integration tests
./mvnw test

# Run a specific test class
./mvnw test -Dtest=TransferUseCaseTest

# Run tests with coverage report
./mvnw test jacoco:report
```

### Frontend (Flutter)

```bash
cd internet_banking

# Run all unit and widget tests
flutter test

# Run tests with coverage
flutter test --coverage

# Generate coverage report (requires lcov)
genhtml coverage/lcov.info -o coverage/html
```

---

## 🤝 Contributing

Contributions are welcome! This project follows a standard Git workflow:

1. **Fork** the repository
2. **Create** a feature branch: `git checkout -b feat/amazing-feature`
3. **Commit** your changes: `git commit -m 'feat: add amazing feature'`
4. **Push** to the branch: `git push origin feat/amazing-feature`
5. **Open** a Pull Request

### Commit Convention

This project uses [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` — A new feature
- `fix:` — A bug fix
- `docs:` — Documentation changes
- `refactor:` — Code restructuring without functional changes
- `test:` — Adding or updating tests
- `chore:` — Build process, tooling, or dependency updates

### Code Style

- **Java:** Follow standard Spring Boot conventions. Lombok is used to reduce boilerplate.
- **Dart:** Follow the [Effective Dart](https://dart.dev/guides/language/effective-dart) guidelines. Run `flutter analyze` before committing.

---

## 📄 License

This project is licensed under a **Proprietary & Confidential License**. It is intended exclusively as a **portfolio piece** for prospective employers and technical recruiters.

> **Permitted:** Temporary viewing, auditing, and evaluation for interview assessment purposes.
>
> **Not Permitted:** Copying, modification, redistribution, or use in any commercial or production environment.

See [`LICENSE.md`](./LICENSE.md) for the full legal text.
