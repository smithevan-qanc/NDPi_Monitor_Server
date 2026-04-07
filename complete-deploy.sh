#!/bin/bash
# NDPi Monitor Complete Production Deployment Script
#
#   This is the All-In-One Script to install NDPi-Server
#   NDPi-Monitor v2.1.0 (2-21-2026)
#

set -e  # Exit on any error

# Set the BOX_BAR characters to the length of the version number
BOX_BAR='━━━━━'
Version='3.1.0'
Version_Date='03-05-2026'

# Set the IP below before execution.
IP="192.168.1.57"
USER="ndpi-server"
IP_PassedIn=false

# Colors for output
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m' # No Color
INFO_COLOR='\033[1;37m'


# Logging functions
log_info() {
    echo -e "${BLUE}     INFO ╮${NC}"
    echo -e "${BLUE}          ╰⸺▶ ${INFO_COLOR}$1${NC}"
}
ext_info() {
    echo -e "${BLUE}          ╰⸺▶ ${INFO_COLOR}$1${NC}"
}

log_success() {
    echo -e "${GREEN}  SUCCESS ╮${NC}"
    echo -e "${GREEN}          ╰⸺▶ ${INFO_COLOR}$1${NC}"
}
ext_success() {
    echo -e "${GREEN}          ╰⸺▶ ${INFO_COLOR}$1${NC}"
}

log_warning() {
    echo -e "${YELLOW}  WARNING ╮${NC}"
    echo -e "${YELLOW}          ╰⸺▶ ${INFO_COLOR}$1${NC}"
}
ext_warning() {
    echo -e "${YELLOW}          ╰⸺▶ ${INFO_COLOR}$1${NC}"
}

log_error() {
    echo -e "${RED}    ERROR ╮${NC}"
    echo -e "${RED}          ╰⸺▶ ${INFO_COLOR}$1${NC}"
}
ext_error() {
    echo -e "${RED}          ╰⸺▶ ${INFO_COLOR}$1${NC}"
}

# Default configuration
LOCAL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REMOTE_DIR="/home/${USER}/ndpi-monitor"
NDI_SDK_URL="https://downloads.ndi.tv/SDK/NDI_SDK_Linux/Install_NDI_SDK_v5_Linux.tar.gz"
NDI_SDK_DIR="/opt/NDI SDK for Linux"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --ip)
            IP="$2"
            IP_PassedIn=true
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Complete NDPi Monitor production deployment script"
            echo ""
            echo "Options:"
            echo "  --ip IP        Server IP address (default: ${IP})"
            echo "  --help         Show this help message"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Prompt for confirmation if IP was not explicitly passed
if [[ "$IP_PassedIn" == false ]]; then
    echo ""
    echo "⚠️  Verify IP Address"
    echo -e "${YELLOW}   This installation will execute on ${NC}${BLUE}${IP}${NC}${NC}"
    read -rp "   Continue? (y/n) " confirm
    if [[ "$confirm" != [yY] ]]; then
        echo -e "${RED}Deployment cancelled.${NC}"
        exit 1
    fi
    echo ""
    echo -e "${GREEN}   Continuing...${NC}"
    echo "   To prevent this message from appearing..."
    echo -e "   • Use \033[0;36m--ip${NC}\033[1m ${IP}${NC} when calling this script"
    echo ""
    sleep 8
fi

#
# Continue to main() function.....
#

deploy_ndi_sdk() {
    log_info "Deploying NDI SDK..."

    # Check if NDI SDK is already installed
    if ssh "${USER}@${IP}" "[ -f '${NDI_SDK_DIR}/include/Processing.NDI.Lib.h' ]"; then
        log_warning "NDI SDK already installed"
        return
    fi

    # Download and install NDI SDK
    log_info "Downloading and installing NDI SDK..."
    ssh "${USER}@${IP}" "
        cd /tmp && \
        rm -f ndi-sdk.tar.gz Install_NDI_SDK_v5_Linux.sh && \
        wget -O ndi-sdk.tar.gz '${NDI_SDK_URL}' && \
        tar -xzf ndi-sdk.tar.gz && \
        chmod +x Install_NDI_SDK_v5_Linux.sh && \
        yes | sudo ./Install_NDI_SDK_v5_Linux.sh && \
        sudo rm -rf '${NDI_SDK_DIR}' && \
        sudo mv 'NDI SDK for Linux' '${NDI_SDK_DIR}'
    "

    log_success "NDI SDK deployed"
}

