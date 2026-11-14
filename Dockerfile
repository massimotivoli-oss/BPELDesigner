# Photon/SWT is x86_64. Compose also fixes the platform on Apple Silicon.
FROM eclipse-temurin:8u472-b08-jdk-jammy@sha256:be68e89be2b331109acb666b38ecb3e6a5445041befdfa66db54ee78c9a661e6 AS base
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl python3 unzip && rm -rf /var/lib/apt/lists/*
COPY docker/install-server.sh /opt/tools/install-server.sh
RUN bash /opt/tools/install-server.sh
ENV CATALINA_HOME=/opt/tomcat PATH=/opt/maven/bin:/opt/tomcat/bin:$PATH

FROM base AS service-build
WORKDIR /build
COPY services/pom.xml ./pom.xml
RUN mvn -B dependency:go-offline
COPY services/src ./src
RUN mvn -B package

FROM base AS participants
COPY --from=service-build /build/target/participants.war /opt/tomcat/webapps/participants.war
COPY docker/configure-tomcat.py /opt/tools/
RUN python3 /opt/tools/configure-tomcat.py 8081
EXPOSE 8081
CMD ["catalina.sh", "run"]

FROM base AS ode
COPY docker/install-ode.py docker/deploy.py docker/configure-tomcat.py /opt/tools/
RUN python3 /opt/tools/install-ode.py && python3 /opt/tools/configure-tomcat.py 8080
COPY docker/ode-entrypoint.sh /opt/tools/
EXPOSE 8080
ENTRYPOINT ["bash", "/opt/tools/ode-entrypoint.sh"]

FROM base AS test
COPY docker/integration.py /opt/tools/
CMD ["python3", "/opt/tools/integration.py"]

FROM base AS ide
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgtk-3-0 libxtst6 libxi6 libxrender1 libasound2 libnss3 libgbm1 \
    xvfb x11vnc fluxbox novnc websockify supervisor x11-utils \
    fonts-dejavu dbus-x11 python3-pil gosu xterm git && rm -rf /var/lib/apt/lists/*
COPY scripts/setup-eclipse.sh scripts/env.sh /opt/installer/scripts/
# Reuse the checksum-verified Photon download and exact p2 feature versions.
RUN bash /opt/installer/scripts/setup-eclipse.sh && \
    mv /opt/installer/.ide/eclipse /opt/eclipse && rm -rf /opt/installer
COPY docker/patch-eclipse.py /opt/tools/
RUN python3 /opt/tools/patch-eclipse.py /opt/eclipse
COPY docker/eclipse-startup /tmp/eclipse-startup
RUN mkdir -p /tmp/eclipse-startup/classes && \
    javac -encoding UTF-8 -cp '/opt/eclipse/plugins/*' \
      -d /tmp/eclipse-startup/classes /tmp/eclipse-startup/src/it/bpeldesigner/Startup.java && \
    mkdir -p /opt/eclipse/dropins && \
    jar cfm /opt/eclipse/dropins/it.bpeldesigner.startup_1.0.0.jar \
      /tmp/eclipse-startup/META-INF/MANIFEST.MF \
      -C /tmp/eclipse-startup/classes . -C /tmp/eclipse-startup plugin.xml && \
    rm -rf /tmp/eclipse-startup
RUN useradd --create-home --uid 1000 developer && mkdir -p /workspace && \
    chown -R developer:developer /workspace /opt/eclipse
COPY docker/supervisord.conf /etc/supervisor/conf.d/desktop.conf
COPY docker/desktop-entrypoint.sh docker/ide-health.py docker/screenshot.py /opt/tools/
ENV DISPLAY=:0 HOME=/home/developer SWT_GTK3=0 NO_AT_BRIDGE=1
# Photon also needs GTK2 when SWT_GTK3=0.
RUN apt-get update && apt-get install -y --no-install-recommends libgtk2.0-0 && \
    rm -rf /var/lib/apt/lists/*
EXPOSE 6080
ENTRYPOINT ["bash", "/opt/tools/desktop-entrypoint.sh"]
