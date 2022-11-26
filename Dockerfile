FROM debian:buster
ARG name="inotify-rsync-server"
ARG summary="inotify-rsync-server built on-top of debian:buster"
LABEL description="${summary}" \
	maintainer="<zctmdc@outlook.com>" \
	app.kubernetes.io/name="${name}" \
	org.opencontainers.image.title="${name}" \
	org.opencontainers.artifact.description="${summary}" \
	org.opencontainers.image.url="https://hub.docker.com/r/zctmdc/inotify-rsync-server" \
	org.opencontainers.image.source="https://github.com/zctmdc/inotify-rsync-server" \
	org.opencontainers.image.authors="zctmdc@outlook.com" \
	org.opencontainers.image.description="${summary}" \
	org.opencontainers.image.documentation="https://github.com/zctmdc/inotify-rsync-server"

ENV DEBIAN_FRONTEND noninteractive
ENV LANG C.UTF-8
ENV NOTVISIBLE "in users profile"

RUN apt-get update && \
	apt-get install -y openssh-server rsync inotify-tools && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN mkdir /var/run/sshd
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd
RUN echo "export VISIBLE=now" >> /etc/profile

COPY entrypoint.sh /entrypoint.sh
RUN chmod 744 /entrypoint.sh

ENV SERVICE_NAME=''
COPY inotify-rsync.sh /inotify-rsync.sh
RUN chmod 744 inotify-rsync.sh

EXPOSE 22
EXPOSE 873

CMD ["rsync_server"]
ENTRYPOINT ["/entrypoint.sh"]
