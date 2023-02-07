FROM ruby:3.1

RUN apt-get update -qq && apt-get install -y build-essential sqlite3 libsqlite3-dev

ENV HMD_PROD_DB hmd.production.sqlite3
ENV HMD_PASS_SALT your-salt-here-please-change-it!

RUN mkdir help-me-decide

ADD . help-me-decide/
RUN cd help-me-decide/rest && bundle install

EXPOSE 9991
WORKDIR help-me-decide/rest

