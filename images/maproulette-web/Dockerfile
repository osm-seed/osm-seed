# MapRoulette frontend. Based on https://github.com/maproulette/maproulette2-docker
# URLs are built as placeholders and replaced at container start (see 40-maproulette-env.sh),
# so the same image works for any osm-seed deployment.
FROM node:22-bookworm AS builder

ARG GIT=maproulette/maproulette-frontend
ARG VERSION=v3.18.8

# jq is used by "npm run build-env" to write public/env.json
RUN apt-get update \
    && apt-get install --no-install-recommends -y jq \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 --branch ${VERSION} https://github.com/${GIT}.git /maproulette-frontend
WORKDIR /maproulette-frontend

COPY env.production .env.local
RUN echo '[]' > src/customLayers.json

# On the OAuth return page (?code=...), the first whoami gets 401 and calls /auth/signout.
# That signout can land after /auth/callback and clear the new session. Skip it on that page.
RUN sed -i 's|^          dispatch(logoutUser());|          if (!new URLSearchParams(window.location.search).has("code")) dispatch(logoutUser());|' src/services/User/User.js \
    && grep -q 'has("code")) dispatch(logoutUser())' src/services/User/User.js

ENV NODE_OPTIONS="--max-old-space-size=8192"
RUN npm install && npm run build

FROM nginx:1.27-alpine

COPY --from=builder /maproulette-frontend/dist /var/www/maproulette
COPY nginx.conf /etc/nginx/templates/default.conf.template
COPY 40-maproulette-env.sh /docker-entrypoint.d/40-maproulette-env.sh
RUN chmod +x /docker-entrypoint.d/40-maproulette-env.sh

ENV MR_API_URL=http://localhost:9000
EXPOSE 80
