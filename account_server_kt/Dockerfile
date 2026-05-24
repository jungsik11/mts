FROM ghcr.io/graalvm/native-image-community:17-ol9 AS build
WORKDIR /app

RUN microdnf install -y unzip findutils ca-certificates && microdnf update -y ca-certificates && \
    curl -L -o gradle.zip https://services.gradle.org/distributions/gradle-8.4-bin.zip && \
    unzip gradle.zip && \
    mv gradle-8.4 /opt/gradle && \
    rm gradle.zip
ENV PATH=$PATH:/opt/gradle/bin

COPY . .
RUN gradle nativeCompile -Pagent --no-daemon

FROM ubuntu:22.04
WORKDIR /app
COPY --from=build /app/build/native/nativeCompile/app ./app
EXPOSE 8000
ENTRYPOINT ["./app"]
