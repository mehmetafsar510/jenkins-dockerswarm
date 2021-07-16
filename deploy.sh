#! /bin/bash
cd /home/ec2-user/jenkins-dockerswarm/
docker pull 646075469151.dkr.ecr.us-east-1.amazonaws.com/clarusway-repo/phonebook-app:latest
docker build -t 646075469151.dkr.ecr.us-east-1.amazonaws.com/clarusway-repo/phonebook-app:latest .
docker stack deploy -c <(docker-compose config) phonebook