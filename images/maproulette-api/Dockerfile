# MapRoulette backend (Scala/Play). Based on https://github.com/maproulette/maproulette2-docker
ARG TEMURIN_JDK_TAG=17
FROM eclipse-temurin:${TEMURIN_JDK_TAG} AS builder

ARG SBT_VERSION=1.9.9
ARG GIT=maproulette/maproulette-backend
ARG VERSION=v4.13.0

RUN curl -L -o sbt.deb https://repo.scala-sbt.org/scalasbt/debian/sbt-${SBT_VERSION}.deb \
    && dpkg -i sbt.deb \
    && rm sbt.deb \
    && apt-get update \
    && apt-get install --no-install-recommends -y git sbt unzip \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 --branch ${VERSION} https://github.com/${GIT}.git /maproulette-api
WORKDIR /maproulette-api
RUN sbt clean compile dist \
    && unzip -d / target/universal/MapRouletteAPI.zip

FROM eclipse-temurin:${TEMURIN_JDK_TAG}

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get upgrade -y \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd -g 1001 maproulette \
    && useradd --uid 1001 --gid 1001 --groups 0 --create-home --home-dir /MapRouletteAPI maproulette \
    && chmod 0775 /MapRouletteAPI

COPY --from=builder --chown=1001:0 /MapRouletteAPI /MapRouletteAPI
COPY --chown=1001:0 application-overrides.conf /MapRouletteAPI/conf/application-overrides.conf
COPY --chown=1001:0 start.sh /MapRouletteAPI/start.sh

USER maproulette
WORKDIR /MapRouletteAPI
EXPOSE 9000
ENTRYPOINT ["./start.sh"]
