FROM golang:1.27.2 AS build
ARG VERSION=0.1.0
ARG COMMIT=dev
ARG BUILD_UID=65532
ARG BUILD_GID=65532
ENV HOME=/tmp GOCACHE=/tmp/go-cache GOMODCACHE=/tmp/go-mod-cache
WORKDIR /src
COPY --chown=${BUILD_UID}:${BUILD_GID} go.mod go.sum ./
USER ${BUILD_UID}:${BUILD_GID}
RUN go mod download
COPY --chown=${BUILD_UID}:${BUILD_GID} . .
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w -X main.version=$VERSION -X main.commit=$COMMIT" -o /tmp/beget-s3 ./cmd/beget-s3
FROM scratch
COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=build /tmp/beget-s3 /beget-s3
# Introspection placeholder only. Real keys are passed with -e and override it.
ENV BEGET_S3_ACCESS_KEY_ID=introspection-placeholder-not-a-key
ENV BEGET_S3_SECRET_ACCESS_KEY=introspection-placeholder-not-a-key
LABEL io.modelcontextprotocol.server.name="io.github.stufently/beget-s3-mcp-ai-cli"
LABEL org.opencontainers.image.source="https://github.com/stufently/beget-s3-mcp-ai-cli"
USER 65532:65532
ENTRYPOINT ["/beget-s3"]
CMD ["mcp"]
