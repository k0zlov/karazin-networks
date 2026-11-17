
# Build stage
FROM dart:stable AS build

WORKDIR /app

# Copy package manifests for dependency caching
COPY lab6_crypto/pubspec.* ./lab6_crypto/
COPY lab6_server/pubspec.* ./lab6_server/

# Resolve server dependencies, including shared crypto
WORKDIR /app/lab6_server
RUN dart pub get

# Copy source code
WORKDIR /app
COPY lab6_crypto/ ./lab6_crypto/
COPY lab6_server/ ./lab6_server/

# Build AOT application bundle
WORKDIR /app/lab6_server
RUN dart build cli --target bin/server.dart -o /app/output

# Minimal runtime image
FROM scratch

# Copy Dart AOT runtime dependencies
COPY --from=build /runtime/ /

# Copy compiled application bundle
COPY --from=build /app/output/bundle/ /app/
COPY --from=build /app/lab6_server/openapi.yaml /app/openapi.yaml

EXPOSE 8080

CMD ["/app/bin/server"]
