FROM amazonlinux:2

# Update/Install modules
RUN yum update -y \
    && yum install \
        unzip \
        sudo \
        jq \
        postgresql \
        -y

# Install AWS CLI v2
# See: https://docs.aws.amazon.com/ja_jp/cli/latest/userguide/install-cliv2-linux.html
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && sudo ./aws/install \
    && rm awscliv2.zip

# Copy scripts directory to the image
COPY scripts scripts

#ECS ReadonlyRootFilesystem時のExec使用
RUN mkdir -p /var/lib/amazon
RUN chmod 777 /var/lib/amazon
RUN mkdir -p /var/log/amazon
RUN chmod 777 /var/log/amazon
VOLUME ["/var/lib/amazon", "/var/log/amazon" ]

#Writable Path into Volume
#Setting for ECS-Task ReadonlyRootFilesystem=true
VOLUME [ "/var/run", "/var/log" ]