#!/bin/bash

# IDM + Bottles Installation Wizard
# A slick installer for setting up Internet Download Manager with Bottles on Linux

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ASCII Art Banner
print_banner() {
    echo -e "${CYAN}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║   ██╗██████╗ ███╗   ███╗    ██████╗  ██████╗ ████████╗████████╗██╗     ███████╗███████╗ ║
║   ██║██╔══██╗████╗ ████║    ██╔══██╗██╔═══██╗╚══██╔══╝╚══██╔══╝██║     ██╔════╝██╔════╝ ║
║   ██║██║  ██║██╔████╔██║    ██████╔╝██║   ██║   ██║      ██║   ██║     █████╗  ███████╗ ║
║   ██║██║  ██║██║╚██╔╝██║    ██╔══██╗██║   ██║   ██║      ██║   ██║     ██╔══╝  ╚════██║ ║
║   ██║██████╔╝██║ ╚═╝ ██║    ██████╔╝╚██████╔╝   ██║      ██║   ███████╗███████╗███████║ ║
║   ╚═╝╚═════╝ ╚═╝     ╚═╝    ╚═════╝  ╚═════╝    ╚═╝      ╚═╝   ╚══════╝╚══════╝╚══════╝ ║
║                                                               ║
║               Internet Download Manager + Bottles            ║
║                      Installation Wizard                     ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Progress indicator
show_progress() {
    local current=$1
    local total=$2
    local description=$3
    local percent=$((current * 100 / total))
    local filled=$((percent / 2))
    local empty=$((50 - filled))
    
    printf "\r${CYAN}[Step %d/%d]${NC} %s " "$current" "$total" "$description"
    printf "${GREEN}"
    printf "%0.s█" $(seq 1 $filled)
    printf "${YELLOW}"
    printf "%0.s░" $(seq 1 $empty)
    printf "${NC} %d%%\n" "$percent"
}

# User prompts
ask_yes_no() {
    local question=$1
    while true; do
        echo -e "${YELLOW}$question${NC} ${CYAN}(y/n):${NC} "
        read -r answer
        case $answer in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo -e "${RED}Please answer y or n.${NC}";;
        esac
    done
}

# Error handling
handle_error() {
    echo -e "${RED}❌ Error: $1${NC}"
    echo -e "${YELLOW}⚠️  Installation failed. Please check the error above.${NC}"
    exit 1
}

# Success message
show_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# Info message
show_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Warning message
show_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        handle_error "This script should not be run as root!"
    fi
}

# Check system requirements
check_requirements() {
    show_info "Checking system requirements..."
    
    # Check if flatpak is installed
    if ! command -v flatpak &> /dev/null; then
        handle_error "Flatpak is not installed. Please install flatpak first."
    fi
    
    # Check if git is installed
    if ! command -v git &> /dev/null; then
        handle_error "Git is not installed. Please install git first."
    fi
    
    show_success "System requirements met!"
}

# Install Bottles
install_bottles() {
    show_progress 1 8 "Installing Bottles..."
    
    if flatpak list | grep -q "com.usebottles.bottles"; then
        show_info "Bottles is already installed!"
    else
        show_info "Installing Bottles from Flathub..."
        flatpak install flathub com.usebottles.bottles -y || handle_error "Failed to install Bottles"
        show_success "Bottles installed successfully!"
    fi
}

# Unsandbox Bottles
unsandbox_bottles() {
    show_progress 2 8 "Configuring Bottles permissions..."
    
    show_info "Granting Bottles full system access..."
    
    # Grant filesystem access
    flatpak override --user --filesystem=host com.usebottles.bottles || handle_error "Failed to grant filesystem access"
    
    # Grant additional permissions
    flatpak override --user --share=network --share=ipc --socket=x11 --socket=wayland --socket=pulseaudio --device=all com.usebottles.bottles || handle_error "Failed to grant device permissions"
    
    # Grant home and temp access
    flatpak override --user --filesystem=home --filesystem=/tmp --filesystem=/var/tmp com.usebottles.bottles || handle_error "Failed to grant temp access"
    
    # Grant flatpak integration
    flatpak override --user --talk-name=org.freedesktop.Flatpak com.usebottles.bottles || handle_error "Failed to grant flatpak integration"
    
    show_success "Bottles permissions configured!"
}

