#!/usr/bin/env bash
docker stack deploy -c <(docker-compose config) docker-compose.yml phonebook