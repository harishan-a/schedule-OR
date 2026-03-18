# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability, please report it responsibly by emailing **harishan.a@gmail.com** instead of opening a public issue. We will acknowledge receipt within 48 hours and work on a fix promptly.

## Firebase API Keys

The Firebase configuration values found in `lib/config/firebase_options.dart` and `web/firebase-messaging-sw.js` are **client-side identifiers**, not secrets. This is standard practice for Firebase web and mobile apps.

Per [Firebase documentation](https://firebase.google.com/docs/projects/api-keys):

> Firebase API keys are not used to control access to backend resources. That can only be done with Firebase Security Rules and App Check.

Security is enforced server-side through:

- **Firestore Security Rules** (`firestore.rules`) — role-based read/write access
- **Storage Security Rules** (`storage.rules`) — scoped file access
- **Firebase Authentication** — verified user identity on every request
- **Firebase App Check** — protects backend from unauthorized clients

## Environment Variables

Actual secrets (API tokens, auth credentials) are stored in `.env` files that are gitignored. The `.env.example` file documents which variables are needed without containing real values:

| Variable | Purpose |
|----------|---------|
| `TWILIO_ACCOUNT_SID` | Twilio SMS account identifier |
| `TWILIO_AUTH_TOKEN` | Twilio SMS authentication |
| `TWILIO_PHONE_NUMBER` | Twilio sender number |
| `CLOUD_FUNCTION_URL` | Firebase Cloud Function endpoint |
| `EMAIL_API_KEY` | SendGrid email API key |

## Firestore Security Rules

All database access requires authentication. Write operations are scoped by user role (admin, doctor, nurse, technologist). See `firestore.rules` for the full rule set.
