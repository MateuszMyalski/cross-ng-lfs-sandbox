#!/usr/bin/env bash
docker build -t emb_linux_env .
docker build --progress=plain -t emb_linux_env . 2>&1 | tee build.log
docker run -v ./shared:/home/builder/shared emb_linux_env:latest
docker run -v ./shared:/home/builder/shared -it emb_linux_env:latest
