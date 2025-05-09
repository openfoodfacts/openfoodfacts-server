#!/bin/bash
# This script is used by logrotate to reload Apache in Docker
docker-compose exec -T backend apache2ctl graceful