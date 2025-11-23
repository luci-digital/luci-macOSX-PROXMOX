#!/bin/bash
# ORION Development Environment Setup
# Installs and configures zsh, antigen, and zsh-autoenv for ORION

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 ORION Development Environment Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Detect OS
OS="unknown"
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
fi

echo "Detected OS: $OS"
echo ""

# Step 1: Install zsh
echo "[1/5] Installing zsh..."
if command -v zsh &> /dev/null; then
    echo -e "${GREEN}✓${NC} zsh already installed: $(zsh --version)"
else
    if [[ "$OS" == "linux" ]]; then
        if command -v apt-get &> /dev/null; then
            sudo apt-get update -qq
            sudo apt-get install -y zsh
        elif command -v yum &> /dev/null; then
            sudo yum install -y zsh
        elif command -v pacman &> /dev/null; then
            sudo pacman -S --noconfirm zsh
        fi
    elif [[ "$OS" == "macos" ]]; then
        if command -v brew &> /dev/null; then
            brew install zsh
        else
            echo -e "${YELLOW}⚠${NC} Homebrew not found. Install from: https://brew.sh"
            echo "Then run: brew install zsh"
            exit 1
        fi
    fi
    echo -e "${GREEN}✓${NC} zsh installed"
fi

# Step 2: Install git (required for antigen)
echo ""
echo "[2/5] Checking git..."
if command -v git &> /dev/null; then
    echo -e "${GREEN}✓${NC} git already installed: $(git --version)"
else
    echo "Installing git..."
    if [[ "$OS" == "linux" ]]; then
        if command -v apt-get &> /dev/null; then
            sudo apt-get install -y git
        elif command -v yum &> /dev/null; then
            sudo yum install -y git
        elif command -v pacman &> /dev/null; then
            sudo pacman -S --noconfirm git
        fi
    elif [[ "$OS" == "macos" ]]; then
        brew install git
    fi
    echo -e "${GREEN}✓${NC} git installed"
fi

# Step 3: Install antigen (zsh plugin manager)
echo ""
echo "[3/5] Installing antigen..."
ANTIGEN_DIR="$HOME/.antigen"
if [[ -d "$ANTIGEN_DIR" ]]; then
    echo -e "${GREEN}✓${NC} antigen already installed"
else
    mkdir -p "$ANTIGEN_DIR"
    curl -L git.io/antigen > "$ANTIGEN_DIR/antigen.zsh"
    echo -e "${GREEN}✓${NC} antigen installed to $ANTIGEN_DIR"
fi

# Step 4: Configure .zshrc
echo ""
echo "[4/5] Configuring .zshrc..."

ZSHRC="$HOME/.zshrc"
BACKUP_ZSHRC="$HOME/.zshrc.backup.$(date +%Y%m%d_%H%M%S)"

# Backup existing .zshrc
if [[ -f "$ZSHRC" ]]; then
    cp "$ZSHRC" "$BACKUP_ZSHRC"
    echo -e "${YELLOW}⚠${NC} Backed up existing .zshrc to $BACKUP_ZSHRC"
fi

# Check if ORION config already exists
if grep -q "# ORION Development Environment" "$ZSHRC" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} ORION config already in .zshrc"
else
    # Append ORION configuration
    cat >> "$ZSHRC" <<'EOF'

# ============================================================================
# ORION Development Environment
# ============================================================================

# Load antigen
source $HOME/.antigen/antigen.zsh

# Load oh-my-zsh library
antigen use oh-my-zsh

# Plugins
antigen bundle git
antigen bundle docker
antigen bundle docker-compose
antigen bundle python
antigen bundle pip
antigen bundle ssh-agent
antigen bundle command-not-found
antigen bundle colored-man-pages
antigen bundle zsh-users/zsh-syntax-highlighting
antigen bundle zsh-users/zsh-autosuggestions
antigen bundle zsh-users/zsh-completions

# zsh-autoenv for auto-loading ORION environment
antigen bundle Tarrasch/zsh-autoenv

# Theme (you can change this)
antigen theme robbyrussell

# Apply antigen configuration
antigen apply

# ============================================================================
# ORION-specific settings
# ============================================================================

# Enable autoenv
export AUTOENV_ENABLE_LEAVE=true

# Auto-update completions
autoload -Uz compinit
compinit

# History settings
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE

# Better directory navigation
setopt AUTO_CD
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS

# Aliases
alias ll='ls -lah'
alias grep='grep --color=auto'
alias df='df -h'
alias free='free -h'

EOF
    echo -e "${GREEN}✓${NC} ORION config added to .zshrc"
fi

# Step 5: Set zsh as default shell
echo ""
echo "[5/5] Setting zsh as default shell..."

if [[ "$SHELL" == *"zsh"* ]]; then
    echo -e "${GREEN}✓${NC} zsh is already the default shell"
else
    echo "Changing default shell to zsh..."
    chsh -s $(which zsh)
    echo -e "${GREEN}✓${NC} Default shell changed to zsh (restart terminal to apply)"
fi

# Success message
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✓ ORION Development Environment Setup Complete!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "What was installed:"
echo "  ✓ zsh - Modern shell"
echo "  ✓ antigen - Plugin manager"
echo "  ✓ zsh-autoenv - Auto-loading environments"
echo "  ✓ zsh-syntax-highlighting - Command syntax highlighting"
echo "  ✓ zsh-autosuggestions - Command suggestions"
echo "  ✓ zsh-completions - Enhanced completions"
echo ""
echo "Next steps:"
echo "  1. Restart your terminal (or run: exec zsh)"
echo "  2. Navigate to ORION directory: cd $(pwd)"
echo "  3. Environment will auto-load with all ORION commands"
echo ""
echo "First time setup:"
echo "  - You'll be prompted to approve .autoenv.zsh (type 'yes')"
echo "  - This is a security feature to prevent malicious code"
echo "  - Once approved, it will auto-load every time you cd here"
echo ""
echo "Test it:"
echo "  cd $(pwd)"
echo "  orion-help"
echo ""
