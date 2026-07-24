.PHONY: test-relay test-ios test smoke-relay

test-relay:
	cd relay && go test ./...

test-ios:
	cd ios && swift test

test: test-relay test-ios

smoke-relay:
	cd relay && go run ./cmd/relay
