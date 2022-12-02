FROM alpine/openssl as certr
WORKDIR certs
RUN openssl req -x509 -newkey rsa:2048 -sha256 -days 36500 -nodes -keyout key.pem -out cert.pem -subj '/CN=ret' && cp cert.pem cacert.pem

FROM elixir:1.8-alpine as builder
RUN apk add --no-cache nodejs yarn git build-base
COPY . .
RUN mix local.hex --force
RUN mix local.rebar --force
RUN mix deps.get
RUN mix deps.clean mime --build
RUN rm -rf _build
#Compile is very long around 200s
RUN mix compile
RUN MIX_ENV=prod mix distillery.release

FROM alpine
RUN mkdir -p /storage && chmod 777 /storage
RUN apk update && apk add --no-cache bash openssl-dev openssl jq libstdc++ coreutils
WORKDIR ret
COPY --from=certr /certs .
COPY --from=builder /_build/turkey/rel/ret/ .
COPY scripts/docker/run.sh /run.sh
CMD exec /ret/bin/ret foreground

FROM elixir:1.8-alpine
RUN apk add --no-cache nodejs yarn git build-base
RUN apk update && apk add --no-cache bash openssl-dev openssl jq libstdc++ coreutils
RUN mkdir -p /storage && chmod 777 /storage
COPY . .
RUN mix local.hex --force
RUN mix local.rebar --force
RUN mix deps.get
RUN mix deps.clean mime --build
RUN rm -rf _build
#Compile is very long around 200s
RUN mix compile
COPY --from=certr /certs ./ret/
RUN MIX_ENV=prod mix distillery.release
RUN cp -a _build/prod/rel/ret/ .
WORKDIR ret
CMD exec /ret/bin/ret foreground
#CMD mix ecto.create; mix ecto.migrations; mix phx.server