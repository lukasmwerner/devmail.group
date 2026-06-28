ARG ERLANG_VERSION=29
ARG GLEAM_VERSION=v1.17.0

# Gleam stage: run on the builder's native platform so Erlang/Gleam
# tooling is not executed through amd64 emulation on ARM machines.
FROM --platform=$BUILDPLATFORM ghcr.io/gleam-lang/gleam:${GLEAM_VERSION}-scratch AS gleam

# Build stage: also native to the builder. The generated Erlang shipment is
# BEAM bytecode and can be copied into the target-platform runtime image.
FROM --platform=$BUILDPLATFORM erlang:${ERLANG_VERSION} AS build
COPY --from=gleam /bin/gleam /bin/gleam
COPY . /app/
RUN cd /app && gleam export erlang-shipment

# Final stage: this is the requested target platform, e.g. linux/amd64.
FROM --platform=$TARGETPLATFORM erlang:${ERLANG_VERSION}-alpine
ARG GIT_SHA
ARG BUILD_TIME
ENV GIT_SHA=${GIT_SHA}
ENV BUILD_TIME=${BUILD_TIME}
#COPY healthcheck.sh /app/healthcheck.sh
#RUN \
#  chmod +x /app/healthcheck.sh \
#  && addgroup --system webapp \
#  && adduser --system webapp -g webapp
#USER webapp
COPY --from=build /app/build/erlang-shipment /app
COPY static /app/static
WORKDIR /app
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["run"]
