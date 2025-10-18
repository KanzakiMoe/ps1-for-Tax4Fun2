FROM rocker/r-ver:4.2.2

ENV DEBIAN_FRONTEND=noninteractive

# Install system packages: wget, unzip, BLAST (ncbi-blast+), vsearch and libs for R packages
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        wget \
        unzip \
        ncbi-blast+ \
        vsearch \
        ca-certificates \
        libssl-dev \
        libcurl4-gnutls-dev \
        libxml2-dev \
    && rm -rf /var/lib/apt/lists/*

# Install DIAMOND (precompiled binary used by Tax4Fun2 reference data processes)
RUN wget -qO /tmp/diamond.tar.gz https://github.com/bbuchfink/diamond/releases/download/v0.9.24/diamond-linux64.tar.gz \
    && tar -xzf /tmp/diamond.tar.gz -C /tmp \
    && mv /tmp/diamond /usr/local/bin/diamond \
    && chmod +x /usr/local/bin/diamond \
    && rm /tmp/diamond.tar.gz

# Copy package sources into the image
COPY . /opt/Tax4Fun2
WORKDIR /opt/Tax4Fun2

# Install suggested R packages (seqinr, ape) and then install the package itself
RUN R -e "install.packages(c('seqinr','ape'), repos='https://cloud.r-project.org')" \
    && R CMD INSTALL .

CMD ["R"]
