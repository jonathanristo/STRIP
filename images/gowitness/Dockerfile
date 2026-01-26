FROM golang:1.23-alpine AS builder

WORKDIR /build
RUN apk add --no-cache git make
RUN git clone https://github.com/sensepost/gowitness.git .
RUN go build -o gowitness .

FROM alpine:latest
RUN apk add --no-cache chromium dumb-init
COPY --from=builder /build/gowitness /usr/local/bin/gowitness

ENV CHROME_BIN=/usr/bin/chromium-browser
ENV CHROME_PATH=/usr/lib/chromium/

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["gowitness"]
