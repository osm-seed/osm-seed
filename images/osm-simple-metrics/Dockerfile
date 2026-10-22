FROM node:24.22.1

# Create app directory
WORKDIR /usr/src/app

# Clone
RUN git clone https://github.com/developmentseed/osm-simple-metrics.git ./

RUN npm install && npm link
COPY start.sh /
CMD /start.sh