# Check for Node.js (required for IDM bridge)
check_nodejs() {
    show_progress 3 8 "Checking Node.js installation..."
    
    if ! command -v node &> /dev/null; then
        show_warning "Node.js not found. IDM browser integration requires Node.js."
        if ask_yes_no "Would you like to install Node.js using NodeSource repository?"; then
            show_info "Installing Node.js..."
            curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - || handle_error "Failed to add NodeSource repository"
            sudo apt-get install -y nodejs || handle_error "Failed to install Node.js"
            show_success "Node.js installed successfully!"
        else
            show_warning "Skipping Node.js installation. Browser integration may not work."
        fi
    else
        show_success "Node.js is already installed!"
    fi
}

# Create Wine wrapper
create_wine_wrapper() {
    show_progress 4 8 "Creating Wine wrapper script..."
    
    mkdir -p ~/.local/bin
    
    cat > ~/.local/bin/wine << 'EOF'
#!/bin/sh
flatpak run --command='bottles-cli' com.usebottles.bottles run -b IDM -e "$@"
EOF
    
    chmod +x ~/.local/bin/wine
    show_success "Wine wrapper script created!"
}

# Download and setup IDM bridge scripts
setup_idm_bridge() {
    show_progress 5 9 "Setting up IDM browser integration..."
    
    local temp_dir=$(mktemp -d)
    cd "$temp_dir"
    
    show_info "Downloading IDM integration files..."
    git clone https://github.com/tazihad/idm-linux.git || handle_error "Failed to clone IDM scripts"
    
    # Copy icon
    mkdir -p ~/.local/share/icons
    cp idm-linux/idm.png ~/.local/share/icons/ || handle_error "Failed to copy IDM icon"
    
    # Setup the proper IDM bridge script for Bottles
    show_info "Creating IDM bridge script..."
    mkdir -p ~/.local/bin
    
    cat > ~/.local/bin/idm << 'EOF'
#!/bin/bash

# IDM bridge script for Bottles
IDM_PATH="/home/$USER/.var/app/com.usebottles.bottles/data/bottles/bottles/IDM/drive_c/Program Files (x86)/Internet Download Manager/IDMan.exe"

# Check if IDM bottle and executable exist
if [[ ! -f "$IDM_PATH" ]]; then
    # Try alternative path (Program Files instead of Program Files (x86))
    IDM_PATH="/home/$USER/.var/app/com.usebottles.bottles/data/bottles/bottles/IDM/drive_c/Program Files/Internet Download Manager/IDMan.exe"
    if [[ ! -f "$IDM_PATH" ]]; then
        echo "Error: IDM not found in IDM bottle. Please install IDM first."
        echo "Expected locations:"
        echo "  - /home/$USER/.var/app/com.usebottles.bottles/data/bottles/bottles/IDM/drive_c/Program Files (x86)/Internet Download Manager/IDMan.exe"
        echo "  - /home/$USER/.var/app/com.usebottles.bottles/data/bottles/bottles/IDM/drive_c/Program Files/Internet Download Manager/IDMan.exe"
        exit 1
    fi
fi

if [[ $1 == '-d' ]]; then
   flatpak run --command='bottles-cli' com.usebottles.bottles run -b IDM -e "$IDM_PATH" /d "$2"
elif [[ $1 == *://* ]]; then
   flatpak run --command='bottles-cli' com.usebottles.bottles run -b IDM -e "$IDM_PATH" /d "$1"
else
   echo "Usage: idm [URL] or idm -d [URL]"
   echo "Example: idm https://example.com/file.zip"
fi
EOF
    
    chmod +x ~/.local/bin/idm
    
    cd - > /dev/null
    rm -rf "$temp_dir"
    show_success "IDM bridge setup complete!"
}

# Setup PATH and environment
setup_environment() {
    show_progress 6 9 "Configuring environment..."
    
    # Add ~/.local/bin to PATH if not already there
    if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
        show_info "Adding ~/.local/bin to PATH..."
        
        # Add to .bashrc
        if [[ -f ~/.bashrc ]] && ! grep -q "/.local/bin" ~/.bashrc; then
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
        fi
        
        # Add to .profile
        if [[ -f ~/.profile ]] && ! grep -q "/.local/bin" ~/.profile; then
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.profile
        fi
        
        # Create .profile if it doesn't exist
        if [[ ! -f ~/.profile ]]; then
            echo 'export PATH="$HOME/.local/bin:$PATH"' > ~/.profile
        fi
        
        show_success "PATH configured!"
    else
        show_info "PATH already configured."
    fi
}

# Create desktop entries and system integration
create_desktop_integration() {
    show_progress 7 9 "Creating desktop integration..."
    
    mkdir -p ~/.local/share/applications
    
    # Create IDM desktop entry
    cat > ~/.local/share/applications/internet-download-manager.desktop << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Internet Download Manager
Comment=Download manager running in Bottles
Exec=flatpak run --command='bottles-cli' com.usebottles.bottles run -b IDM -e "/home/$USER/.var/app/com.usebottles.bottles/data/bottles/bottles/IDM/drive_c/Program Files (x86)/Internet Download Manager/IDMan.exe"
Icon=idm.png
Terminal=false
Categories=Network;FileTransfer;
StartupNotify=true
MimeType=application/x-wine-extension-idm;
EOF
    
    # Create Bottles desktop entry (if not exists)
    if [[ ! -f ~/.local/share/applications/bottles.desktop ]]; then
        cat > ~/.local/share/applications/bottles.desktop << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Bottles
Comment=Run Windows applications on Linux
Exec=flatpak run com.usebottles.bottles
Icon=com.usebottles.bottles
Terminal=false
Categories=Utility;System;
StartupNotify=true
EOF
    fi
    
    # Update desktop database
    if command -v update-desktop-database &> /dev/null; then
        update-desktop-database ~/.local/share/applications/ 2>/dev/null || true
    fi
    
    show_success "Desktop integration created!"
}

# Create comprehensive guide
create_user_guide() {
    show_progress 8 9 "Creating user guide..."
    
    cat > ~/IDM-Bottles-Guide.md << 'EOF'
# IDM + Bottles Setup Guide

## Quick Start

### 1. Create IDM Bottle
```bash
# Open Bottles
bottles
```
- Click "Create New Bottle"
- Name: `IDM`
- Environment: Windows 10
- Click "Create"

### 2. Install IDM
- Download IDM: https://www.internetdownloadmanager.com/download.html
- In Bottles, select your IDM bottle
- Click "Run Executable" and select the IDM installer
- Follow the installation wizard

### 3. Install Browser Extension
- Firefox: https://addons.mozilla.org/en-US/firefox/addon/download-by/
- Chrome: https://chrome.google.com/webstore/detail/download-by/ndjcdnblompbohoefbjgbnjojfejddnd

### 4. Test Installation
```bash
# Test IDM bridge
idm https://speed.hetzner.de/100MB.bin

# Test wine wrapper
wine --version
```

## Commands

- `idm <URL>` - Download a file with IDM
- `wine <program.exe>` - Run Windows programs in IDM bottle
- `bottles` - Open Bottles management interface

## Troubleshooting

### IDM not found error
If you get "IDM not found in IDM bottle":
1. Make sure you created a bottle named exactly "IDM"
2. Install IDM in the default location
3. Check paths in `~/.local/bin/idm` script

### Browser extension not working
1. Make sure Node.js is installed: `node --version`
2. Check if `idm` command works from terminal
3. Restart your browser after installation

### Permission issues
Make sure Bottles has the right permissions:
```bash
flatpak permission-show com.usebottles.bottles
```

## File Locations

- IDM Bridge Script: `~/.local/bin/idm`
- Wine Wrapper: `~/.local/bin/wine`
- Desktop Entries: `~/.local/share/applications/`
- IDM Icon: `~/.local/share/icons/idm.png`
- Bottles Data: `~/.var/app/com.usebottles.bottles/`

## Links

- Bottles: https://usebottles.com/
- IDM: https://www.internetdownloadmanager.com/
- Browser Extension: https://add0n.com/download-by.html

Happy downloading! 🎉
EOF
    
    show_success "User guide created at ~/IDM-Bottles-Guide.md"
}

# Final instructions
show_final_instructions() {
    show_progress 9 9 "Installation complete!"
    
    echo -e "\n${GREEN}🎉 IDM + Bottles installation completed successfully!${NC}\n"
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}                           NEXT STEPS${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    echo -e "\n${BLUE}1. Create IDM Bottle:${NC}"
    echo -e "   • Open Bottles from your applications menu"
    echo -e "   • Create a new bottle named ${YELLOW}'IDM'${NC}"
    echo -e "   • Use Windows 10 environment"
    
    echo -e "\n${BLUE}2. Install IDM:${NC}"
    echo -e "   • Download IDM from: ${CYAN}https://www.internetdownloadmanager.com/download.html${NC}"
    echo -e "   • Install it in your IDM bottle"
    
    echo -e "\n${BLUE}3. Install Browser Extension:${NC}"
    echo -e "   • Firefox/Chrome: ${CYAN}https://add0n.com/download-by.html${NC}"
    echo -e "   • Follow extension setup instructions"
    
    echo -e "\n${BLUE}4. Test Installation:${NC}"
    echo -e "   • Run: ${GREEN}idm https://example.com/file.zip${NC}"
    echo -e "   • Or use: ${GREEN}wine /path/to/program.exe${NC}"
    
    echo -e "\n${BLUE}5. Read the Guide:${NC}"
    echo -e "   • A comprehensive guide has been created at ${YELLOW}~/IDM-Bottles-Guide.md${NC}"
    echo -e "   • Run: ${GREEN}cat ~/IDM-Bottles-Guide.md${NC} to view it"
    
    echo -e "\n${BLUE}6. Restart Your Session:${NC}"
    echo -e "   • Log out and back in, or restart your computer"
    echo -e "   • This ensures PATH changes take effect"
    
    echo -e "\n${GREEN}✨ Happy downloading! ✨${NC}\n"
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE}                    Useful Commands:${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${YELLOW}idm <URL>${NC}           - Download a file with IDM"
    echo -e "  ${YELLOW}wine <program.exe>${NC}  - Run Windows programs in IDM bottle"
    echo -e "  ${YELLOW}bottles${NC}             - Open Bottles management interface"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

# Main installation function
main() {
    clear
    print_banner
    
    echo -e "${PURPLE}Welcome to the IDM + Bottles Installation Wizard!${NC}\n"
    echo -e "This wizard will:\n"
    echo -e "• Install and configure Bottles"
    echo -e "• Set up Wine wrapper for IDM bottle"
    echo -e "• Create IDM bridge scripts for browser integration"
    echo -e "• Configure desktop integration"
    echo -e ""
    
    if ! ask_yes_no "Do you want to continue with the installation?"; then
        echo -e "${YELLOW}Installation cancelled.${NC}"
        exit 0
    fi
    
    echo -e ""
    
    # Run installation steps
    check_root
    check_requirements
    install_bottles
    unsandbox_bottles
    check_nodejs
    create_wine_wrapper
    setup_idm_bridge
    setup_environment
    create_desktop_integration
    create_user_guide
    show_final_instructions
}

# Run the installer
main "$@" 