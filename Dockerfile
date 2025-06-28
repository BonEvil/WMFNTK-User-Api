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

# Set up a build area
WORKDIR /build

# Copy local dependency and app source
COPY ../WMFNTK-Models ./WMFNTK-Models
COPY ./Package.* ./WMFNTK-User-Api/
COPY . ./WMFNTK-User-Api/

# Switch into app source
WORKDIR /build/WMFNTK-User-Api

# Resolve Swift package dependencies
RUN swift package resolve --skip-update \
    $([ -f ./Package.resolved ] && echo "--force-resolved-versions" || true)

# Install build dependencies
RUN apt-get update \
    && apt-get install -y openssl libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Build the application
RUN swift build -c release --product WmfntkUserApi --static-swift-stdlib

# ================================
# Stage build artifacts
# ================================
WORKDIR /staging

# Copy the built binary
RUN cp "/build/WMFNTK-User-Api/.build/release/WmfntkUserApi" ./

# Copy SPM resource bundles
RUN find -L "/build/WMFNTK-User-Api/.build/release" -regex '.*\.resources$' -exec cp -Ra {} ./ \;

# Copy static resources if present
RUN [ -d /build/WMFNTK-User-Api/Public ] && { mv /build/WMFNTK-User-Api/Public ./Public && chmod -R a-w ./Public; } || true
RUN [ -d /build/WMFNTK-User-Api/Resources ] && { mv /build/WMFNTK-User-Api/Resources ./Resources && chmod -R a-w ./Resources; } || true

# ================================
# Run image
# ================================
FROM swift:5.9-jammy-slim

# Install runtime libraries
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

# Copy built app from build stage
COPY --from=build --chown=vapor:vapor /staging /app

# Copy AWS cert if needed
COPY ../us-east-1-bundle.pem .  # adjust path if cert is elsewhere

# Configure Swift crash reporter
ENV SWIFT_ROOT=/usr \
    SWIFT_BACKTRACE=enable=yes,sanitize=yes,threads=all,images=all,interactive=no

# Run as non-root user
USER vapor:vapor

# Expose the app port
EXPOSE 8080

# Default launch command
CMD ./WmfntkUserApi serve --env production --hostname 0.0.0.0 --port 8080
