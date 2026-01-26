# -*- mode: ruby -*-
# vi: set ft=ruby :

# RustPi Build Environment
# 
# This Vagrantfile creates an Ubuntu VM with all tools needed to build RustPi.
# 
# Usage:
#   vagrant up        # Start and provision the VM
#   vagrant ssh       # SSH into the VM
#   vagrant halt      # Stop the VM
#   vagrant destroy   # Delete the VM
#
# Inside the VM, the project is mounted at /vagrant
# Run: cd /vagrant && ./scripts/build-all.sh

Vagrant.configure("2") do |config|
  # Ubuntu 22.04 LTS (Jammy)
  config.vm.box = "ubuntu/jammy64"
  
  # VM name
  config.vm.define "rustpi-builder"
  config.vm.hostname = "rustpi-builder"

  # VM resources
  config.vm.provider "virtualbox" do |vb|
    vb.name = "RustPi Builder"
    vb.memory = "4096"
    vb.cpus = 4
    
    # Enable nested virtualization if needed
    vb.customize ["modifyvm", :id, "--nested-hw-virt", "on"]
  end

  # VMware provider (alternative)
  config.vm.provider "vmware_desktop" do |vmware|
    vmware.vmx["displayname"] = "RustPi Builder"
    vmware.vmx["memsize"] = "4096"
    vmware.vmx["numvcpus"] = "4"
  end

  # Synced folder - project root
  config.vm.synced_folder ".", "/vagrant", type: "virtualbox"

  # Output folder for built images (persists on host)
  config.vm.synced_folder "./output", "/home/vagrant/output", create: true

  # Provisioning script
  config.vm.provision "shell", inline: <<-SHELL
    set -e
    
    echo "============================================="
    echo "  RustPi Build Environment Setup"
    echo "============================================="
    
    # Update system
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get upgrade -y
    
    # Install build dependencies
    echo "[*] Installing build tools..."
    apt-get install -y \
      build-essential \
      gcc-aarch64-linux-gnu \
      g++-aarch64-linux-gnu \
      git \
      wget \
      curl \
      parted \
      dosfstools \
      e2fsprogs \
      kpartx \
      qemu-user-static \
      binfmt-support \
      debootstrap \
      libncurses-dev \
      flex \
      bison \
      libssl-dev \
      bc \
      rsync \
      cpio \
      unzip \
      fdisk

    # Install Rust for vagrant user
    echo "[*] Installing Rust..."
    sudo -u vagrant bash -c 'curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y'
    
    # Add ARM64 musl target
    sudo -u vagrant bash -c 'source ~/.cargo/env && rustup target add aarch64-unknown-linux-musl'
    
    # Install musl tools for static linking
    apt-get install -y musl-tools
    
    # Setup cross-compilation linker for musl
    mkdir -p /home/vagrant/.cargo
    cat > /home/vagrant/.cargo/config.toml << 'EOF'
[target.aarch64-unknown-linux-musl]
linker = "aarch64-linux-gnu-gcc"
EOF
    chown -R vagrant:vagrant /home/vagrant/.cargo

    # Create output directory
    mkdir -p /home/vagrant/output
    chown vagrant:vagrant /home/vagrant/output

    # Add vagrant to disk group for loop devices
    usermod -aG disk vagrant

    # Setup environment in bashrc
    cat >> /home/vagrant/.bashrc << 'EOF'

# RustPi Build Environment
export PATH="$HOME/.cargo/bin:$PATH"
export CROSS_COMPILE=aarch64-linux-gnu-
export ARCH=arm64

# Aliases
alias build='cd /vagrant && ./scripts/build-all.sh'
alias clean='cd /vagrant && ./scripts/clean.sh'

echo ""
echo "=========================================="
echo "  RustPi Build Environment Ready!"
echo "=========================================="
echo ""
echo "Commands:"
echo "  build          - Build RustPi image"
echo "  clean          - Clean build artifacts"
echo "  cd /vagrant    - Go to project directory"
echo ""
EOF

    echo ""
    echo "============================================="
    echo "  Setup Complete!"
    echo "============================================="
    echo ""
    echo "Run 'vagrant ssh' to enter the VM"
    echo "Then run 'build' to start building"
    echo ""
  SHELL

  # Message after vagrant up
  config.vm.post_up_message = <<-MESSAGE
  
  =============================================
    RustPi Build Environment Ready!
  =============================================
  
  SSH into the VM:
    vagrant ssh
  
  Build RustPi:
    build
    
  Or manually:
    cd /vagrant
    ./scripts/build-all.sh
  
  Output will be in ./output/ on your host machine.
  
  MESSAGE
end
