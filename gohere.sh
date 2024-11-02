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
DRY_RUN="false"
TEMPLATE_ONLY="false"

# Get the directory of the current script
SCRIPT_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# ------------------------------------------------------------------------------
# Functions
# ------------------------------------------------------------------------------

# Source the finest helper functions
[[ -f "${SCRIPT_PATH}/_helper.sh" ]] && source "${SCRIPT_PATH}/_helper.sh"

# How do they work?
usage(){
    >&2 echo -e "Usage:\n\n    ${Bold}${Green}$(basename "$0")${Reset} -p --project [PROJECT_NAME] -u --user [GITHUB_USER_NAME] [-d --dry-run] [-t --template-only]\n"
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


# Make a dang Makefile
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
" > Makefile
    execute "touch Makefile"
    execute "echo \"${makefile_content}\" > Makefile"
}


# Create initial mail.go file
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


# Create a basic golang project .gitignore
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


# Make some common directories
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


# Make github join in the party.. you count too.
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


# Initialized the project module
initialize_go_module() {
    execute "go mod init github.com/${GH_USER}/${PROJECT}"
    execute "go mod tidy"
}


# Install common development tooling
install_dev_tools() {
    local tools=(
        "github.com/golangci/golangci-lint/cmd/golangci-lint@latest"
        "github.com/air-verse/air@latest"
        "github.com/swaggo/swag/cmd/swag@latest"
    )

    for tool in "${tools[@]}"; do
        execute "go install ${tool}"
    done
}


# I can't hear you over all this drum and bass
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

    if [[ "${TEMPLATE_ONLY}" == "false" ]]; then
      init_keys
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

# Protect against running main when we run bats
if [[ "${TESTING:-false}" != "true" ]]; then
    main "$@"
fi
