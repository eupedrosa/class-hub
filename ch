#!/usr/bin/env bash

# bash options
set -e # exit on error
set -u # exit on undefined variable (use ${varname:-} to check if a variable is defined)

# Class-Hub CLI
# This script is used to manage students repositories on github using the github api

# Check if the gh cli is installed
[[ ! -x "$(command -v gh)" ]] && { echo "GitHub CLI is not installed. Please install it from https://cli.github.com/"; exit 1; }
# Check if the jq cli is installed
[[ ! -x "$(command -v jq)" ]] && { echo "jq is not installed. Please install it from https://stedolan.github.io/jq/"; exit 1; }

# Check if the gh cli is authenticated
if ! gh auth status > /dev/null 2>&1; then
  echo "GitHub CLI is not authenticated. Please run 'gh auth login' to authenticate."
  exit 1
fi

# Add this helper function to calculate lective year
function get_lective_year() {
    local current_month=$(date +%m)
    local current_year=$(date +%Y)
    
    # If we're between January and July, we're in the second half of the academic year
    # So we use the previous year as the start
    if [ "$current_month" -le 7 ]; then
        echo "$(($current_year % 100 - 1))$(($current_year % 100))"
    else
        # If we're between August and December, we're in the first half
        echo "$(($current_year % 100))$(($current_year % 100 + 1))"
    fi
}

