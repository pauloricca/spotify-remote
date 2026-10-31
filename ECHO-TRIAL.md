# Tune on Echo Show: trial notes

Source: https://github.com/fully-forged/tune (archived December 2022).

The intended setup is Silk showing Tune's controls and Spotify Connect
playing on the Echo's native Spotify integration or another available device.
Silk audio playback via Spotify's Web Playback SDK is unverified.

## Spotify setup

1. Sign into https://developer.spotify.com/dashboard with your Premium account.
2. Check for an existing application, or create a personal application using Web API.
3. For a test on this Mac, register this redirect URI exactly:
   `http://127.0.0.1:4000/auth/spotify/callback`.
4. Put its client ID and secret in `.env.local` (already ignored by Git).
   Copy `.env` as a starting point and generate fresh session secrets.
   Do not share the secret in chat or commit it.

Spotify no longer accepts `localhost` callbacks. A test from the Echo needs
an HTTPS address that the Echo can reach; the loopback URL above only works
on this Mac. Hosting is not configured by this trial.

## Local trial build

Docker is used to avoid installing the old Elixir/Erlang/Node toolchain on macOS.

```sh
docker compose up --build -d
docker compose exec tune mix test
docker compose down
```

Open `http://127.0.0.1:4000` on this Mac.

Source files are mounted for development. Dependencies, compiled output,
Node modules, and generated assets live in Docker volumes. Run all build,
development, and test commands through Docker; no host runtime is needed.

## Compatibility checks still needed

Tune predates Spotify's 2026 development-mode API changes. In particular:

- `/me` no longer returns `product`; the trial allows playback controls when
  that field is absent and lets Spotify enforce playback eligibility.
- Search requests now use a limit of at most 10 in the trial UI.
- Several recommendations and artist top-track endpoints have been removed.
- Playlist contents and some metadata fields have changed.

The original locked dependencies have reported security advisories. This
container is for a local evaluation, not a public deployment.

After adapting and verifying login, test search → artist → album → play,
selecting the Echo in the device chooser. Link Spotify in Alexa first and
start Spotify on the Echo if it is not appearing as an available device.

References:
- https://developer.spotify.com/documentation/web-api/tutorials/february-2026-migration-guide
- https://developer.spotify.com/documentation/web-api/concepts/redirect_uri
- https://support.spotify.com/us/article/spotify-on-alexa-devices/
