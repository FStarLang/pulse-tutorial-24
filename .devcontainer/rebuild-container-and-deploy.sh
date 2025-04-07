#!/bin/bash

set -eux

# Note: this will the master branches of F*/karamel/pulse to create the container.
# It will not check that the files here build with that combination. You may also want to update
# the contents of tutorial/ to mimic share/pulse/examples/by-example/ in the Pulse repo.

# Cache off since we pull from upstream branches that change
docker build --no-cache -f .devcontainer/minimal.Dockerfile -t mtzguido/pulse-tutorial .

docker push mtzguido/pulse-tutorial
