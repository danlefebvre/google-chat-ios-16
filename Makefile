.PHONY: test-relay test-ios test smoke-relay

test-relay:
	cd relay && npm test

test-ios:
	cd ios/GoogleChatMultiCore && swift test

test: test-relay test-ios

smoke-relay:
	cd relay && npm run dev
