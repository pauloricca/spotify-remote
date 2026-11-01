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

## Runtime and Spotify reliability

The production Dockerfile builds a self-contained OTP release and copies only
that release into Debian slim. Node, Mix, compilers, dependency sources, and npm
packages stay in the build stage. The runtime runs as `nobody`; environment
variables are loaded when the release starts, and port 4000 remains unchanged.

Each user has one GenServer that serializes token refresh and commands. Read
results are cached for up to 30 seconds (two seconds for the queue) (at most 100 entries per user); successful
mutations clear that cache. Playback polls every 10 seconds and devices every
60 seconds while a browser is subscribed. Sessions without subscribers expire
after 30 seconds. Network errors back off up to five minutes. Commands are not
replayed after network or server errors because Spotify may have applied them.
A 401 refreshes the token once and retries the rejected operation once.

All backend Spotify HTTP calls pass through one app-wide request gate. A 429
pauses all users and endpoints for Spotify's `Retry-After` interval. If no valid
interval is provided, ordinary rate limits pause for 60 seconds and
`QUOTA_EXCEEDED` pauses for one hour. The gate applies to this app instance;
cooldowns and caches live in memory and reset when it restarts. Do not scale to
multiple instances without sharing that gate. Requests that spend over ten
seconds waiting at the gate are discarded before sending.

Quota exhaustion requires Spotify's quota to reset or an app quota change;
reconnecting or adding RAM cannot bypass it. During a temporary authentication
failure the existing page shell stays available and loads the requested page
when the session recovers. Invalid refresh credentials return the user to login.

Run the regression suite with `MIX_ENV=test mix test`. Build and smoke test the
release with `docker build -t spotify-remote:local .` and runtime environment
variables as listed above. No deployment is performed by these commands.
