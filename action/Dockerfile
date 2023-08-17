FROM ruby:3.0

# Install the gh cli (TODO: make the action comment on the PR)
# RUN apt-get update && apt-get install -y software-properties-common && \
#     apt-add-repository https://cli.github.com/packages && \
#     apt-get update && \
#     apt-get install -y gh

# Do not: Set the working directory in the container
# per https://docs.github.com/en/actions/creating-actions/dockerfile-support-for-github-actions#workdir
# WORKDIR /linkchecker

# Copy over your application
COPY Gemfile Gemfile.lock /link-checker

# Install Ruby dependencies
RUN gem install bundler -v 2.4.10 && bundle install

COPY Makefile scripts main.rb lib /opt/link-checker/

# Copies your code file from your action repository to the filesystem path `/` of the container
COPY entrypoint.sh /entrypoint.sh

# Executes `entrypoint.sh` when the Docker container starts up
ENTRYPOINT ["/entrypoint.sh"]
