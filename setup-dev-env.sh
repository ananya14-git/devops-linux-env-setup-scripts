#!/bin/bash

# =============================================
# DevOps Development Environment Setup Script
# =============================================
# This script automates setting up a complete
# DevOps development environment on Linux.
# =============================================

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Log file
LOG_FILE="logs/install_$(date +%Y%m%d_%H%M%S).log"

# =============================================
# Helper Functions
# =============================================

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# =============================================
# System Detection
# =============================================

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
    else
        OS=$(uname -s)
        VER=$(uname -r)
    fi
    
    info "Detected OS: $OS $VER"
    
    case $OS in
        ubuntu|debian)
            PKG_MANAGER="apt-get"
            INSTALL_CMD="sudo apt-get install -y"
            UPDATE_CMD="sudo apt-get update"
            ;;
        rhel|centos|fedora)
            PKG_MANAGER="yum"
            INSTALL_CMD="sudo yum install -y"
            UPDATE_CMD="sudo yum check-update"
            if [ "$OS" = "fedora" ]; then
                PKG_MANAGER="dnf"
                INSTALL_CMD="sudo dnf install -y"
                UPDATE_CMD="sudo dnf check-update"
            fi
            ;;
        *)
            error "Unsupported OS: $OS"
            ;;
    esac
    
    info "Package manager: $PKG_MANAGER"
}

# =============================================
# Installation Functions
# =============================================

install_basic_tools() {
    log "Installing basic development tools..."
    
    $UPDATE_CMD >> "$LOG_FILE" 2>&1
    
    # Common tools for all distributions
    BASIC_PACKAGES="curl wget git vim htop net-tools tree unzip zip build-essential"
    
    if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
        $INSTALL_CMD $BASIC_PACKAGES software-properties-common apt-transport-https ca-certificates gnupg lsb-release >> "$LOG_FILE" 2>&1
    elif [ "$OS" = "rhel" ] || [ "$OS" = "centos" ] || [ "$OS" = "fedora" ]; then
        $INSTALL_CMD $BASIC_PACKAGES epel-release >> "$LOG_FILE" 2>&1
    fi
    
    if [ $? -eq 0 ]; then
        log "✓ Basic tools installed successfully"
    else
        error "Failed to install basic tools"
    fi
}

setup_git() {
    log "Configuring Git..."
    
    # Backup existing gitconfig if it exists
    if [ -f ~/.gitconfig ]; then
        mv ~/.gitconfig ~/.gitconfig.backup.$(date +%Y%m%d_%H%M%S)
        warning "Existing gitconfig backed up"
    fi
    
    # Copy gitconfig template
    cp configs/gitconfig ~/.gitconfig
    
    # Prompt for user details
    echo ""
    read -p "Enter your Git username: " git_username
    read -p "Enter your Git email: " git_email
    
    # Update gitconfig with user details
    sed -i "s/YOUR_NAME/$git_username/g" ~/.gitconfig
    sed -i "s/YOUR_EMAIL@example.com/$git_email/g" ~/.gitconfig
    
    log "✓ Git configured successfully"
    
    # Set up global gitignore
    cat > ~/.gitignore_global << EOF
# OS generated files
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db

# Editor files
*.swp
*.swo
*~
.vim/
.vscode/

# Logs and databases
*.log
*.sql
*.sqlite

# OS files
Thumbs.db
.DS_Store
EOF
    
    git config --global core.excludesfile ~/.gitignore_global
    log "✓ Global gitignore configured"
}

setup_bash_aliases() {
    log "Setting up bash aliases..."
    
    # Backup existing bashrc
    if [ -f ~/.bashrc ]; then
        cp ~/.bashrc ~/.bashrc.backup.$(date +%Y%m%d_%H%M%S)
    fi
    
    # Add aliases to bashrc if not already present
    if ! grep -q "CUSTOM ALIASES" ~/.bashrc; then
        echo -e "\n# ---------- CUSTOM ALIASES ----------" >> ~/.bashrc
        cat configs/.bashrc_aliases >> ~/.bashrc
        echo -e "# ---------- END CUSTOM ALIASES ----------\n" >> ~/.bashrc
        log "✓ Aliases added to .bashrc"
    else
        warning "Aliases already present in .bashrc"
    fi
    
    # Source bashrc to apply changes
    source ~/.bashrc 2>/dev/null || true
}

