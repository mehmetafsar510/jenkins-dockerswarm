#! /bin/bash
cd /home/ec2-user/jenkins-dockerswarm/
docker stack deploy -c <(docker-compose config) phonebook