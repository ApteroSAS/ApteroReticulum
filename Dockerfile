FROM elixir:1.10.2
RUN apt-get update -qq && apt-get install -y inotify-tools
RUN curl -so- -L https://yarnpkg.com/install.sh | bash
RUN mkdir /ret
COPY . /ret

WORKDIR	/ret
#COPY mix.exs /ret/mix.exs
#COPY mix.lock /ret/mix.lock
RUN mix local.hex --force
RUN mix local.rebar --force
#COPY . /ret

RUN mix deps.get
RUN cd assets && yarn
RUN mix compile.phoenix
