FROM registry.opensuse.org/opensuse/leap:15.3
ARG CONTAINER_USERID=1000

# Add needed repos
RUN echo 'solver.allowVendorChange = true' >> /etc/zypp/zypp.conf; \
    zypper ar -f https://download.opensuse.org/repositories/openSUSE:/infrastructure:/dale/15.3/openSUSE:infrastructure:dale.repo; \
    zypper ar -f https://download.opensuse.org/repositories/devel:/languages:/ruby/openSUSE_Leap_15.3/devel:languages:ruby.repo; \
    zypper --gpg-auto-import-keys refresh

# Install requirements
RUN zypper -n install --no-recommends --replacefiles \
  curl vim vim-data psmisc timezone ack glibc-locale sudo hostname \
  sphinx libxml2-devel libxslt-devel sqlite3-devel nodejs8 gcc-c++ \
  ImageMagick libmariadb-devel ruby3.1-devel make git-core mariadb-client; \
  zypper -n clean --all

# Add our user
RUN useradd -m frontend

# Configure our user
RUN usermod -u $CONTAINER_USERID frontend

# Setup sudo
RUN echo 'frontend ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers

# Disable versioned gem binary names
RUN echo 'install: --no-format-executable' >> /etc/gemrc

# We copy the Gemfiles into this intermediate build stage so it's checksum
# changes and all the subsequent stages (a.k.a. the bundle install call below)
# have to be rebuild. Otherwise, after the first build of this image,
# docker would use it's cache for this and the following stages.
ADD Gemfile /hackweek/Gemfile
ADD Gemfile.lock /hackweek/Gemfile.lock
RUN chown -R frontend /hackweek

# Install bundler
RUN gem.ruby3.1 install bundler -v "$(grep -A 1 "BUNDLED WITH" /hackweek/Gemfile.lock | tail -n 1)"; \
    gem.ruby3.1 install foreman

# Setup Ruby 3.1 as default
RUN ln -sf /usr/bin/ruby.ruby3.1 /home/frontend/bin/ruby; \
    ln -sf /usr/bin/gem.ruby3.1 /home/frontend/bin/gem; \
    ln -sf /usr/bin/bundle.ruby3.1 /home/frontend/bin/bundle; \
    ln -sf /usr/bin/rake.ruby3.1 /home/frontend/bin/rake

WORKDIR /hackweek
USER frontend

# Refresh our bundle
RUN export NOKOGIRI_USE_SYSTEM_LIBRARIES=1; bundle install --jobs=3 --retry=3

# Run our command
CMD ["/bin/bash", "-l"]

