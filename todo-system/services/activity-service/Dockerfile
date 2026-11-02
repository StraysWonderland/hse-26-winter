# Optimised build: multi-stage, dependency cache mount, Spring Boot layered extraction,
# small JRE base, non-root user, exec-form ENTRYPOINT (java is PID 1 and receives SIGTERM).

FROM gradle:9.4-jdk21 AS build
ENV GRADLE_USER_HOME=/gradle-home
WORKDIR /workspace
# Build scripts change rarely, sources often: copy in that order.
COPY settings.gradle.kts build.gradle.kts ./
COPY src ./src
# Cache mount: downloaded dependencies survive between builds, but are not part of any image layer.
RUN --mount=type=cache,target=/gradle-home \
    gradle bootJar --no-daemon --quiet
RUN java -Djarmode=tools -jar build/libs/application.jar extract --layers --destination /extracted

FROM eclipse-temurin:21-jre-alpine
ARG APP_VERSION=dev
LABEL org.opencontainers.image.title="activity-service" \
      org.opencontainers.image.description="TODO system: activity feed, consumes todo events (Spring Boot)" \
      org.opencontainers.image.version="${APP_VERSION}"
RUN addgroup -S -g 10001 app && adduser -S -D -u 10001 -G app app
WORKDIR /app
# Least to most frequently changing -> unchanged layers are reused and not re-pushed.
COPY --from=build /extracted/dependencies/ ./
COPY --from=build /extracted/spring-boot-loader/ ./
COPY --from=build /extracted/snapshot-dependencies/ ./
COPY --from=build /extracted/application/ ./
ENV APP_VERSION=${APP_VERSION} \
    PORT=8080 \
    JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=75"
USER 10001
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "application.jar"]
