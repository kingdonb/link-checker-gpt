FROM ruby:3.0

# Install the gh cli (TODO: make the action comment on the PR)
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
      && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
      && echo 'deb [signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main' | tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
    apt-get update && \
    apt-get install -y gh

# Do not: Set the working directory in the container
# per https://docs.github.com/en/actions/creating-actions/dockerfile-support-for-github-actions#workdir
# WORKDIR /linkchecker

# Copy over your application
WORKDIR /opt/link-checker
COPY Gemfile Gemfile.lock /opt/link-checker

# Install Ruby dependencies
RUN gem install bundler -v 2.4.10 && bundle install

COPY . /opt/link-checker/

# Copies your code file from your action repository to the filesystem path `/` of the container
# COPY entrypoint.sh /entrypoint.sh

# Executes `entrypoint.sh` when the Docker container starts up
ENTRYPOINT ["/opt/link-checker/entrypoint.sh"]
