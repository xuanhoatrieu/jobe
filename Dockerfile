# Custom Jobe-in-a-box: Dockerised Jobe server with Python Data Science libraries
# Based on https://github.com/trampgeek/jobeinabox
# Extended with: numpy, pandas, matplotlib, seaborn, scipy, sympy, plotly, pillow

FROM docker.io/ubuntu:24.04

LABEL \
    org.opencontainers.image.authors="xuanhoatrieu" \
    org.opencontainers.image.title="JobeInABox-DataScience" \
    org.opencontainers.image.description="Jobe server with Python data science libraries for Moodle CodeRunner" \
    org.opencontainers.image.source="https://github.com/xuanhoatrieu/jobe"

ARG TZ=Asia/Ho_Chi_Minh
ARG JOBE_VERSION=master

# Apache environment variables
ENV APACHE_RUN_USER=www-data
ENV APACHE_RUN_GROUP=www-data
ENV APACHE_LOG_DIR=/var/log/apache2
ENV APACHE_LOCK_DIR=/var/lock/apache2
ENV APACHE_PID_FILE=/var/run/apache2.pid
ENV LANG=C.UTF-8

# Copy apache virtual host config
COPY 000-jobe.conf /

# Set timezone + Install system packages
RUN ln -snf /usr/share/zoneinfo/"$TZ" /etc/localtime && \
    echo "$TZ" > /etc/timezone && \
    apt-get update && \
    apt-get --no-install-recommends install -yq \
        acl \
        apache2 \
        build-essential \
        fp-compiler \
        git \
        libapache2-mod-php \
        nano \
        nodejs \
        octave \
        default-jdk \
        php \
        php-cli \
        php-mbstring \
        php-intl \
        python3 \
        python3-pip \
        python3-setuptools \
        python3-dev \
        python3-venv \
        pylint \
        sqlite3 \
        sudo \
        tzdata \
        unzip \
        # Extra dependencies for matplotlib rendering
        pkg-config \
        libfreetype6-dev \
        libpng-dev \
        libjpeg-dev && \
    # -------------------------------------------------------
    # Install Python data science libraries (system-wide)
    # -------------------------------------------------------
    pip3 install --no-cache-dir --break-system-packages \
        numpy \
        pandas \
        matplotlib \
        seaborn \
        scipy \
        sympy \
        plotly \
        pillow \
        scikit-learn \
        openpyxl \
        tabulate && \
    # Configure matplotlib to use non-interactive backend (no display)
    mkdir -p /tmp/matplotlib && \
    echo "backend: Agg" > /etc/matplotlibrc && \
    # -------------------------------------------------------
    # Configure pylint
    # -------------------------------------------------------
    pylint --reports=no --score=n --generate-rcfile > /etc/pylintrc && \
    # -------------------------------------------------------
    # Configure Apache
    # -------------------------------------------------------
    ln -sf /proc/self/fd/1 /var/log/apache2/access.log && \
    ln -sf /proc/self/fd/1 /var/log/apache2/error.log && \
    sed -i "s/export LANG=C/export LANG=$LANG/" /etc/apache2/envvars && \
    sed -i '1 i ServerName localhost' /etc/apache2/apache2.conf && \
    sed -i 's/ServerTokens\ OS/ServerTokens \Prod/g' /etc/apache2/conf-enabled/security.conf && \
    sed -i 's/ServerSignature\ On/ServerSignature \Off/g' /etc/apache2/conf-enabled/security.conf && \
    rm /etc/apache2/sites-enabled/000-default.conf && \
    mv /000-jobe.conf /etc/apache2/sites-enabled/ && \
    mkdir -p /var/crash && \
    chmod 777 /var/crash && \
    echo '<!DOCTYPE html><html lang="en"><title>Jobe</title><h1>Jobe</h1></html>' > /var/www/html/index.html && \
    # -------------------------------------------------------
    # Clone and install Jobe (from upstream - rebuild to get updates)
    # -------------------------------------------------------
    git clone --single-branch --branch ${JOBE_VERSION} https://github.com/trampgeek/jobe.git /var/www/html/jobe && \
    apache2ctl start && \
    cd /var/www/html/jobe && \
    /usr/bin/python3 /var/www/html/jobe/install --max_uid=500 && \
    chown -R ${APACHE_RUN_USER}:${APACHE_RUN_GROUP} /var/www/html && \
    # -------------------------------------------------------
    # Cleanup
    # -------------------------------------------------------
    apt-get -y autoremove --purge && \
    apt-get -y clean && \
    rm -rf /var/lib/apt/lists/*

EXPOSE 80

# Healthcheck
HEALTHCHECK --interval=1m --timeout=2s \
    CMD /usr/bin/python3 /var/www/html/jobe/minimaltest.py || exit 1

# Start apache
CMD ["/usr/sbin/apache2ctl", "-D", "FOREGROUND"]
