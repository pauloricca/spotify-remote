FROM node:14-bullseye AS node
FROM elixir:1.12 AS build
COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm
WORKDIR /app
ENV MIX_ENV=prod
RUN mix local.hex --force && mix local.rebar --force
COPY mix.exs mix.lock ./
COPY config config
RUN mix deps.get --only prod && mix deps.compile
COPY lib lib
COPY priv priv
COPY assets assets
RUN mix compile
RUN npm ci --prefix assets --ignore-scripts \
    && npm install --prefix assets --no-save --ignore-scripts sass@1.32.13 \
    && npm run deploy --prefix assets
RUN mix phx.digest && mix release

FROM debian:bullseye-slim AS runtime
COPY --from=build /etc/ssl/certs /etc/ssl/certs
RUN sed -i 's|http://|https://|g' /etc/apt/sources.list \
    && apt-get update && apt-get install -y --no-install-recommends \
    libssl1.1 libstdc++6 libncurses6 \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
ENV HOME=/app PORT=4000 LANG=C.UTF-8 LC_ALL=C.UTF-8
COPY --from=build --chown=nobody:nogroup /app/_build/prod/rel/tune ./
USER nobody
EXPOSE 4000
CMD ["bin/tune", "start"]
