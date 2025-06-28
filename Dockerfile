# ================================
# Build image
# ================================
FROM swift:6.0-jammy AS build

# Install system updates
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    && apt-get update -q \
    && apt-get dist-upgrade -y \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir /staging

# Set up build area
WORKDIR /build

# Copy local dependency and main app code
COPY WMFNTK-Models ./WMFNTK-Models
COPY WMFNTK-User-Api/Package.* ./WMFNTK-User-Api/
COPY WMFNTK-User-Api/. ./WMFNTK-User-Api/

# Switch into app directory
WORKDIR /build/WMFNTK-User-Api

# Resolve Swift package dependencies
RUN swift package resolve --skip-update \
    $([ -f ./Package.resolved ] && echo "--force-resolved-versions" || true)

# Install build-time dependencies
RUN apt-get update \
    && apt-get install -y openssl libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Build the app
RUN swift build -c release --product WmfntkUserApi --static-swift-stdlib

# ================================
# Stage built artifacts
# ================================
WORKDIR /staging

# Copy the built binary
RUN cp "/build/WMFNTK-User-Api/.build/release/WmfntkUserApi" ./

# Copy SPM resource bundles
RUN find -L "/build/WMFNTK-User-Api/.build/release" -regex '.*\.resources$' -exec cp -Ra {} ./ \;

# Copy any static resources
RUN [ -d /build/WMFNTK-User-Api/Public ] && { mv /build/WMFNTK-User-Api/Public ./Public && chmod -R a-w ./Public; } || true
RUN [ -d /build/WMFNTK-User-Api/Resources ] && { mv /build/WMFNTK-User-Api/Resources ./Resources && chmod -R a-w ./Resources; } || true

# ================================
# Run image
# ================================
FROM swift:5.9-jammy-slim

# Install runtime dependencies
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    && apt-get update -q \
    && apt-get dist-upgrade -y \
    && apt-get install -y \
        ca-certificates \
        tzdata \
    && rm -rf /var/lib/apt/lists/*

# Create vapor user
RUN useradd --user-group --create-home --system --skel /dev/null --home-dir /app vapor

# Set working directory
WORKDIR /app

# Copy staged artifacts from build image
COPY --from=build --chown=vapor:vapor /staging /app

# Optional: Copy AWS cert
COPY ../us-east-1-bundle.pem .  # Ensure it exists in parent context

# Configure crash reporter
ENV SWIFT_ROOT=/usr \
    SWIFT_BACKTRACE=enable=yes,sanitize=yes,threads=all,images=all,interactive=no

# Run as non-root
USER vapor:vapor

# Expose app port
EXPOSE 8080

# Default startup command
CMD ./WmfntkUserApi serve --env production --hostname 0.0.0.0 --port 8080
