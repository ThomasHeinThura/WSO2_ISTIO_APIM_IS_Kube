# Builds an APIM 4.6.0 image with the MySQL JDBC driver included.
# Default BASE_IMAGE points to the public Docker Hub image.

ARG BASE_IMAGE=wso2/wso2am:4.6.0
FROM ${BASE_IMAGE}

ARG USER=wso2carbon
ARG USER_HOME=/home/${USER}
ARG WSO2_SERVER_NAME=wso2am
ARG WSO2_SERVER_VERSION=4.6.0
ARG WSO2_SERVER=${WSO2_SERVER_NAME}-${WSO2_SERVER_VERSION}
ARG WSO2_SERVER_HOME=${USER_HOME}/${WSO2_SERVER}

# Copy JDBC MySQL driver
ADD --chown=wso2carbon:wso2 https://repo1.maven.org/maven2/mysql/mysql-connector-java/8.0.28/mysql-connector-java-8.0.28.jar ${WSO2_SERVER_HOME}/repository/components/lib/
