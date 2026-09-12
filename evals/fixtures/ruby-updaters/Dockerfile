FROM registry.access.redhat.com/ubi9/ruby-33:1-20
COPY . /opt/app-root/src
RUN bundle install
CMD ["bundle", "exec", "puma"]
