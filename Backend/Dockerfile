FROM swift:6.0-jammy AS build
WORKDIR /build
COPY Shared ./Shared
COPY Backend/Package.swift Backend/Package.resolved* ./Backend/
WORKDIR /build/Backend
RUN swift package resolve
COPY Backend/Sources ./Sources
RUN mkdir -p Tests/AppTests && echo '@testable import App' > Tests/AppTests/Placeholder.swift
RUN swift build -c release --static-swift-stdlib && ls -la .build/release/App

FROM ubuntu:22.04
RUN apt-get update && apt-get install -y ca-certificates tzdata && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=build /build/Backend/.build/release/App .
ENV TZ=Europe/Berlin
EXPOSE 8080
ENTRYPOINT ["./App"]
CMD ["serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "8080"]
