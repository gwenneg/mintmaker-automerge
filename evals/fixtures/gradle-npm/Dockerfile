FROM quay.io/example/jdk-builder:latest AS build
COPY . /src
WORKDIR /src
RUN ./gradlew bootJar

FROM registry.access.redhat.com/ubi9/openjdk-21-runtime:1.20
COPY --from=build /src/build/libs/app.jar /deployments/app.jar
