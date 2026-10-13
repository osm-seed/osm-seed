FROM ubuntu:20.04
ENV workdir /mnt/data

RUN apt-get -y update
RUN DEBIAN_FRONTEND=noninteractive apt-get -y install  \
    build-essential \
    libboost-program-options-dev \
    libbz2-dev \
    zlib1g-dev \
    libexpat1-dev \
    cmake \
    pandoc \
    git \
    python3 \
    python3-pip \
    curl \
    unzip \
    wget \
    software-properties-common \
    libz-dev \
    gdal-bin \
    tar \
    bzip2 \
    clang \
    default-jre \
    default-jdk \
    gradle \
    apt-utils \
    postgresql-client \
    libgeos-dev \
    sqlite3 \
    spatialite-bin


#Install osmium-tool
RUN apt-get -y install \
    libbz2-dev \
    libgd-dev \
    libprotozero-dev \
    libsqlite3-dev \
    make \
    jq \
    ca-certificates \
    liblz4-dev

WORKDIR /home
RUN git clone https://github.com/osmcode/libosmium.git
RUN cd libosmium && git checkout v2.18.0
RUN cd libosmium && mkdir build
WORKDIR /home/libosmium/build
RUN cmake ..
RUN make ..

# Other useful packages
RUN apt-get install -y \
    rsync \
    tmux \
    zsh \
    libgdal-dev

WORKDIR /home
RUN echo 'hello'
RUN git clone https://github.com/osmcode/osmcoastline.git
RUN cd osmcoastline && git checkout v2.3.1 && mkdir build
WORKDIR /home/osmcoastline/build
RUN cmake ..
RUN make
RUN ln -s "$PWD"/src/osmcoastline /usr/local/bin/osmcoastline
RUN osmcoastline --version
# # Install AWS CLI
# RUN pip install awscli

# # Install GCP CLI
# RUN curl -sSL https://sdk.cloud.google.com | bash
# RUN ln -f -s /root/google-cloud-sdk/bin/gsutil /usr/bin/gsutil

# # Install Azure CLI
# RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash

VOLUME $workdir
WORKDIR $workdir
COPY start.sh /start.sh
RUN chmod +x /start.sh
CMD /start.sh
