FROM debian:buster

ENV DEBIAN_FRONTEND noninteractive
ENV USER bankusr
ENV container docker
ENV LANG pt_BR.UTF-8
STOPSIGNAL SIGRTMIN+3

RUN apt-get update \
    && apt-get install -y --no-install-recommends locales wget ca-certificates gnupg sudo libgtk2.0-0 procps zenity python3 2> /dev/null \
    && locale-gen pt_BR.UTF-8 \
    && localedef -i pt_BR -f UTF-8 pt_BR.UTF-8 \
    && dpkg-reconfigure --frontend=noninteractive locales \
    && echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list \
    && wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1 apt-key add - \
    && apt-get update && apt-get install -y --no-install-recommends google-chrome-stable \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN rm -f /lib/systemd/system/multi-user.target.wants/* \
    /etc/systemd/system/*.wants/* \
    /lib/systemd/system/local-fs.target.wants/* \
    /lib/systemd/system/sockets.target.wants/*udev* \
    /lib/systemd/system/sockets.target.wants/*initctl* \
    /lib/systemd/system/sysinit.target.wants/systemd-tmpfiles-setup* \
    /lib/systemd/system/systemd-update-utmp*

RUN useradd -m ${USER} \
    && echo ${USER}' ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers \
    && echo 'Defaults !requiretty' >> /etc/sudoers

ADD warsaw_setup64.deb /var/cache/apt/archives
ADD browser /usr/local/bin

CMD ["/sbin/init"]
