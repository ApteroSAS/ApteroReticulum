FROM elixir:1.10.1
RUN apt-get update
RUN apt remove cmdtest
RUN curl -sL https://deb.nodesource.com/setup_10.x | bash
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add
RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
RUN apt-get update
RUN apt-get install -y inotify-tools nodejs
RUN node --version
RUN apt-get install -y apt-transport-https ca-certificates
RUN apt-get -y install yarn
RUN yarn --version
#RUN curl -so- -L https://yarnpkg.com/install.sh | bash
RUN mkdir /ret
COPY . /ret
WORKDIR	/ret
RUN mix local.hex --force
RUN mix local.rebar --force
RUN mix deps.get
RUN cd assets && yarn
RUN mix compile.phoenix
