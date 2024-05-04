# .dotmez

## Mez Dots Files

## Testing in docker
To build the docker, use the following command:
```shell
docker build -t ubuntu-desktop-dotmez-test .
```
To run the docker, use the following command:
```shell
docker run -d --name ubuntu-desktop-dotmez-test -p 2222:22 ubuntu-desktop-dotmez-test

```
Or is wanting desktop:
```shell
docker run -d --name ubuntu-desktop-dotmez-test -p 2222:22 -p 3389:3389 ubuntu-desktop-dotmez-test

```
Then SSH into the docker vm:
```shell
ssh root@localhost -p 2222
```
Or RDP into the docker: 
```shell
rdesktop -u root -p pass123 localhost
```
Stop and remove the docker:
```shell
docker stop ubuntu-desktop-dotmez-test && docker rm ubuntu-desktop-dotmez-test
```

ssh-keygen -f "/home/meza/.ssh/known_hosts" -R "[localhost]:2222"


## config files
	- alias
	- .zshrc
	- Env Vars?
	- tmux ?
	- ssh logins
	- Github deets?
	- lunavim configs
	- tmux shortcuts
	- lunavim shortcuts / configs
	- powerlevel10k config / style
	- oh my zsh
	- oh my zsh plugins
	- make p10k look good and change colour random?

## VSCode extensions and settings
	- check all for extensions (print out list?)

## move script(s)
	- move for the above files from repo into associated folders

## backup script(s)
	- backup and rename for the above files
	
## install script(s)
	- to install common apps and copy from repo to associated  folders

each of the above for MacOS / Ubuntu / Other

