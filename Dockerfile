FROM quay.io/quarkus/ubi-quarkus-graalvmce-builder-image:jdk-21@sha256:5f2a1c5004b1fd7996d8a04c8e8798db57827fbd92629690ec6a7ffe319993ac AS build

ENV LANGUAGE='en_US:en'

WORKDIR /code/quarkus-gs

COPY --chown=quarkus:quarkus pom.xml .
# Maven wrapper files
COPY --chown=quarkus:quarkus ./mvnw .
COPY --chown=quarkus:quarkus .mvn ./.mvn
COPY --chown=quarkus:quarkus src ./src

# create cache dir if not exist and fix permissions
RUN mkdir -p /tmp/.buildx-cachee
RUN chown -R quarkus:quarkus /tmp/.buildx-cachee

USER quarkus

RUN \
  --mount=type=cache,target=/tmp/.buildx-cachee,sharing=locked \
  ls -la /tmp/.buildx-cachee

RUN \
  --mount=type=cache,target=/tmp/.buildx-cachee,sharing=locked \
  ["./mvnw", "verify", "clean", "-Dmaven.repo.local=/tmp/.buildx-cachee", "--fail-never"]

RUN \
  --mount=type=cache,target=/tmp/.buildx-cachee,sharing=locked \
  ./mvnw -f pom.xml -B package -Dmaven.repo.local=/tmp/.buildx-cachee -Dmaven.test.skip=true

FROM registry.access.redhat.com/ubi8/openjdk-21-runtime:1.20-2@sha256:6a3242526aebd99245eee76feb55c0b9a10325cddfc9530b24c096064a5ed81e
COPY --from=build /code/quarkus-gs/target/quarkus-app/lib/ /deployments/lib/
COPY --from=build /code/quarkus-gs/target/quarkus-app/*.jar /deployments/
COPY --from=build /code/quarkus-gs/target/quarkus-app/app/ /deployments/app/
COPY --from=build /code/quarkus-gs/target/quarkus-app/quarkus/ /deployments/quarkus/

EXPOSE 8080
USER 185
ENV JAVA_OPTS_APPEND="-Dquarkus.http.host=0.0.0.0 -Djava.util.logging.manager=org.jboss.logmanager.LogManager"
ENV JAVA_APP_JAR="/deployments/quarkus-run.jar"

ENTRYPOINT [ "/opt/jboss/container/java/run/run-java.sh" ]

