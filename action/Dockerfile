FROM ruby:3.0

# Install the gh cli (TODO: make the action comment on the PR)
# RUN apt-get update && apt-get install -y software-properties-common && \
#     apt-add-repository https://cli.github.com/packages && \
#     apt-get update && \
#     apt-get install -y gh

# Set the working directory in the container
WORKDIR /app

# Copy over your application
COPY Gemfile Gemfile.lock /app

# Install Ruby dependencies
RUN gem install bundler -v 2.4.10 && bundle install

COPY Makefile scripts main.rb lib /app/

# Copies your code file from your action repository to the filesystem path `/` of the container
COPY entrypoint.sh /entrypoint.sh

# Executes `entrypoint.sh` when the Docker container starts up
ENTRYPOINT ["/entrypoint.sh"]
