FROM ruby:2.6.3

ENV APP_ENV "production"
ENV RACK_ENV "production"

WORKDIR /slacktionic

COPY Gemfile* ./

RUN bundle install

COPY . .

CMD ["puma"]
