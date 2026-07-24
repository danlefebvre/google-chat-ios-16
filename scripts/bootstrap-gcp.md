# Bootstrap Google Cloud (Phase 0 / relay)

Manual checklist — run in a project you control:

1. Create a GCP project; enable **Google Chat API**, **Google Workspace Events API**, **Pub/Sub**, and **People API** as needed.
2. Configure OAuth consent screen in **Testing**; add personal + work accounts as test users.
3. Create an OAuth client (iOS + Web/installed as required by GoogleSignIn / relay).
4. As Workspace admin, allowlist the OAuth client under API controls if work login is blocked.
5. Create a Pub/Sub topic for Workspace Events; grant `roles/pubsub.publisher` to the Workspace Events service agent.
6. Deploy `relay/` (Cloud Run / Fly) with secrets:
   - `NTFY_BASE_URL=https://ntfy.sh`
   - `NTFY_TOPIC=<hard-to-guess>`
   - `NTFY_ACCESS_TOKEN=<optional but recommended>`
   - Google refresh credentials / encryption key for token-at-rest
7. Point Pub/Sub push subscription at `https://<relay>/v1/pubsub/push` with `accountId` attributes.
8. On the phone: install **ntfy**, subscribe to the topic (token/AutoLogin if used), then run `./scripts/phase0-smoke.sh`.
