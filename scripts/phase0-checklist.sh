#!/usr/bin/env bash
set -euo pipefail

cat <<'EOF'
Phase 0 checklist (manual on device / Google Cloud console):

1. Install ntfy from the App Store on iPhone 8 (iOS 16.7.16).
2. Subscribe to your secret topic (optionally with access token / AutoLogin).
3. Run: NTFY_TOPIC=your-topic ./scripts/phase0-ntfy-smoke.sh
4. Create a Google Cloud project; enable Chat API, Workspace Events API, Pub/Sub.
5. Configure OAuth consent screen (Testing) and add personal + work accounts as test users.
6. Allowlist the OAuth client in Workspace admin if the work account is blocked.
7. Verify spaces.list and spaces.messages.list for both accounts.
8. Deploy relay and wire Pub/Sub push to POST /pubsub/push.

Exit criteria: both accounts return spaces/messages, and relay→ntfy reaches the phone.
EOF
