# API Verification – Flutter ↔ Backend

This document confirms that the Flutter app is aligned with the Arena of Coders NestJS backend.

## Base URL & Auth

- **Backend** runs on `PORT` (default `3000`). CORS allows mobile (no origin).
- **Flutter** `ApiService.baseUrl`: set to your backend (e.g. `http://10.0.2.2:3000` for Android emulator, `http://<YOUR_IP>:3000` for a physical device).
- **Auth header**: `Authorization: Bearer <accessToken>` — Flutter sends this for all protected calls.

## Endpoints Verified

| Flutter method              | Backend route                          | Method | Match |
|----------------------------|----------------------------------------|--------|--------|
| signUp                     | `/auth/signup`                         | POST   | ✅ |
| signIn                     | `/auth/signin`                         | POST   | ✅ |
| verifyEmail                | `/auth/verify-email`                   | POST   | ✅ |
| resendVerification         | `/auth/resend-verification`            | POST   | ✅ |
| getMe                      | `/auth/me`                             | GET    | ✅ |
| updateProfile              | `/auth/profile`                        | PATCH  | ✅ |
| getCompetitionsForMe       | `/competitions/for-me`                 | GET    | ✅ |
| getCompetitions            | `/competitions`                        | GET    | ✅ |
| getCompetitionById         | `/competitions/:id`                    | GET    | ✅ |
| joinCompetition            | `/competitions/:id/join`               | POST   | ✅ |
| createCompetition          | `/competitions`                        | POST   | ✅ |
| getNotifications          | `/notifications`                       | GET    | ✅ |
| markNotificationRead      | `/notifications/:id/read`              | PATCH  | ✅ |
| markAllNotificationsRead  | `/notifications/read-all`             | PATCH  | ✅ |

## Response shapes

- **Auth**: `{ user: { id, email, role, firstName, lastName, mainSpecialty? }, tokens: { accessToken, expiresIn } }` — Flutter `AuthResponse` / `AuthUser` / `AuthTokens` match.
- **Competitions list**: `{ data: Competition[], pagination: { page, limit, totalCount, totalPages, hasNext, hasPrev } }` — Flutter `CompetitionsResponse` / `Competition` (including `_count.participants`, `creator`, `specialty`) match.
- **Single competition**: Same `Competition` shape with `creator` and `_count` — Flutter `Competition.fromJson` handles it.
- **Notifications**: `{ data: Notification[], unreadCount }` — Flutter `NotificationsResponse` / `AppNotification` (with `competition` when included) match.
- **Errors**: `{ statusCode, message?, error? }` — Flutter `ApiError.fromJson` and `displayMessage` (including `message` as string or array) match.

## Summary

- All listed endpoints and methods match.
- Request/response shapes and query parameters match backend.
- Auth uses Bearer token; Flutter stores and sends it correctly.
- For Android emulator, set `baseUrl` to `http://10.0.2.2:3000` so the app can reach the backend.
