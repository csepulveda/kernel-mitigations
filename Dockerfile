FROM amazonlinux:2023

RUN dnf install -y kmod procps && dnf clean all

COPY scripts/mitigate.sh /mitigate.sh
RUN chmod +x /mitigate.sh

ENTRYPOINT ["/mitigate.sh"]
