# Use the official Ubuntu image as the base image
FROM ubuntu:22.04

# Set environment variable to noninteractive mode
ENV DEBIAN_FRONTEND=noninteractive

# Install necessary packages for a desktop environment, SSH server, and Oh My Zsh setup
RUN apt-get update && apt-get install -y \
    xrdp \
    xfce4 \
    xfce4-goodies \
    tightvncserver \
    openssh-server \       
    curl \
    git \
    && apt-get clean



# Set up the SSH server
RUN mkdir /var/run/sshd

# Allow password authentication for SSH (optional, but useful for testing)
RUN sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Set a root password for convenience (change as needed)
RUN echo 'root:pass123' | chpasswd 

# Configure XRDP to use xfce4 as the session manager
RUN echo xfce4-session > ~/.xsession

# Removes an error around this
RUN apt-get -y remove xfce4-power-manager


# Fixes input/output error
RUN update-alternatives --set x-terminal-emulator /usr/bin/xfce4-terminal.wrapper

# Expose SSH and XRDP ports
# EXPOSE 22
EXPOSE 22 3389

# Start the SSH server and XRDP service
CMD service ssh start && service xrdp start && tail -f /dev/null