compile_ndi_discover() {
    log_info "Compiling NDI discovery tool..."

    ssh "${USER}@${IP}" "
        cd '${REMOTE_DIR}' && \
        g++ -std=c++11 -pthread -I'${NDI_SDK_DIR}/include' \
            -L'${NDI_SDK_DIR}/lib/aarch64-rpi4-linux-gnueabi' \
            -Wl,--allow-shlib-undefined -Wl,--as-needed \
            ndi-discover.cpp -lndi -ldl -o ndi-discover && \
        cp '${NDI_SDK_DIR}/lib/aarch64-rpi4-linux-gnueabi/libndi.so.5.6.1' ./libndi.so.5
    "

    log_success "NDI discovery tool compiled"
}

deploy_server() {
    log_info "Deploying program files..."

    rsync -avz \
        --exclude 'Archive' \
        --exclude 'client' \
        --exclude 'node_modules' \
        --exclude '.git' \
        --exclude '.DS_Store' \
        --exclude '*.log' \
        --exclude '*.md' \
        --exclude '*.sh' \
        "${LOCAL_DIR}/" "${USER}@${IP}:${REMOTE_DIR}/"

    log_success "Program files deployed."
}

install_system_deps() {
    log_info "Installing system dependencies..."

    ssh "${USER}@${IP}" "
        sudo apt update && \
        sudo apt install -y xserver-xorg \
        xinit \
        plymouth \
        plymouth-themes \
        avahi-daemon \
        git \
        curl \
        wget \
        fbi \
        unclutter \
        openbox \
        lightdm
    "

    log_success "System dependencies installed"
}

install_nodejs() {
    log_info "Installing Node.js..."

    if ssh "${USER}@${IP}" "node --version >/dev/null 2>&1"; then
        log_warning "Node.js already installed"
        return
    fi

    ssh "${USER}@${IP}" "
        curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash - && \
        sudo apt-get install -y nodejs
    "

    log_success "Node.js installed"
}

install_node_deps() {
    log_info "Installing Node Package Manager..."
    ext_info "Installing DOM Xml Parser..."
    ext_info "Installing Bonjour..."

    ssh "${USER}@${IP}" "
        cd '${REMOTE_DIR}' && \
        npm install && \
        npm install @xmldom/xmldom && \
        npm install bonjour
    "

    log_success "Node.js dependencies installed"
}

configure_services() {
    log_info "Configuring UI..."

    scp "config/kiosk.service" "${USER}@${IP}:/tmp/kiosk.service"
    scp "config/.xinitrc" "${USER}@${IP}:/tmp/.xinitrc"
    scp "config/autostart" "${USER}@${IP}:/tmp/autostart"

    ssh "${USER}@${IP}" "
        sudo cp /tmp/kiosk.service /etc/systemd/system/ && \
        sudo cp /tmp/.xinitrc /home/${USER}/.xinitrc && \
        mkdir -p /home/${USER}/.config/openbox && \
        sudo cp /tmp/autostart /home/${USER}/.config/openbox/autostart && \
        sudo chown ${USER}:${USER} /home/${USER}/.xinitrc && \
        sudo chown ${USER}:${USER} /home/${USER}/.config/openbox/autostart && \
        sudo systemctl daemon-reload && \
        sudo systemctl enable kiosk.service
    "

    scp "config/lightdm-autologin.conf" "${USER}@${IP}:/tmp/lightdm-autologin.conf"
    ssh "${USER}@${IP}" "
        sudo mkdir -p /etc/lightdm/lightdm.conf.d && \
        sudo cp /tmp/lightdm-autologin.conf /etc/lightdm/lightdm.conf.d/ && \
        sudo systemctl enable lightdm
    "

    log_success "UI configured"
}

