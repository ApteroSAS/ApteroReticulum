FROM elixir:1.10.2

#install node
RUN apt-get update
RUN apt remove cmdtest
RUN curl -sL https://deb.nodesource.com/setup_16.x | bash
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add
RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
RUN apt-get install -y nodejs nodejs-legacy
RUN node --version

#install inotify
RUN apt-get update -qq && apt-get install -y inotify-tools

#install yarn
RUN curl -so- -L https://yarnpkg.com/install.sh | bash
RUN $HOME/.yarn/bin/yarn -version

RUN mkdir /ret
COPY . /ret

WORKDIR	/ret
#COPY mix.exs /ret/mix.exs
#COPY mix.lock /ret/mix.lock
RUN mix local.hex --force
RUN mix local.rebar --force
#COPY . /ret

RUN mix deps.get
RUN cd assets && $HOME/.yarn/bin/yarn
RUN mix compile.phoenix
