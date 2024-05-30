#!/opt/homebrew/bin/bash

# Remove any text after the first space in string $1
strip_comments() {
    echo "$1" | head -n1 | awk '{print $1;}'
}
