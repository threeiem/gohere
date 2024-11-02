#!/usr/bin/env bats

# Setup is run before each test
setup() {
    # Save original PWD
    ORIG_PWD="$PWD"
    
    # Create temp dir for tests
    TEST_DIR="$(mktemp -d)"
    
    # Copy scripts to test dir
    cp "$(pwd)/gohere.sh" "$TEST_DIR/"
    cp "$(pwd)/_helper.sh" "$TEST_DIR/"
    
    # Move to test dir
    cd "$TEST_DIR"
    
    # Export test variables
    export TEST_USER="test-user"
    export TEST_PROJECT="test-project"
    export DRY_RUN=true
    
    # Source the helper script first
    source _helper.sh
    # Then source the main script but skip running main
    export TESTING=true
    source ./gohere.sh
}

# Teardown is run after each test
teardown() {
    cd "$ORIG_PWD"
    rm -rf "$TEST_DIR"
}

@test "parse_arguments accepts valid arguments" {
    # Reset variables before test
    GH_USER=""
    PROJECT=""
    DRY_RUN=false
    TEMPLATE_ONLY=false
    
    # Run the test
    parse_arguments -p "$TEST_PROJECT" -u "$TEST_USER"
    
    # Assert results
    [ "$PROJECT" = "$TEST_PROJECT" ]
    [ "$GH_USER" = "$TEST_USER" ]
}

@test "parse_arguments fails without project" {
    # Reset variables before test
    GH_USER=""
    PROJECT=""
    DRY_RUN=false
    TEMPLATE_ONLY=false
    
    run parse_arguments -u "$TEST_USER"
    [ "$status" -eq 1 ]
    [[ "$(echo "$output" | strip_color)" =~ "Project name is required" ]]
}

@test "parse_arguments fails without user" {
    # Reset variables before test
    GH_USER=""
    PROJECT=""
    DRY_RUN=false
    TEMPLATE_ONLY=false
    
    run parse_arguments -p "$TEST_PROJECT"
    [ "$status" -eq 1 ]
    [[ "$(echo "$output" | strip_color)" =~ "Github username is required" ]]
}

@test "parse_arguments accepts dry run flag" {
    # Reset variables before test
    GH_USER=""
    PROJECT=""
    DRY_RUN=false
    TEMPLATE_ONLY=false
    
    parse_arguments -p "$TEST_PROJECT" -u "$TEST_USER" --dry-run
    [ "$DRY_RUN" = true ]
}

@test "execute function handles dry run mode" {
    DRY_RUN=true
    run execute "echo test"
    [ "$status" -eq 0 ]
    [[ "$(echo "$output" | strip_color)" =~ "Would execute: echo test" ]]
}

@test "create_makefile generates expected content" {
    PROJECT="testproj"
    run create_makefile
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Makefile" ]]
}

@test "setup_project_structure creates directories" {
    PROJECT="testproj"
    run setup_project_structure
    [ "$status" -eq 0 ]
    [[ "$output" =~ "cmd/testproj" ]]
}

@test "main function runs successfully in dry run mode" {
    run main -p "$TEST_PROJECT" -u "$TEST_USER" --dry-run
    [ "$status" -eq 0 ]
    [[ "$(echo "$output" | strip_color)" =~ "Setting up Go project" ]]
}
