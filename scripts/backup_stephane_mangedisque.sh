#!/bin/sh
rsync -av --exclude .dart --exclude .dartServer --exclude .gradle --exclude .vscode --exclude .cache --exclude Cache --exclude Slack --exclude google-chrome --exclude Code --exclude VSCodium /home/stephane stephane@mangedisque:ubuntu-backup/
