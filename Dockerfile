# Dockerfile for Scrapyd-EZLaunch
FROM debian:bookworm
LABEL maintainer="Scrapyd-EZLaunch"

ARG TARGETPLATFORM

SHELL ["/bin/bash", "-c"]

COPY ./requirements.txt /
RUN set -xe \
    && apt-get update \
    && apt-get install -y autoconf \
                          build-essential \
                          curl \
                          git \
                          libffi-dev \
                          libssl-dev \
                          libtool \
                          libxml2 \
                          libxml2-dev \
                          libxslt1.1 \
                          libxslt1-dev \
                          python3 \
                          python3-cryptography \
                          python3-dev \
                          python3-distutils \
                          python3-pil \
                          python3-pip \
                          tini \
                          vim-tiny \
                          pwgen \
                          locales \
                          locales-all \
    && rm -f /usr/lib/python3.11/EXTERNALLY-MANAGED \
    && if [[ ${TARGETPLATFORM} = "linux/arm/v7" ]]; then apt install -y cargo; fi \
    && pip install -r requirements.txt \
    && mkdir -p /etc/bash_completion.d \
    && curl -sSL https://github.com/scrapy/scrapy/raw/master/extras/scrapy_bash_completion -o /etc/bash_completion.d/scrapy_bash_completion \
    && echo 'source /etc/bash_completion.d/scrapy_bash_completion' >> /root/.bashrc \
    && if [[ ${TARGETPLATFORM} = "linux/arm/v7" ]]; then apt purge -y --auto-remove cargo; fi \
    && apt-get purge -y --auto-remove autoconf \
                                      build-essential \
                                      curl \
                                      libffi-dev \
                                      libssl-dev \
                                      libtool \
                                      libxml2-dev \
                                      libxslt1-dev \
                                      python3-dev \
    && rm -rf /var/lib/apt/lists/*

# Configure locale
RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    sed -i -e 's/# es_ES.UTF-8 UTF-8/es_ES.UTF-8 UTF-8/' /etc/locale.gen && \
    dpkg-reconfigure --frontend=noninteractive locales && \
    update-locale LANG=en_US.UTF-8

ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8

# Set up Scrapyd configuration
COPY ./scrapyd.conf /etc/scrapyd/
COPY ./update_scrapyd_conf.sh /update_scrapyd_conf.sh
RUN chmod +x /update_scrapyd_conf.sh

# Create directories for data persistence
RUN mkdir -p /var/lib/scrapyd/eggs \
    /var/lib/scrapyd/logs \
    /var/lib/scrapyd/items \
    /var/lib/scrapyd/dbs \
    && chown -R root:root /var/lib/scrapyd

VOLUME /etc/scrapyd/ /var/lib/scrapyd/
EXPOSE 6800

ENTRYPOINT ["tini", "--"]
CMD ["/bin/bash", "-c", "/update_scrapyd_conf.sh && scrapyd --pidfile="]