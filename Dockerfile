FROM alpine:latest

ENV SPAM_WAIT_MILLISECONDS=1000

RUN apk add coreutils util-linux

RUN mkdir -p /app

COPY audit_log_spammer.sh /app

ENTRYPOINT [ "sh", "/app/audit_log_spammer.sh" ]
