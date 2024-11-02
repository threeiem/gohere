#!/usr/bin/env bash
# ------------------------------------------------------------------------------
#  Runtime Environment
# ------------------------------------------------------------------------------

set -e
set -u
set -o pipefail

# ------------------------------------------------------------------------------
# GLOBAL Defaults
# ------------------------------------------------------------------------------

GH_USER=""
PROJECT=""
DRY_RUN=false
TEMPLATE_ONLY=false

# Colors/Views
Reset=$({ tput sgr0 || tput me;} 2> /dev/null)

[ -t 1 ] && [ -n "$TERM" ] && [ "$TERM" != *-m ] && [ "$TERM" != "dumb" ] && {
    Bold=$({ tput bold || tput md;} 2> /dev/null)
    Black=$({ tput setaf 0 || tput AF 0;} 2> /dev/null)
    White=$({ tput setaf 7 || tput AF 7;} 2> /dev/null)
    Red=$({ tput setaf 1 || tput AF 1;} 2> /dev/null)
    Green=$({ tput setaf 2 || tput AF 2;} 2> /dev/null)
    Yellow=$({ tput setaf 3 || tput AF 3;} 2> /dev/null)
    Blue=$({ tput setaf 4 || tput AF 4;} 2> /dev/null)
    Purple=$({ tput setaf 5 || tput AF 5;} 2> /dev/null)
    Cyan=$({ tput setaf 6 || tput AF 6;} 2> /dev/null)
}

# ------------------------------------------------------------------------------
# Functions
# ------------------------------------------------------------------------------

usage(){
    >&2 echo -e "Usage:\n\n    ${Bold}${Green}$(basename $0)${Reset} -p --project [PROJECT_NAME] -u --user [GITHUB_USER_NAME] [-d --dry-run] [-t --template-only]\n"
    >&2 echo "Options:"
    >&2 echo "  -p, --project        Project name"
    >&2 echo "  -u, --user          GitHub username"
    >&2 echo "  -d, --dry-run       Show commands without executing"
    >&2 echo "  -t, --template-only Create local structure without GitHub setup"
    exit 1
}

# Execute or simulate command based on DRY_RUN
execute() {
    if [ "$DRY_RUN" = true ]; then
        info "[DRY RUN] Would execute: $@"
    else
        eval "$@"
    fi
}

# Your existing helper functions here...
[[ -f "helper_functions.sh" ]] && source "helper_functions.sh"

create_makefile() {
    local makefile_content="
.PHONY: build test lint run clean

build:
	go build -v ./cmd/${PROJECT}

test:
	go test -v -race ./...

lint:
	golangci-lint run

run:
	go run cmd/${PROJECT}/main.go

clean:
	rm -f ${PROJECT}
	go clean -cache
"
    execute "echo \"${makefile_content}\" > Makefile"
}

create_main_go() {
    local main_content='
package main

import (
	"fmt"
	"log"
)

func main() {
	log.Println("Starting application...")
	fmt.Println("Hello from '"${PROJECT}"'!")
}
'
    execute "mkdir -p cmd/${PROJECT}"
    execute "echo \"${main_content}\" > cmd/${PROJECT}/main.go"
}

create_gitignore() {
    local gitignore_content="
# Binaries and build
bin/
${PROJECT}

# Dependencies
vendor/

# IDE
.idea/
.vscode/
*.swp

# Logs
*.log

# Environment variables
.env
"
    execute "echo \"${gitignore_content}\" > .gitignore"
}

setup_project_structure() {
    local dirs=(
        "cmd/${PROJECT}"
        "internal/app"
        "internal/pkg/config"
        "internal/pkg/database"
        "internal/pkg/server"
        "pkg/models"
        "pkg/utils"
        "api/v1"
        "docs"
        "test/integration"
        "test/unit"
    )

    for dir in "${dirs[@]}"; do
        execute "mkdir -p $dir"
    done

    create_main_go
    create_makefile
    create_gitignore
}

setup_github_repo() {
    if [ "$TEMPLATE_ONLY" = false ]; then
        # Check if gh CLI is installed
        if ! command -v gh &> /dev/null; then
            error "GitHub CLI (gh) is not installed. Please install it first."
            exit 1
        fi

        execute "gh repo create ${PROJECT} --public --clone"
    fi
}

initialize_go_module() {
    execute "go mod init github.com/${GH_USER}/${PROJECT}"
    execute "go mod tidy"
}

install_dev_tools() {
    local tools=(
        "github.com/golangci/golangci-lint/cmd/golangci-lint@latest"
        "github.com/cosmtrek/air@latest"
        "github.com/swaggo/swag/cmd/swag@latest"
    )

    for tool in "${tools[@]}"; do
        execute "go install ${tool}"
    done
}

# ------------------------------------------------------------------------------
# Parse Arguments
# ------------------------------------------------------------------------------

parse_arguments(){
    while [[ $# > 0 ]]; do
        case "${1}" in
            -p|--project)
                PROJECT="${2}"
                shift 2
                ;;
            -u|--user)
                GH_USER="${2}"
                shift 2
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -t|--template-only)
                TEMPLATE_ONLY=true
                shift
                ;;
            *)
                warn "Unknown option: ${1}"
                usage
                ;;
        esac
    done

    if [[ -z "${GH_USER}" ]]; then
        error "Github username is required."
        usage
    fi

    if [[ -z "${PROJECT}" ]]; then
        error "Project name is required."
        usage
    fi
}

# ------------------------------------------------------------------------------
# Main
# ------------------------------------------------------------------------------

main() {
    parse_arguments "$@"

    info "Setting up Go project: github.com/${GH_USER}/${PROJECT}"

    if [ "$DRY_RUN" = true ]; then
        info "Running in dry-run mode - no changes will be made"
    fi

    execute "mkdir -p ${PROJECT}"
    execute "cd ${PROJECT}"

    setup_project_structure
    initialize_go_module
    install_dev_tools

    if [ "$TEMPLATE_ONLY" = false ]; then
        setup_github_repo

        # Initial commit
        execute "git add ."
        execute "git commit -m 'Initial commit: Basic Go project structure'"
        execute "git push -u origin main"
    fi

    info "Project setup complete! 🎉"
}

main "$@"
