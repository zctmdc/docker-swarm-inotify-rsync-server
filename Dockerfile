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
	org.opencontainers.image.documentation="https://github.com/zctmdc/inotify-rsync-server#inotify-rsync-when-rsyncd"

ENV DEBIAN_FRONTEND noninteractive
ENV LANG C.UTF-8
ENV NOTVISIBLE "in users profile"

RUN apt-get update && \
	apt-get install -y openssh-server rsync inotify-tools psmisc && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN mkdir /var/run/sshd
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd
RUN echo "export VISIBLE=now" >> /etc/profile

COPY entrypoint.sh /entrypoint.sh
RUN chmod 744 /entrypoint.sh
COPY inotify-rsync.sh /inotify-rsync.sh
RUN chmod 744 /inotify-rsync.sh

ENV USERNAME='admin'
ENV PASSWORD='mysecret'
ENV SERVICE_NAMES=''
ENV ALLOW='10.0.0.0/8 172.16.0.0/12 192.168.0.0/16'
ENV VOLUME='/data'
ENV VERBOSE 'false'
EXPOSE 22
EXPOSE 873

VOLUME [ "/data" ]

ENTRYPOINT ["/entrypoint.sh"]

CMD ["rsync_server"]
