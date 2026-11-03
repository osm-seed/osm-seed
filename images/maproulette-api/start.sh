#!/bin/bash
set -e

# The Play process writes RUNNING_PID, remove it in case of a restart.
rm -f RUNNING_PID

# conf/application-overrides.conf can be replaced at runtime (e.g. a ConfigMap mount).
# JAVA_OPTS is read by the start script (e.g. -Xmx2g).
exec /MapRouletteAPI/bin/maprouletteapi \
  -Dhttp.port=9000 \
  -Dconfig.resource=application-overrides.conf
