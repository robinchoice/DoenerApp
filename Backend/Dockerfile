FROM swift:6.0-jammy AS build
WORKDIR /app
COPY ../Shared /shared
COPY Backend/Package.swift Backend/Package.resolved* ./
RUN swift package resolve
COPY Backend/Sources ./Sources
COPY Backend/Tests ./Tests
RUN swift build -c release --static-swift-stdlib

FROM ubuntu:22.04
RUN apt-get update && apt-get install -y ca-certificates tzdata && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=build /app/.build/release/App .
ENV TZ=Europe/Berlin
EXPOSE 8080
ENTRYPOINT ["./App"]
CMD ["serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "8080"]
