# ================================
# Build image
# ================================
FROM swift:6.0-noble AS build

# Install OS updates
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    && apt-get -q update \
    && apt-get -q dist-upgrade -y \
    && apt-get install -y libjemalloc-dev

# Set up a build area
WORKDIR /build

# Copy local dependency and main app source
COPY WMFNTK-Models ./WMFNTK-Models
COPY WMFNTK-User-Api/Package.* ./WMFNTK-User-Api/
COPY WMFNTK-User-Api/. ./WMFNTK-User-Api/

# Resolve dependencies
WORKDIR /build/WMFNTK-User-Api
RUN swift package resolve \
    $([ -f ./Package.resolved ] && echo "--force-resolved-versions" || true)

# Build the application
RUN swift build -c release \
    --product WmfntkUserApi \
    --static-swift-stdlib \
    -Xlinker -ljemalloc

# ================================
# Staging
# ================================
WORKDIR /staging

# Copy main executable to staging area
RUN cp "/build/WMFNTK-User-Api/.build/release/WmfntkUserApi" ./

# Copy static swift backtracer binary
RUN cp "/usr/libexec/swift/linux/swift-backtrace-static" ./

# Copy resources bundled by SPM
RUN find -L "/build/WMFNTK-User-Api/.build/release" -regex '.*\.resources$' -exec cp -Ra {} ./ \;

# Copy any public/resources if present
RUN [ -d /build/WMFNTK-User-Api/Public ] && { mv /build/WMFNTK-User-Api/Public ./Public && chmod -R a-w ./Public; } || true
RUN [ -d /build/WMFNTK-User-Api/Resources ] && { mv /build/WMFNTK-User-Api/Resources ./Resources && chmod -R a-w ./Resources; } || true

# ================================
# Run image
# ================================
FROM ubuntu:noble

# Install runtime dependencies
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    && apt-get -q update \
    && apt-get -q dist-upgrade -y \
    && apt-get -q install -y \
        libjemalloc2 \
        ca-certificates \
        tzdata \
    && rm -r /var/lib/apt/lists/*

# Create a vapor user
RUN useradd --user-group --create-home --system --skel /dev/null --home-dir /app vapor

# Set working directory
WORKDIR /app

# Copy app and resources
COPY --from=build --chown=vapor:vapor /staging /app

# Configure Swift backtrace
ENV SWIFT_BACKTRACE=enable=yes,sanitize=yes,threads=all,images=all,interactive=no,swift-backtrace=./swift-backtrace-static

# Switch to non-root user
USER vapor:vapor

# Expose app port
EXPOSE 8080

# Entry point
ENTRYPOINT ["./WmfntkUserApi"]
CMD ["serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "8080"]
