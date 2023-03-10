#!/usr/bin/env bash

# Renders markdown doc in docs to html in gh_pages

# we need to install one more dependency to minidocs/mkdocs
PIP_INSTALL=$(mktemp)
cat >$PIP_INSTALL <<EOF
#!/bin/sh
echo "installing mdx_truly_sane_lists"
pip3 install mdx_truly_sane_lists
EOF
# get group id to use it in the docker
GID=$(id -g)

# we use minidocks capability to add entrypoint to install some pip package
# we use also it's capability to change user and group id to avoid permissions problems
docker run --rm \
  -v $PIP_INSTALL:/docker-entrypoint.d/60-pip-install.sh \
  -e USER_ID=$UID -e GROUP_ID=$GID \
  -v $(pwd):/app -w /app \
  minidocks/mkdocs build
# cleanup
rm $PIP_INSTALL
