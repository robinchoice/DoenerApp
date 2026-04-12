FROM swift:6.0-jammy AS build
WORKDIR /build
COPY Shared ./Shared
COPY Backend ./Backend
WORKDIR /build/Backend
RUN swift package resolve
RUN swift build -c release --static-swift-stdlib

FROM ubuntu:22.04
RUN apt-get update && apt-get install -y ca-certificates tzdata && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=build /build/Backend/.build/release/App .
ENV TZ=Europe/Berlin
EXPOSE 8080
ENTRYPOINT ["./App"]
CMD ["serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "8080"]