setup_vim() {
    log "Configuring Vim..."
    
    # Backup existing vimrc
    if [ -f ~/.vimrc ]; then
        cp ~/.vimrc ~/.vimrc.backup.$(date +%Y%m%d_%H%M%S)
    fi
    
    # Copy vim configuration
    cp configs/.vimrc ~/.vimrc
    
    # Install Vim plugin manager
    curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim >> "$LOG_FILE" 2>&1
    
    log "✓ Vim configured successfully"
}

install_docker() {
    log "Installing Docker..."
    
    if command_exists docker; then
        warning "Docker is already installed"
        docker --version
    else
        if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
            # Remove old versions
            sudo apt-get remove docker docker-engine docker.io containerd runc >> "$LOG_FILE" 2>&1
            
            # Install Docker using official script
            curl -fsSL https://get.docker.com -o get-docker.sh
            sudo sh get-docker.sh >> "$LOG_FILE" 2>&1
            
            # Add user to docker group
            sudo usermod -aG docker $USER
            
            log "✓ Docker installed successfully"
            log "NOTE: You need to log out and back in for docker group changes to take effect"
            
        elif [ "$OS" = "rhel" ] || [ "$OS" = "centos" ] || [ "$OS" = "fedora" ]; then
            sudo $PKG_MANAGER install -y yum-utils
            sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            sudo $PKG_MANAGER install -y docker-ce docker-ce-cli containerd.io
            sudo systemctl start docker
            sudo systemctl enable docker
            sudo usermod -aG docker $USER
            log "✓ Docker installed successfully"
        fi
        
        # Install Docker Compose
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        log "✓ Docker Compose installed successfully"
    fi
}

install_kubectl() {
    log "Installing kubectl..."
    
    if command_exists kubectl; then
        warning "kubectl is already installed"
    else
        # Download latest kubectl
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        
        # Install kubectl
        chmod +x kubectl
        sudo mv kubectl /usr/local/bin/
        
        log "✓ kubectl installed successfully"
    fi
}

install_terraform() {
    log "Installing Terraform..."
    
    if command_exists terraform; then
        warning "Terraform is already installed"
    else
        # Download and install Terraform
        wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
        echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
        sudo apt update
        sudo apt install terraform -y
        
        if [ $? -eq 0 ]; then
            log "✓ Terraform installed successfully"
            terraform --version
        else
            error "Failed to install Terraform"
        fi
    fi
}

install_jenkins() {
    log "Installing Jenkins..."
    
    if command_exists jenkins; then
        warning "Jenkins is already installed"
    else
        if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
            # Add Jenkins repository
            curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee \
                /usr/share/keyrings/jenkins-keyring.asc > /dev/null
            echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
                https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
                /etc/apt/sources.list.d/jenkins.list > /dev/null
            
            sudo apt-get update
            sudo apt-get install -y fontconfig openjdk-11-jre jenkins
            sudo systemctl start jenkins
            sudo systemctl enable jenkins
            
            log "✓ Jenkins installed successfully"
            log "Jenkins initial password:"
            sudo cat /var/lib/jenkins/secrets/initialAdminPassword
        else
            warning "Jenkins installation not automated for $OS. Please install manually."
        fi
    fi
}

# =============================================
# Main Installation Menu
# =============================================

