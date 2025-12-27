# Builds an APIM Universal GW 4.6.0 image with the MySQL JDBC driver included.
# Default BASE_IMAGE may need to be changed depending on where you pull the Universal GW image from.

ARG BASE_IMAGE=docker.wso2.com/wso2am-universal-gw:4.6.0.0
FROM ${BASE_IMAGE}

ARG USER_HOME=/home/${USER}
ARG WSO2_SERVER_NAME=wso2am-universal-gw
ARG WSO2_SERVER_VERSION=4.6.0
ARG WSO2_SERVER=${WSO2_SERVER_NAME}-${WSO2_SERVER_VERSION}
ARG WSO2_SERVER_HOME=${USER_HOME}/${WSO2_SERVER}

# Copy JDBC MySQL driver
ADD --chown=wso2carbon:wso2 https://repo1.maven.org/maven2/mysql/mysql-connector-java/8.0.28/mysql-connector-java-8.0.28.jar ${WSO2_SERVER_HOME}/repository/components/lib/
