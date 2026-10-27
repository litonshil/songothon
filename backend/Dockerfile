# ==========================================
# Multi-Stage Production Dockerfile for Songothon Go Backend
# ==========================================

# Stage 1: Builder
FROM golang:alpine AS builder

WORKDIR /app

# Install security certificates & build essentials
RUN apk update && apk add --no-cache git ca-certificates tzdata

# Cache Go modules layers
COPY go.mod go.sum ./
RUN go mod download && go mod verify

# Copy source code
COPY . .

# Build statically linked binary with optimizations (strip debug info & symbols)
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -trimpath \
    -ldflags="-w -s" \
    -o /app/bin/songothon-api \
    .

# ------------------------------------------
# Stage 2: Final Minimal Runtime Image
# ------------------------------------------
FROM alpine:3.20 AS runner

# Create dedicated non-root user and group
RUN addgroup -S appgroup -g 10001 && \
    adduser -S appuser -u 10001 -G appgroup

# Install runtime dependencies (tzdata and certificates)
RUN apk --no-cache add ca-certificates tzdata

WORKDIR /app

# Copy binary from builder
COPY --from=builder /app/bin/songothon-api /app/songothon-api
COPY --from=builder /app/migrations /app/migrations

# Secure ownership
RUN chown -R appuser:appgroup /app

USER appuser:appgroup

EXPOSE 8080

HEALTHCHECK --interval=15s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

ENTRYPOINT ["/app/songothon-api"]
CMD ["serve"]
