.PHONY: run build test migrate-up migrate-down sqlc

run:
	go run cmd/server/main.go

build:
	go build -o bin/server cmd/server/main.go

test:
	go test ./... -v -race

migrate-up:
	goose -dir migrations -table goose_chatapp_version postgres "$(DATABASE_URL)" up

migrate-down:
	goose -dir migrations -table goose_chatapp_version postgres "$(DATABASE_URL)" down

sqlc:
	sqlc generate
