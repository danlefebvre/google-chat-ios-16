FROM golang:1.22-alpine AS build
WORKDIR /src
COPY go.mod ./
COPY . .
RUN CGO_ENABLED=0 go build -o /out/relay ./cmd/relay

FROM alpine:3.20
RUN apk add --no-cache ca-certificates
WORKDIR /app
COPY --from=build /out/relay /app/relay
ENV PORT=8080
EXPOSE 8080
USER nobody
ENTRYPOINT ["/app/relay"]
