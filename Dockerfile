FROM tomcat:8.5.82-jdk8
LABEL maintainer="biomodels-developers@ebi.ac.uk"

ARG UID=1000
ARG USERNAME=tomcat
ARG GID=1000
ARG GROUP=tomcat

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    net-tools vim \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

ENV datacentre="local"
ENV HOME=/home/$USERNAME
RUN mkdir -p $HOME
RUN addgroup --gid "$GID" "$GROUP" \
   && adduser \
   --uid "$UID" \
   --disabled-password \
   --gecos "" \
   --ingroup "$GROUP" \
   --no-create-home \
   "$USERNAME"; \
   chown -R $USERNAME:$GROUP $HOME

ENV JAVA_OPTS_1="-Xms512m -Xmx1g -XX:MaxMetaspaceSize=512m"
ENV JAVA_OPTS_2="-XX:+UseConcMarkSweepGC -XX:+UseParNewGC -XX:MaxJavaStackTraceDepth=100"
ENV JAVA_OPTS_3="-XX:+HeapDumpOnOutOfMemoryError"
ENV JAVA_OPTS="$JAVA_OPTS_1 $JAVA_OPTS_2 $JAVA_OPTS_3 -server -noverify -Djava.net.preferIPv4Stack=true"

EXPOSE 8080

# Build context is the project root (biomodels-converters/)
COPY sbfc-webapp-k8s/tomcat-users.xml /usr/local/tomcat/conf/
COPY sbfc-webapp-k8s/context.xml /usr/local/tomcat/temp/
COPY sbfc-webapp-k8s/sbfcOnline.war sbfc-converters-aws-ec2/biomodels#tools#converters-local.xml /usr/local/tomcat/temp/
COPY sbfc-converters-aws-ec2/sbfConverterOnline.sh /data/converters/sbfc/sbfConverterOnline.sh

RUN rm -rf /usr/local/tomcat/webapps; \
    mv /usr/local/tomcat/webapps.dist /usr/local/tomcat/webapps; \
    cp /usr/local/tomcat/temp/context.xml /usr/local/tomcat/webapps/manager/META-INF/context.xml; \
    mkdir -p /usr/local/tomcat/conf/Catalina/localhost; \
    cp /usr/local/tomcat/temp/biomodels#tools#converters-local.xml /usr/local/tomcat/conf/Catalina/localhost/tools#converters.xml; \
    mkdir /usr/local/tomcat/deploy; \
    cp /usr/local/tomcat/temp/biomodels#tools#converters-local.xml /usr/local/tomcat/deploy/tools#converters.xml; \
    cp /usr/local/tomcat/temp/sbfcOnline.war /usr/local/tomcat/deploy/; \
    mkdir -p /data/converters/jobs /data/converters/zip /data/converters/ws /data/converters/sbfc/log; \
    chmod +x /data/converters/sbfc/sbfConverterOnline.sh; \
    mkdir log; \
    chown -R $USERNAME:$GROUP /usr/local/tomcat/webapps /usr/local/tomcat/temp /usr/local/tomcat/log /data/converters

USER $USERNAME
WORKDIR /usr/local/tomcat

CMD ["catalina.sh", "run"]
