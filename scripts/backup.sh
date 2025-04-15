#!/bin/bash
#write (directory name of project)_app - for example python-cicd-project_app
docker save -o my-python-app-backup.tar python-cicd-project_app:latest
echo "Backup created: my-python-app-backup.tar"