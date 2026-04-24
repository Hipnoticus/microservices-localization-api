FROM ruby:3.3-alpine AS build
RUN apk add --no-cache build-base
WORKDIR /app
COPY Gemfile Gemfile.lock* ./
RUN bundle install --without development test --jobs 4

FROM ruby:3.3-alpine
RUN apk add --no-cache libstdc++
WORKDIR /app
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY . .
EXPOSE 3003
ENV RACK_ENV=production
CMD ["bundle", "exec", "puma", "-p", "3003", "-e", "production"]
