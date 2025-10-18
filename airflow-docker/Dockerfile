FROM apache/airflow:3.1.0

USER root
RUN set -eux; \
    apt-get update && \
    apt-get install -y --no-install-recommends openjdk-17-jre-headless procps && \
    rm -rf /var/lib/apt/lists/* && \
    arch="$(dpkg --print-architecture)" && \
    ln -s /usr/lib/jvm/java-17-openjdk-"${arch}" /usr/lib/jvm/java-17-openjdk

ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk
ENV PATH="${JAVA_HOME}/bin:${PATH}"

USER airflow
RUN pip install --no-cache-dir \
    apache-airflow-providers-microsoft-mssql \
    apache-airflow-providers-postgres \
    apache-airflow-providers-apache-spark \
    pymssql==2.3.0 psycopg2-binary==2.9.9 pyspark==3.5.1 \
    pandas==2.2.3 numpy==1.26.4 scikit-learn==1.5.2