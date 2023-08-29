#!/bin/bash
if [[ "$1" = "start" ]]; then
    docker network create pizza
    docker run --rm \
        --detach \
        --name pizza-oven-db \
        --network pizza \
        -e POSTGRES_PASSWORD=pw \
        -p "5432:5432" \
        postgres:15.3-alpine

    for i in `seq 1 10`;
    do
        echo Pinging Postgres
        sleep 5
        nc -z -w 1 localhost 5432 && break
    done

    docker run --rm \
        --name migrations \
        --network pizza \
        -v $(pwd)/migrations:/var/migrations \
        migrate/migrate:v4.16.2 \
        -source file:///var/migrations \
        -database postgres://postgres:pw@pizza-oven-db:5432?sslmode=disable \
        -verbose \
        up
    docker run --rm \
        --detach \
        --name pizza-app \
        --network pizza \
        -v $(pwd):$(pwd) \
        -w $(pwd) \
        -p "8080:8080" \
        golang:1.21-alpine \
        go run main.go

    for i in `seq 1 10`;
    do
        echo Pinging Pizza Oven
        sleep 5
        curl -s --connect-timeout 1 http://localhost:8080/ping && break
    done
    curl -v -d '{"url":"https://github.com/open-sauced/insights"}' \
        -H "Content-Type: application/json" \
        -X POST http://localhost:8080/bake
    docker run --rm -it \
        --network pizza \
        postgres:15.3-alpine \
        sh
fi
if [[ "$1" = "stop" ]]; then
    docker stop pizza-app
    docker stop pizza-oven-db
    docker network rm pizza
fi