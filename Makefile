# Variables
DOCKER_IMAGE_NAME = ubuntu-desktop-dotmez-test
SSH_PORT = 2222
RDP_PORT = 3389

# Default target to build and run Docker container
all: build run

full:
	reset-docker build run
	
# Build the Docker image
build:
	docker build -t $(DOCKER_IMAGE_NAME) .

# Run the Docker container with or without RDP support
run-without-rdp:
	@echo "Running with SSH only..."
	docker run -d --name $(DOCKER_IMAGE_NAME) -p $(SSH_PORT):22 $(DOCKER_IMAGE_NAME)

run:
	@echo "Running with SSH and RDP..."
	docker run -d --name $(DOCKER_IMAGE_NAME) -p $(SSH_PORT):22 -p $(RDP_PORT):$(RDP_PORT) $(DOCKER_IMAGE_NAME)

# SSH into the Docker container
ssh:
	ssh root@localhost -p $(SSH_PORT)

stop:
	docker stop $(DOCKER_IMAGE_NAME)

# Remove the Docker container
reset-docker:
	docker stop $(DOCKER_IMAGE_NAME) && docker rm $(DOCKER_IMAGE_NAME)
	ssh-keygen -f "/home/meza/.ssh/known_hosts" -R "[localhost]:$(SSH_PORT)"

# Additional targets
rdp:
	@echo "Use an RDP client to connect to localhost:$(RDP_PORT)"
