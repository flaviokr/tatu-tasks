FROM ruby:2.6.3

WORKDIR /slacktionic

COPY Gemfile .

RUN bundle install

COPY . .

CMD ["puma"]
