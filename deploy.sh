#!/usr/bin/env bash
docker-compose config
docker stack deploy --with-registry-auth -c docker-compose.yml phonebook