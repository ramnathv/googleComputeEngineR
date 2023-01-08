#!/bin/bash
echo "Docker RStudio launch script"

RSTUDIO_USER=$(curl http://metadata.google.internal/computeMetadata/v1/instance/attributes/rstudio_user -H "Metadata-Flavor: Google")
RSTUDIO_PW=$(curl http://metadata.google.internal/computeMetadata/v1/instance/attributes/rstudio_pw -H "Metadata-Flavor: Google")
GCER_DOCKER_IMAGE=$(curl http://metadata.google.internal/computeMetadata/v1/instance/attributes/gcer_docker_image -H "Metadata-Flavor: Google")
VM_NAME=$(curl http://metadata.google.internal/computeMetadata/v1/instance/name -H "Metadata-Flavor: Google")

# Truncate hostname to 64 characters since max allowable length of hostname is 64.
CONTAINER_HOSTNAME=${VM_NAME:0:64}

echo "Docker image: $GCER_DOCKER_IMAGE"
echo "VM Name: $VM_NAME"
echo "Container Hostname: $CONTAINER_HOSTNAME"

# Add new iptables firewall rule to allow incomming traffic on port 2222
iptables -A INPUT -p tcp -m tcp --dport 2222 -j ACCEPT

# Remove the existing port 22 rule (otherwise this existing rule will prevent traffic from going to the docker container)
iptables -D INPUT -p tcp -m tcp --dport 22 -j ACCEPT

# Change the default SSH port to 2222
SSH_CONF_FILE=/etc/ssh/sshd_config
cat /etc/ssh/sshd_config
echo "Modifying $SSH_CONF_FILE"
if grep -q "Port [[:digit:]]*" $SSH_CONF_FILE; then
    # If a Port directive is already specified in the ssh conf file, change that line.
    sed -i 's/Port [[:digit:]]*/Port 2222/g' hello
else
    # Otherwise, append a new Port directive
    echo "Port 2222" >> $SSH_CONF_FILE
fi
cat /etc/ssh/sshd_config

sudo systemctl restart sshd
systemctl status sshd

docker run -p 80:8787 \
           -p 22:22 \
           -p 8080:80 \
           -h $CONTAINER_HOSTNAME \
           -e ROOT=TRUE \
           -e USER=$RSTUDIO_USER \
           -e PASSWORD=$RSTUDIO_PW \
           -e GCER_DOCKER_IMAGE=$GCER_DOCKER_IMAGE \
           -v /home/{{username}}:/home/{{username}} \
           --name=rstudio \
           $GCER_DOCKER_IMAGE
