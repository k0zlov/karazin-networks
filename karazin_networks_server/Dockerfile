
# Build stage
FROM dart:stable AS build

WORKDIR /app

# Copy package manifests for dependency caching
COPY karazin_networks_crypto/pubspec.* ./karazin_networks_crypto/
COPY karazin_networks_server/pubspec.* ./karazin_networks_server/

# Resolve server dependencies, including shared crypto
WORKDIR /app/karazin_networks_server
RUN dart pub get

# Copy source code
WORKDIR /app
COPY karazin_networks_crypto/ ./karazin_networks_crypto/
COPY karazin_networks_server/ ./karazin_networks_server/

# Build AOT application bundle
WORKDIR /app/karazin_networks_server
RUN dart build cli --target bin/server.dart -o /app/output

# Minimal runtime image
FROM scratch

# Copy Dart AOT runtime dependencies
COPY --from=build /runtime/ /

# Copy compiled application bundle
COPY --from=build /app/output/bundle/ /app/
COPY --from=build /app/karazin_networks_server/openapi.yaml /app/openapi.yaml

EXPOSE 8080

CMD ["/app/bin/server"]
