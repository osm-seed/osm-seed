FROM ruby:3.4
WORKDIR /app
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl unzip \
    && rm -rf /var/lib/apt/lists/*
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip" -o "awscliv2.zip" \
    && unzip -q awscliv2.zip \
    && ./aws/install \
    && rm -rf awscliv2.zip aws
# TODO: Install Google Cloud Platform (GCP) and Azure CLI for better data management
# libxml-ruby 6 removed "xml/libxml", which the script requires
RUN gem install bigdecimal pg \
    && gem install libxml-ruby -v 5.0.5
COPY replicate_changesets.rb start.sh ./
RUN chmod +x replicate_changesets.rb start.sh
CMD /app/start.sh
