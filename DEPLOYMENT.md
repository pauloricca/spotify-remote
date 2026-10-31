# Faffless deployment

Production URL: https://spotify.ricca.uk

Build `Dockerfile` and route HTTP to container port 4000. No persistent volumes are needed.

Configure these runtime environment variables in Coolify before starting:

- `SPOTIFY_CLIENT_ID`
- `SPOTIFY_CLIENT_SECRET`
- `SECRET_KEY_BASE` (a stable random secret of at least 64 bytes)
- `SESSION_ENCRYPTION_SALT` (a stable random salt)
- `ADMIN_USER`
- `ADMIN_PASSWORD`

Register `https://spotify.ricca.uk/auth/spotify/callback` as a redirect URI in the Spotify application settings.

Keep secrets out of Git and Docker build arguments. Session credentials live in encrypted browser cookies and server memory. Keep the cookie encryption secrets stable across redeployments.

Search indexing is discouraged through an X-Robots-Tag header, HTML robots metadata, and robots.txt. The app is also excluded from the Faffless public directory. These directives do not restrict access.
