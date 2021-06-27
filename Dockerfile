ARG GO_VERSION=1.16.5
ARG ALPINE_VERSION=3.14.0

# STAGE 1: building the executable
FROM golang:${GO_VERSION}-alpine AS build
ENV CONFTEST_VERSION 0.25.0
RUN apk add --no-cache git
RUN apk --no-cache add ca-certificates
RUN go get -v github.com/open-policy-agent/conftest@v${CONFTEST_VERSION}

# STAGE 2: build the container to run
FROM alpine:${ALPINE_VERSION}
LABEL org.opencontainers.image.authors="koozz@linux.com"
COPY --from=build /go/bin/conftest /usr/bin/conftest
RUN apk add --no-cache jq curl
WORKDIR /
COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
