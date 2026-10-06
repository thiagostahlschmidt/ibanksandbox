FROM debian:trixie-slim

ARG CHROME_URL=https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
ARG WARSAW_URL=https://cloud.gastecnologia.com.br/gas/warsaw/install/ubuntu_64bits.run

ENV DEBIAN_FRONTEND=noninteractive \
    container=docker \
    TZ=America/Sao_Paulo \
    CHROME_URL=${CHROME_URL} \
    WARSAW_URL=${WARSAW_URL}
STOPSIGNAL SIGRTMIN+3

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        systemd systemd-sysv dbus iproute2 locales tzdata ca-certificates wget sudo procps python3 \
        libnss3-tools x11-utils \
    && sed -i 's/^# *\(pt_BR.UTF-8 UTF-8\)/\1/' /etc/locale.gen \
    && locale-gen \
    && ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
# only once the locale exists: earlier, perl (debconf) warns it can't set it
ENV LANG=pt_BR.UTF-8

# The container is privileged: mask every unit that would reach the host kernel or hardware
RUN systemctl mask \
        systemd-sysctl.service systemd-modules-load.service systemd-binfmt.service \
        proc-sys-fs-binfmt_misc.automount proc-sys-fs-binfmt_misc.mount \
        sys-kernel-config.mount sys-kernel-debug.mount sys-kernel-tracing.mount \
        systemd-pstore.service systemd-hibernate-clear.service systemd-logind.service \
        sleep.target suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target \
        systemd-tpm2-setup-early.service systemd-tpm2-setup.service systemd-pcrmachine.service \
        systemd-pcrphase.service systemd-pcrphase-sysinit.service \
        systemd-journald-audit.socket \
        getty.target console-getty.service systemd-firstboot.service systemd-remount-fs.service \
        apt-daily.timer apt-daily-upgrade.timer \
    && mkdir -p /etc/systemd/journald.conf.d \
    && printf '[Journal]\nReadKMsg=no\nStorage=volatile\n' > /etc/systemd/journald.conf.d/container.conf \
    && ln -sf /dev/null /etc/tmpfiles.d/x11.conf

# Chrome's NSS DB must exist for warsaw to register its CA (the one behind https://127.0.0.1:30900).
RUN useradd -m -u 1000 -s /bin/bash bankusr \
    && echo 'bankusr ALL=(root) NOPASSWD: /usr/sbin/poweroff, /usr/bin/systemctl start bankusr-session.service' \
        > /etc/sudoers.d/bankusr \
    && chmod 0440 /etc/sudoers.d/bankusr \
    && su bankusr -c 'mkdir -p ~/.pki/nssdb && certutil -N -d sql:$HOME/.pki/nssdb --empty-password'

COPY bankusr-session.service /etc/systemd/system/

# Lets bb.com.br reach warsaw on 127.0.0.1 without Chrome's local network access prompt
RUN mkdir -p /etc/opt/chrome/policies/managed \
    && echo '{"LocalNetworkAccessAllowedForUrls": ["https://[*.]bb.com.br"]}' \
        > /etc/opt/chrome/policies/managed/ibank.json

COPY ibank-install /usr/local/sbin/
RUN ibank-install
COPY ibank-init /usr/local/sbin/
COPY browser /usr/local/bin/

ENTRYPOINT ["/usr/local/sbin/ibank-init"]
CMD ["/sbin/init"]
