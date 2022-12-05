FROM alpine/openssl as certr
WORKDIR certs
RUN openssl req -x509 -newkey rsa:2048 -sha256 -days 36500 -nodes -keyout key.pem -out cert.pem -subj '/CN=ret' && cp cert.pem cacert.pem

#FROM elixir:1.8-alpine as builder
FROM elixir:1.8-alpine
RUN apk add --no-cache nodejs yarn git build-base
RUN apk update && apk add --no-cache bash openssl-dev openssl jq libstdc++ coreutils
RUN apk update && apk add --no-cache inotify-tools
RUN mkdir -p /storage && chmod 777 /storage
WORKDIR ret
COPY --from=certr /certs .
COPY ./.elixir_ls ./.elixir_ls
COPY ./assets ./assets
COPY ./bin ./bin
COPY ./config ./config
COPY ./test ./test
COPY ./priv ./priv
COPY ./scripts ./scripts
COPY ./.formatter.exs ./.formatter.exs
COPY ./.tool-versions ./.tool-versions
COPY ./mix.exs ./mix.exs
COPY ./mix.lock ./mix.lock
COPY ./lib ./lib
COPY ./rel ./rel
COPY ./version.json ./version.json
COPY docker/config.toml .
RUN mix local.hex --force
RUN mix local.rebar --force
RUN mix deps.get
RUN mix deps.clean mime --build
RUN rm -rf _build
#Compile is very long around 200s
RUN mix compile
RUN MIX_ENV=prod mix distillery.release
#CMD exec /ret/bin/ret foreground
CMD mix ecto.create; mix ecto.migrations; mix phx.server
#DEBUG
#ENTRYPOINT ["tail", "-f", "/dev/null"]

#FROM alpine
#RUN mkdir -p /storage && chmod 777 /storage
#RUN apk update && apk add --no-cache bash openssl-dev openssl jq libstdc++ coreutils
#WORKDIR ret
#COPY --from=certr /certs .
#COPY --from=builder /_build/prod/rel/ret/ .
#COPY docker/config.toml .
#CMD exec /ret/bin/ret foreground
#DEBUG
#ENTRYPOINT ["tail", "-f", "/dev/null"]