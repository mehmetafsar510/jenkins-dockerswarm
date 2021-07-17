#! /bin/bash
cd /home/ec2-user/jenkins-dockerswarm/
docker stack deploy --with-registry-auth -c <(docker-compose config) --resolve-image always phonebook