# Add this helper function to check if a GitHub user exists
function github_user_exists() {
    local username="$1"
    # Check if user exists using the GitHub API
    if gh api "users/${username}" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Create a new assignment
# An assignment consists of a repository template and a list of students organized in groups
function create_assignment() {
    # Check required arguments
    if [ "$#" -lt 3 ]; then
        echo "Usage: ch create-assignment <classroom_name> <assignment_name> <students_file> [template_repo]"
        exit 1
    fi

    local classroom_name="$1"
    local assignment_name="$2"
    local students_file="$3"
    local template_repo="${4:-}" # Optional template repository

    echo "Creating assignment '$assignment_name' in classroom '$classroom_name'..."

    # Validate that students file exists
    if [ ! -f "$students_file" ]; then
        echo "Error: Students file '$students_file' not found"
        exit 1
    fi

    # Create associative array to store students by group
    declare -A group_students

    # Get current lective year
    local lective_year=$(get_lective_year)

    # First pass: collect all students by group
    while IFS=, read -r username group_number || [ -n "$username" ]; do
        # Skip empty lines and comments
        [[ -z "$username" || "$username" =~ ^#.*$ ]] && continue
        
        # Trim whitespace
        username=$(echo "$username" | xargs)
        group_number=$(echo "$group_number" | xargs | tr -d '\r')

        # Append student username to group array
        if [ -z "${group_students[$group_number]:-}" ]; then
            group_students[$group_number]="$username"
        else
            group_students[$group_number]="${group_students[$group_number]} $username"
        fi
    done < "$students_file"

    # Show preview of repositories and students
    echo -e "\nThe following repositories will be created:"
    
    # Create a sorted array of group numbers
    readarray -t sorted_groups < <(printf '%s\n' "${!group_students[@]}" | sort -n)
    
    # Display groups in sorted order
    for group_number in "${sorted_groups[@]}"; do
        echo "${lective_year}-${assignment_name}-group${group_number}"
        repo_name="${lective_year}-${assignment_name}-group$(printf "%02d" "$group_number")"
        echo -e "\n  Repository: $classroom_name/$repo_name"
        echo "  Students:"
        for username in ${group_students[$group_number]}; do
            if github_user_exists "$username"; then
                echo "    - @$username"
            else
                echo "    - @$username (⚠️ GitHub user not found)"
            fi
        done
    done

    # Ask for confirmation
    echo -e "\nPlease review the repository names and student assignments."
    read -p "Do you want to proceed? (y/N) " -n 1 -r
    echo    # Move to a new line
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Operation cancelled."
        exit 1
    fi

    # Second pass: create repository for each group and add all students
    for group_number in "${sorted_groups[@]}"; do
        # Create repository name starting with lective year, using printf to pad group number with zeros
        repo_name="${lective_year}-${assignment_name}-group$(printf "%02d" "$group_number")"
        
        # Check if repository already exists
        if gh repo view "$classroom_name/$repo_name" >/dev/null 2>&1; then
            echo "Repository $repo_name already exists, skipping..."
            continue
        fi

        # Create repository
        echo "Creating repository $repo_name..."
        if [ -n "$template_repo" ]; then
            gh repo create "$classroom_name/$repo_name" --private --template "$template_repo"
        else
            gh repo create "$classroom_name/$repo_name" --private
        fi

        # Add all students in the group as collaborators
        for username in ${group_students[$group_number]}; do
            if github_user_exists "$username"; then
                echo "  - Inviting @$username to $repo_name..."
                gh api -X PUT "repos/$classroom_name/$repo_name/collaborators/$username" -f permission=write >/dev/null 2>&1
            else
                echo "  ⚠️  Warning: GitHub user '@$username' not found, skipping..."
            fi
        done
    done

    echo -e "\nAssignment creation completed!"
}

function list_assignments() {
    # Check required arguments
    if [ "$#" -lt 1 ]; then
        echo "Usage: ch list-assignments <classroom_name> [assignment_name]"
        exit 1
    fi

    local classroom_name="$1"
    local assignment_name="${2:-}" # Optional assignment name filter

    echo "Listing assignments in classroom '$classroom_name'..."
    
    if [ -n "$assignment_name" ]; then
        # If assignment name is provided, filter repositories that start with that name
        gh repo list "$classroom_name" --json name --jq ".[] | select(.name | startswith(\"$assignment_name\")) | .name"
    else
        # List all repositories in the classroom
        gh repo list "$classroom_name" --json name --jq '.[].name'
    fi
}

function get_assignment() {
    # Check required arguments
    if [ "$#" -lt 2 ]; then
        echo "Usage: ch get-assignment <classroom_name> <assignment_name> [target_directory]"
        exit 1
    fi

    local classroom_name="$1"
    local assignment_name="$2"
    local target_dir="${3:-.}" # Optional target directory, defaults to current directory

    echo "Getting assignment '$assignment_name' in classroom '$classroom_name'..."

    # List all repositories for this assignment
    repos=$(gh repo list "$classroom_name" --json name --jq ".[] | select(.name | startswith(\"$assignment_name\")) | .name")

    # Show repositories that will be processed and ask for confirmation
    echo -e "\nThe following repositories will be updated:"
    echo "$repos" | sed 's/^/  - /'
    
    read -p "Do you want to proceed? (y/N) " -n 1 -r
    echo    # Move to a new line
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Operation cancelled."
        exit 1
    fi

    # Create target directory if it doesn't exist
    mkdir -p "$target_dir"
    cd "$target_dir"

    # Process each repository
    for repo in $repos; do
        if [ -d "$repo" ]; then
            echo "Repository $repo exists, pulling latest changes..."
            (cd "$repo" && git pull)
        else
            echo "Cloning repository $repo..."
            gh repo clone "$classroom_name/$repo"
        fi
    done

    echo "Assignment repositories updated successfully!"
}

function update() {
    echo "Checking for updates..."
    
    # Define the repository and script location
    local repo="eupedrosa/class-hub"
    local script_path="ch"
    local current_script="$0"
    
    # Get the latest version from GitHub
    local tmp_file=$(mktemp)
    if ! gh api "repos/$repo/contents/$script_path" --jq '.content' | base64 -d > "$tmp_file"; then
        echo "Error: Failed to fetch the latest version"
        rm "$tmp_file"
        exit 1
    fi
    
    # Compare files
    if cmp -s "$current_script" "$tmp_file"; then
        echo "Already up to date!"
        rm "$tmp_file"
        exit 0
    fi
    
    # Replace current script with new version
    mv "$tmp_file" "$current_script"
    chmod +x "$current_script"

    # Update autocomplete file
    local autocomplete_path="$HOME/.local/share/bash-completion/completions/ch"
    if [ -f "$autocomplete_path" ]; then
        echo "Updating autocomplete file..."
        mkdir -p "$(dirname "$autocomplete_path")"
        "$current_script" autocomplete > "$autocomplete_path"
    fi
    
    echo "Successfully updated!"
}

function autocomplete() {
    cat << 'EOF'
_ch_completion() {
    local cur prev words cword
    _get_comp_words_by_ref -n : cur prev words cword

    # List of available commands
    local commands="create-assignment list-assignments get-assignment update"

    # Handle command-specific completions
    case ${words[1]} in
        create-assignment)
            case $cword in
                2) # classroom_name - complete with organization names
                    local orgs=$(gh api user/memberships/orgs --jq '.[].organization.login')
                    COMPREPLY=($(compgen -W "$orgs" -- "$cur"))
                    ;;
                4) # students_file - complete with .csv files
                    COMPREPLY=($(compgen -f -X '!*.csv' -- "$cur"))
                    ;;
                5) # template_repo - complete with repository names
                    local repos=$(gh repo list --json nameWithOwner --jq '.[].nameWithOwner')
                    COMPREPLY=($(compgen -W "$repos" -- "$cur"))
                    ;;
            esac
            ;;
        list-assignments|get-assignment)
            case $cword in
                2) # classroom_name - complete with organization names
                    local orgs=$(gh api user/memberships/orgs --jq '.[].organization.login')
                    COMPREPLY=($(compgen -W "$orgs" -- "$cur"))
                    ;;
            esac
            ;;
        *)
            # Complete command names
            COMPREPLY=($(compgen -W "$commands" -- "$cur"))
            ;;
    esac

    return 0
}

# Register the completion function
complete -F _ch_completion ch
EOF
}


# Handle arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    create-assignment)
      shift
      create_assignment "$@"
      exit 0
      ;;
    list-assignments)
      shift
      list_assignments "$@"
      exit 0
      ;;
    get-assignment)
      shift
      get_assignment "$@"
      exit 0
      ;;
    update)
      shift
      update "$@"
      exit 0
      ;;
    autocomplete)
      shift
      autocomplete "$@"
      exit 0
      ;;
    -h|--help)
      echo "Usage: $0 <command> <options>"
      echo ""
      echo "Commands:"
      echo "  create-assignment <classroom_name> <assignment_name> <students_file> [template_repo]"
      echo "  list-assignments <classroom_name> [assignment_name]"
      echo "  get-assignment <classroom_name> <assignment_name> [target_directory]"
      echo "  update                          Update the CLI tool to the latest version"
      echo "  autocomplete                    Output shell completion code"
      exit 0
      ;;
    *)
      echo "Error: Unknown command '$1'"
      echo "Run '$0 --help' for usage information"
      exit 1
      ;;
  esac
done

# If no command is provided, show help
echo "Error: No command provided"
echo "Run '$0 --help' for usage information"
exit 1
