FROM golang:1.21-alpine AS builder

WORKDIR /app
COPY main.go go.mod* go.sum* ./
RUN go mod init poc-app || true
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o poc-app main.go

FROM alpine:3.18

RUN apk --no-cache add ca-certificates
WORKDIR /root/

COPY --from=builder /app/poc-app .

ARG VERSION=v1.0.0
ENV APP_VERSION=$VERSION

EXPOSE 8080
CMD ["./poc-app"]