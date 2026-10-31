FROM node:14-bullseye AS node
FROM elixir:1.12
COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm
WORKDIR /app
ENV MIX_ENV=prod PORT=4000
RUN mix local.hex --force && mix local.rebar --force
COPY mix.exs mix.lock ./
COPY config config
RUN mix deps.get
RUN mix deps.compile
COPY . .
RUN mix compile
# Use Dart Sass instead of the archived native node-sass binary.
RUN npm ci --prefix assets --ignore-scripts \
    && npm install --prefix assets --no-save --ignore-scripts sass@1.32.13 \
    && npm run deploy --prefix assets
RUN mix phx.digest
EXPOSE 4000
CMD ["mix", "phx.server"]
