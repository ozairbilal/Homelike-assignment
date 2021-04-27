FROM ubuntu:18.04
ARG version=''
RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get -qq update && \
    apt-get -y install python python-pip openssh-client jq groff vim docker.io curl && \
    pip install awscli && \
    apt-get -y  install ruby-full

RUN gem install cfn-nag --version "$version"
