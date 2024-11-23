#!/bin/bash

set -e # exit on error

# Create ~/.local/bin if it doesn't exist
mkdir -p ~/.local/bin

# Download the script
echo "Downloading Class-Hub CLI..."
curl -fsSL https://raw.githubusercontent.com/eupedrosa/class-hub/main/ch -o ~/.local/bin/ch

# Make it executable
chmod +x ~/.local/bin/ch

# Set up autocomplete
echo "Setting up autocomplete..."
~/.local/bin/ch autocomplete > ~/.local/share/bash-completion/completions/ch 2>/dev/null || {
    # If the default completion directory doesn't exist, try adding to bashrc
    mkdir -p ~/.local/share/bash-completion/completions/ 2>/dev/null
    ~/.local/bin/ch autocomplete > ~/.local/share/bash-completion/completions/ch
}

echo "Installation complete!"
echo
echo "Please make sure ~/.local/bin is in your PATH."
echo "You can add it by adding this line to your ~/.bashrc or ~/.zshrc:"
echo "    export PATH=\$PATH:\$HOME/.local/bin"
echo
echo "Then restart your shell or run:"
echo "    source ~/.bashrc  # or source ~/.zshrc"

