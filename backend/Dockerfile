ARG GO_VERSION=1.26

FROM golang:${GO_VERSION}-alpine AS builder

RUN mkdir /user && \
    echo 'nobody:x:65534:65534:nobody:/:' > /user/passwd && \
    echo 'nobody:x:65534:' > /user/group

RUN apk add --no-cache ca-certificates git
RUN apk --no-cache add tzdata

WORKDIR /src
COPY ./ ./
ENV GOTOOLCHAIN=auto
RUN CGO_ENABLED=0 go build -o /app .

######## Start a new stage from alpine #######
FROM alpine:3.19 AS final

# Import the user and group files from the first stage.
COPY --from=builder /user/group /user/passwd /etc/
# Import the timezone data from build stage.
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo
# Import the Certificate-Authority certificates for enabling HTTPS.
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
# Import the compiled executable from the first stage.
COPY --from=builder /app /app
# Import the migrations directory from the builder stage.
COPY --from=builder /src/migrations /migrations

EXPOSE 8080

USER nobody:nobody

ENTRYPOINT ["/app"]