show_menu() {
    clear
    echo "========================================="
    echo "  DevOps Environment Setup Script"
    echo "========================================="
    echo ""
    echo "1. Full Installation (Everything)"
    echo "2. Basic Tools Only (curl, git, vim, etc.)"
    echo "3. Docker + Docker Compose"
    echo "4. Kubernetes Tools (kubectl)"
    echo "5. Terraform"
    echo "6. Jenkins"
    echo "7. Custom Selection"
    echo "8. Exit"
    echo ""
    echo "========================================="
    echo -n "Enter your choice [1-8]: "
}

custom_selection() {
    echo ""
    echo "Select components to install:"
    echo "a. Basic Tools"
    echo "b. Git Configuration"
    echo "c. Bash Aliases"
    echo "d. Vim Configuration"
    echo "e. Docker"
    echo "f. kubectl"
    echo "g. Terraform"
    echo "h. Jenkins"
    echo "i. All of the above"
    echo "q. Back to main menu"
    echo ""
    echo -n "Enter your choices (e.g., a,b,c): "
    read choices
    
    IFS=',' read -ra ADDR <<< "$choices"
    for choice in "${ADDR[@]}"; do
        case $choice in
            a|A) install_basic_tools ;;
            b|B) setup_git ;;
            c|C) setup_bash_aliases ;;
            d|D) setup_vim ;;
            e|E) install_docker ;;
            f|F) install_kubectl ;;
            g|G) install_terraform ;;
            h|H) install_jenkins ;;
            i|I) 
                install_basic_tools
                setup_git
                setup_bash_aliases
                setup_vim
                install_docker
                install_kubectl
                install_terraform
                install_jenkins
                ;;
            q|Q) return ;;
            *) warning "Invalid choice: $choice" ;;
        esac
    done
}

# =============================================
# Main Script Execution
# =============================================

main() {
    # Create log directory if it doesn't exist
    mkdir -p logs
    
    log "Starting DevOps Environment Setup"
    log "Log file: $LOG_FILE"
    
    # Detect OS
    detect_os
    
    # Show menu and process choice
    while true; do
        show_menu
        read choice
        
        case $choice in
            1)
                log "Starting full installation..."
                install_basic_tools
                setup_git
                setup_bash_aliases
                setup_vim
                install_docker
                install_kubectl
                install_terraform
                install_jenkins
                break
                ;;
            2)
                install_basic_tools
                break
                ;;
            3)
                install_docker
                break
                ;;
            4)
                install_kubectl
                break
                ;;
            5)
                install_terraform
                break
                ;;
            6)
                install_jenkins
                break
                ;;
            7)
                custom_selection
                ;;
            8)
                log "Exiting setup script"
                exit 0
                ;;
            *)
                warning "Invalid option. Please enter 1-8"
                sleep 2
                ;;
        esac
        
        if [ $choice -ne 7 ]; then
            break
        fi
    done
    
    log "✅ Setup completed successfully!"
    
    # Show summary
    echo ""
    echo "========================================="
    echo "📦 Installation Summary"
    echo "========================================="
    echo ""
    echo "Installed components:"
    command_exists git && echo "  ✓ Git: $(git --version)" || echo "  ✗ Git not installed"
    command_exists docker && echo "  ✓ Docker: $(docker --version | head -n1)" || echo "  ✗ Docker not installed"
    command_exists kubectl && echo "  ✓ kubectl: $(kubectl version --client --short 2>/dev/null | cut -d' ' -f3)" || echo "  ✗ kubectl not installed"
    command_exists terraform && echo "  ✓ Terraform: $(terraform --version | head -n1)" || echo "  ✗ Terraform not installed"
    command_exists jenkins && echo "  ✓ Jenkins is installed" || echo "  ✗ Jenkins not installed"
    
    echo ""
    echo "📝 Next steps:"
    echo "1. Log out and log back in for group changes to take effect"
    echo "2. Test your setup:"
    echo "   - Run 'll' to test aliases"
    echo "   - Run 'git status' to test git"
    echo "   - Run 'docker run hello-world' to test Docker"
    echo ""
    echo "📄 Check the log file for details: $LOG_FILE"
    echo "========================================="
}

# Run main function
main "$@"
