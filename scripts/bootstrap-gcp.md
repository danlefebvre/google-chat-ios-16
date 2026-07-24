# Bootstrap Google Cloud (Phase 0 / MVP)

Run these once in a project you control. You are Workspace admin for the work account.

1. Create a GCP project and enable APIs:
   - Google Chat API
   - Google Workspace Events API
   - Cloud Pub/Sub API
   - People API (optional, for display names)

2. Configure OAuth consent screen in **Testing** mode; add personal + work accounts as test users.

3. Create OAuth clients:
   - iOS client → put client ID into `ios/project.yml` (`GOOGLE_CLIENT_ID` / URL scheme)
   - Web/other client for the relay token exchange if needed

4. Create a Pub/Sub topic + push subscription pointing at:
   `https://<relay-host>/pubsub/push`

5. Allowlist the OAuth client under Workspace **API controls** for the work domain.

6. Deploy `relay/` (Cloud Run / Fly) with secrets:
   - `NTFY_TOPIC`, `NTFY_TOKEN`, `TOKEN_ENCRYPTION_KEY`
   - Google client credentials used to create Workspace Events subscriptions

7. Prove the path:
   ```bash
   ./scripts/test-ntfy.sh          # direct to ntfy
   RELAY_URL=... ./scripts/test-ntfy.sh
   ```
