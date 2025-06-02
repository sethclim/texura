FROM golang:tip-alpine3.22 AS builder

WORKDIR /src

COPY . .

RUN go build -o texura_api.exe .

FROM golang:tip-alpine3.22 AS runtime

WORKDIR /app

COPY --from=builder /src/texura_api.exe /app/texura_api.exe

ENTRYPOINT [ "/app/texura_api.exe" ]
