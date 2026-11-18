# Karazin Networks server

HTTP API for RSA key exchange and AES-256-GCM messages. Data is stored in memory.
Requires Dart 3.14.0; the Flutter client uses Flutter 3.50.0.

## Run

From `karazin_networks_server`:

```sh
dart pub get
dart run bin/server.dart
```

The server listens on port 8080 (override with `PORT`).
From the monorepo root, run both Docker services with `docker compose up --build`.

## OpenAPI and Swagger UI

- Swagger UI: http://localhost:8080/docs
- OpenAPI 3.0.3 specification: http://localhost:8080/openapi.yaml
- Source: [openapi.yaml](openapi.yaml)

Swagger UI loads its JavaScript and CSS from unpkg, so the browser needs internet access.
The YAML endpoint works offline. Both endpoints are included in the server Docker image.
The YAML file is located relative to the entrypoint, so starting the server does not depend
on the current directory. When distributing a compiled server, keep `openapi.yaml` one
level above the directory containing the executable (for example `bin/server` and `openapi.yaml`).

The specification describes the actual controller contract: RSA generation returns
`200` with `{id}`, the public key is plain text containing Base64 DER, session creation
returns `201`, and duplicate sessions return `409`. Requests to create a session require
`x-rsa-id` and `x-session-id`; messages require `x-session-id`. These headers identify
stored keys and sessions, without a separate authentication scheme.

## CI

[GitHub Actions](../.github/workflows/ci.yml) runs on every push and pull request:

- Dart 3.14.0: dependencies, analysis and unit tests in `karazin_networks_crypto`;
  dependencies, analysis, HTTP tests and executable compilation in `karazin_networks_server`.
- Flutter 3.50.0: dependencies, analysis, unit tests and a release Web build in `karazin_networks_client`.

Each step runs from its package directory so `path: ../karazin_networks_crypto` dependencies resolve.
No secrets or deployment configuration are needed.

## Session expiration

`Session` stores the session ID, AES key and `expiresAt` in UTC. The
`sessionLifetime` constant in `lib/repositories/session_repository.dart` is one minute.
The current UTC time is created with `DateTime.timestamp()`. A session is expired
when `expiresAt` is earlier than the current time. Expired sessions are retained
in memory, and their IDs cannot be reused.

`POST /api/messages` checks expiration before reading the request body and returns
HTTP `440` with `{"error":"Session expired"}`. The client creates a new RSA/AES session,
re-encrypts the original message with the new key and retries once. A second error
ends the attempt and preserves the draft.

To demonstrate: connect the client, wait longer than one minute, then send a message.
The first message request returns `440`; the client automatically establishes a new
session and sends the original text again. The reply appears on the same screen.