# Function to enable mDNS
enable_mdns() {
    log_info "Enabling mDNS..."

    ssh "${USER}@${IP}" "
        sudo systemctl enable avahi-daemon && \
        sudo systemctl start avahi-daemon
    "

    log_success "mDNS enabled"
}

# Function to create and start systemd service
create_systemd_service() {
    log_info "Creating Node.js Server service file..."

    ssh "${USER}@${IP}" "
        sudo tee /etc/systemd/system/ndpi-monitor.service > /dev/null << EOF
[Unit]
Description=NDPi Monitor Web Server
After=network.target

[Service]
Type=simple
User=${USER}
WorkingDirectory=${REMOTE_DIR}
ExecStart=/usr/bin/node ${REMOTE_DIR}/server.js
Restart=always
RestartSec=10
Environment=PATH=/usr/bin:/usr/local/bin
Environment=LD_LIBRARY_PATH=${REMOTE_DIR}

[Install]
WantedBy=multi-user.target
EOF

        sudo systemctl daemon-reload && \
        sudo systemctl enable ndpi-monitor.service && \
        sudo systemctl start ndpi-monitor.service
    "

    log_success "Node.js Server service file created and enabled"
}

# Function to test deployment
test_deployment() {
    log_info "Testing deployment..."

    # Wait for service to start
    sleep 5

    ssh "${USER}@${IP}" "
        cd '${REMOTE_DIR}' && \
        LD_LIBRARY_PATH='${REMOTE_DIR}' ./ndi-discover 1
    "

    ssh "${USER}@${IP}" "
        curl -s http://localhost:3000/api/sources && echo '' && \
        curl -s http://localhost:3000/api/ndi-sources
    "

    log_success "Deployment testing completed"
}

# Main execution
main() {
    echo -e "${BLUE}┏━━━━━${BOX_BAR}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
    echo -e "${BLUE}┃${NC}${INFO_COLOR}     Nᗪᑭi - PROGRAM INSTALLATION - SERVER - ver ${Version}     ${NC}${BLUE}┃${NC}"
    echo -e "${BLUE}┗━━━━━${BOX_BAR}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}"

    log_info "Device: ${USER}@${IP}"
    ext_info "Local directory: ${LOCAL_DIR}"

    # Deploy server files
    deploy_server

    # Deploy NDI SDK
    deploy_ndi_sdk

    # Step 4: Install system dependencies
    install_system_deps

    # Step 5: Install Node.js
    install_nodejs

    # Step 7: Compile NDI discovery tool
    compile_ndi_discover

    # Step 8: Install Node.js dependencies
    install_node_deps

    # Step 9: Configure kiosk mode
    configure_services

    # Step 10: Enable mDNS
    enable_mdns

    # Step 11: Create systemd service
    create_systemd_service

    # Step 12: Test deployment
    test_deployment
    
    echo ""
    echo ""
    echo -e "${GREEN}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
    echo -e "${GREEN}┃${NC}${INFO_COLOR}               Deployment completed${NC} ${GREEN}SUCCESSFULLY ${NC}              ${GREEN}┃${NC}"
    echo -e "${GREEN}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}"
    echo -e "${INFO_COLOR}  —▷ ${NC}\033[1;36mServer online at: ${NC}${INFO_COLOR}http://${IP}:3000 ${NC}"
    echo -e "${INFO_COLOR}  —▷ ${NC}${YELLOW}Sending reboot command in 5s...${NC}"
    sleep 5
    echo ""
    sleep 1
    ssh "${USER}@${IP}" "sudo reboot"
}

# Run main function
main "$@"