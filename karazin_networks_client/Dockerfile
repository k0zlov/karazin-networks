
# Build Flutter Web
FROM debian:bookworm-slim AS build

RUN apt-get update && apt-get install -y \
    --no-install-recommends \
    git curl ca-certificates unzip xz-utils zip \
    && rm -rf /var/lib/apt/lists/*

# Install Flutter 3.50.0 with Dart 3.14.0
ARG FLUTTER_VERSION=3.50.0

RUN git clone --depth 1 \
    --branch ${FLUTTER_VERSION} \
    https://github.com/flutter/flutter.git /opt/flutter

ENV PATH="/opt/flutter/bin:${PATH}"
ENV FLUTTER_SUPPRESS_ANALYTICS=true

RUN flutter --version
RUN flutter precache --web

# Copy monorepo packages
WORKDIR /app
COPY karazin_networks_crypto/ ./karazin_networks_crypto/
COPY karazin_networks_client/ ./karazin_networks_client/

WORKDIR /app/karazin_networks_client

RUN flutter pub get

ARG API_BASE_URL=http://localhost:8080

RUN flutter build web --release \
    --dart-define=API_BASE_URL=${API_BASE_URL}

# Minimal runtime
FROM busybox:stable

COPY --from=build /app/karazin_networks_client/build/web/ /www/

EXPOSE 80

CMD ["httpd", "-f", "-p", "80", "-h", "/www"]
