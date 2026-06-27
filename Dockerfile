FROM ghcr.io/prefix-dev/pixi:0.71.0 AS build

# copy source code, pixi.toml and pixi.lock to the container
WORKDIR /app
COPY . .
# install dependencies to `/app/.pixi/envs/prod`
# use `--locked` to ensure the lock file is up to date with pixi.toml
RUN apt-get update
RUN apt-get install -y git
RUN apt-get clean
RUN pixi config set --local run-post-link-scripts insecure
RUN pixi install --locked 
# create the shell-hook bash script to activate the environment
RUN pixi shell-hook -s bash > /shell-hook
RUN echo "#!/bin/bash" > /app/entrypoint.sh
RUN cat /shell-hook >> /app/entrypoint.sh
# extend the shell-hook script to run the command passed to the container
RUN echo 'exec "$@"' >> /app/entrypoint.sh

FROM ubuntu:24.04 AS production
WORKDIR /app
# only copy the production environment into prod container
# please note that the "prefix" (path) needs to stay the same as in the build container
COPY --from=build /app/.pixi/envs/default /app/.pixi/envs/default
COPY --from=build --chmod=0755 /app/entrypoint.sh /app/entrypoint.sh

#copy code into containeir
COPY . /app/

ENTRYPOINT [ "/app/entrypoint.sh" ]
ENTRYPOINT  [ "/app/run.sh" ]

