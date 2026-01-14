#!/bin/bash
# ==============================================================================
# setup-cursor.sh
# ==============================================================================
# Purpose:
#   Configure symlinks for Cursor IDE from knowledge-base/04-AI-assets/AI-coding
#
# Target Structure:
#   .cursor/
#   ├── rules/        (*.md → *.mdc conversion for Cursor rules)
#   └── commands/     (direct symlinks for Cursor commands)
#       ├── workflows/
#       └── skills/
#
# Usage:
#   ./knowledge-base/04-AI-assets/AI-coding/scripts/setup-cursor.sh
#
# ==============================================================================

set -e

# ==============================================================================
# Path Configuration
# ==============================================================================

# Calculate directory paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AI_CODING_ROOT="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(cd "$AI_CODING_ROOT/../../.." && pwd)"

# Source directories
readonly RULES_SOURCE="$AI_CODING_ROOT/rules"
readonly WORKFLOWS_SOURCE="$AI_CODING_ROOT/workflows"
readonly SKILLS_SOURCE="$AI_CODING_ROOT/skills"

# Target directories
readonly CURSOR_DIR="$PROJECT_ROOT/.cursor"
readonly CURSOR_RULES_DIR="$CURSOR_DIR/rules"
readonly CURSOR_COMMANDS_DIR="$CURSOR_DIR/commands"

# ==============================================================================
# Helper Functions
# ==============================================================================

# ------------------------------------------------------------------------------
# Link individual files with extension conversion (*.md → *.{ext})
# ------------------------------------------------------------------------------
# Args:
#   $1: source_dir      - Directory containing .md files
#   $2: target_dir      - Target directory for symlinks
#   $3: target_ext      - Target file extension (e.g., "mdc")
# ------------------------------------------------------------------------------
link_files_with_conversion() {
    local src_dir="$1"
    local tgt_dir="$2"
    local tgt_ext="$3"
    
    echo "   📝 Processing: $(basename "$src_dir") → $(basename "$tgt_dir")"

    # Clean and recreate target directory
    rm -rf "$tgt_dir"
    mkdir -p "$tgt_dir"

    # Check if source directory exists
    if [ ! -d "$src_dir" ]; then
        echo "   ⚠️  Source directory not found: $src_dir"
        return
    fi

    # Change to source directory
    pushd "$src_dir" > /dev/null
    
    local count=0
    
    # Find and link all .md files
    while IFS= read -r -d '' file; do
        local rel_path="${file#./}"
        local rel_dir="$(dirname "$rel_path")"
        local file_base="${rel_path%.md}"
        local tgt_file="$tgt_dir/${file_base}.${tgt_ext}"
        
        # Create parent directory if needed
        mkdir -p "$tgt_dir/$rel_dir"
        
        # Create symlink with absolute path
        ln -sf "$src_dir/$rel_path" "$tgt_file"
        
        echo "      → $rel_path"
        ((count++))
    done < <(find . -type f -name "*.md" -print0)
    
    popd > /dev/null
    
    echo "   ✓ Linked $count file(s) as .$tgt_ext"
    echo
}

# ------------------------------------------------------------------------------
# Create directory symlink
# ------------------------------------------------------------------------------
# Args:
#   $1: source_dir   - Source directory to link
#   $2: target_link  - Target symlink path
# ------------------------------------------------------------------------------
link_directory() {
    local src_dir="$1"
    local tgt_link="$2"
    
    # Check if source directory exists
    if [ ! -d "$src_dir" ]; then
        echo "   ⚠️  Source directory not found: $src_dir"
        return
    fi
    
    # Clean existing link/directory
    rm -rf "$tgt_link"
    
    # Ensure parent directory exists
    mkdir -p "$(dirname "$tgt_link")"
    
    # Create symlink
    ln -s "$src_dir" "$tgt_link"
    
    echo "   ✓ $(basename "$tgt_link") → $src_dir"
}

# ==============================================================================
# Main Setup Process
# ==============================================================================

echo "🖱️  Configuring Cursor IDE Symlinks"
echo "===================================="
echo
echo "📂 Project Root: $PROJECT_ROOT"
echo "📂 AI-Coding: $AI_CODING_ROOT"
echo

# --- Step 1: Link Rules (with .md → .mdc conversion) ---
echo "📚 [1/2] Setting up Rules"
link_files_with_conversion "$RULES_SOURCE" "$CURSOR_RULES_DIR" "mdc"

# --- Step 2: Link Commands (workflows & skills) ---
echo "⚡ [2/2] Setting up Commands"
mkdir -p "$CURSOR_COMMANDS_DIR"
link_directory "$WORKFLOWS_SOURCE" "$CURSOR_COMMANDS_DIR/workflows"
link_directory "$SKILLS_SOURCE" "$CURSOR_COMMANDS_DIR/skills"
echo

echo "===================================="
echo "✅ Cursor IDE setup complete!"
echo
echo "📁 Structure created:"
echo "   .cursor/"
echo "   ├── rules/        (*.mdc files - auto-applied rules)"
echo "   └── commands/"
echo "       ├── workflows/ (step-by-step guides)"
echo "       └── skills/    (reusable capabilities)"
echo
