FROM golang:1.22-alpine AS build
WORKDIR /src
COPY go.mod ./
COPY . .
RUN CGO_ENABLED=0 go build -o /out/relay ./cmd/relay
RUN mkdir -p /out/data && chown 65532:65532 /out/data

FROM gcr.io/distroless/static-debian12:nonroot
WORKDIR /
COPY --from=build /out/relay /relay
COPY --from=build --chown=nonroot:nonroot /out/data /data
ENV PORT=8080
ENV ACCOUNTS_PATH=/data/accounts.json
EXPOSE 8080
USER nonroot:nonroot
ENTRYPOINT ["/relay"]
