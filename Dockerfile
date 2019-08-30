FROM ruby:2.6.3

ENV APP_ENV "production"
ENV RACK_ENV "production"

WORKDIR /tatu-tasks

COPY Gemfile* ./

RUN bundle install

COPY . .

CMD ["puma"]
