# Class-Hub

Class-Hub is a command-line tool that simplifies the management of student group repositories on GitHub. Using the GitHub API, it automates the creation and management of repositories for classroom assignments, making it easier for educators to organize and track student work.

The `ch` CLI tool provides features like:
- Creating repositories for student groups from a template
- Managing student access permissions automatically
- Bulk cloning/updating of assignment repositories
- Smart academic year handling
- Tab completion support

## Quick Start

1. Install the CLI tool (see Installation below)
2. Authenticate with GitHub:
```bash
gh auth login
```
3. Create a CSV file with student groups (e.g., `students.csv`):
```csv
student1@email.com, 1
student2@email.com, 1
student3@email.com, 2
student4@email.com, 2
```
4. Create an assignment:
```bash
ch create-assignment classroom-org assignment-name students.csv [template-repo]
```

## Installation

You can install Class-Hub using the provided install script:

```bash
curl -fsSL https://raw.githubusercontent.com/eupedrosa/class-hub/main/install.sh | bash
```

### Prerequisites

- [GitHub CLI](https://cli.github.com/) (`gh`)
- [jq](https://stedolan.github.io/jq/)

### Manual Installation

If you prefer to install manually:

1. Ensure `~/.local/bin` is in your PATH
2. Download the script:
```bash
curl -fsSL https://raw.githubusercontent.com/eupedrosa/class-hub/main/ch -o ~/.local/bin/ch
chmod +x ~/.local/bin/ch
```
3. Set up autocomplete (optional):
```bash
ch autocomplete > ~/.local/share/bash-completion/completions/ch
```

## Usage

### Create Assignment
```bash
ch create-assignment <classroom_name> <assignment_name> <students_file> [template_repo]
```
NOTE: The lective year is automatically added to the assignment name.

### List Assignments
```bash
ch list-assignments <classroom_name> [assignment_name]
```

### Get Assignment
```bash
ch get-assignment <classroom_name> <assignment_name> [target_directory]
```

### Update CLI Tool
```bash
ch update
```
Updates the CLI tool to the latest version.

For more information, run:
```bash
ch --help
```