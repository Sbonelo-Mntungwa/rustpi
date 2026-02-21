Vagrant.configure("2") do |config|
  config.vm.box = "spox/ubuntu-arm"
  config.vm.box_version = "1.0.0"
  config.vm.network "private_network", ip: "192.168.56.11"
  
  config.vm.provider "vmware_desktop" do |vmware|
    vmware.gui = false
    vmware.allowlist_verified = true
    vmware.vmx["memsize"] = "8192"
    vmware.vmx["numvcpus"] = "4"
  end
  
  # Install system dependencies
  config.vm.provision "shell", privileged: true, inline: <<-SHELL
    set -e
    echo "=== Installing build dependencies ==="
    apt-get update
    apt-get install -y \
      build-essential git bc bison flex libssl-dev \
      libncurses-dev libelf-dev gcc-aarch64-linux-gnu \
      binutils-aarch64-linux-gnu parted dosfstools e2fsprogs \
      device-tree-compiler wget curl kpartx musl-tools
  SHELL
  
  # Install Rust and setup build environment
  config.vm.provision "shell", privileged: false, inline: <<-SHELL
    set -e
    echo "=== Installing Rust ==="
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source ~/.cargo/env
    rustup target add aarch64-unknown-linux-gnu
    rustup target add aarch64-unknown-linux-musl
    
    mkdir -p ~/.cargo
    cat > ~/.cargo/config.toml << 'CARGO'
[target.aarch64-unknown-linux-musl]
linker = "aarch64-linux-gnu-gcc"
CARGO

    # Create project directory
    mkdir -p ~/pi-distro
    
    # Copy scripts from synced folder
    if [ -d "/vagrant/scripts" ]; then
      cp -r /vagrant/scripts ~/pi-distro/
      chmod +x ~/pi-distro/scripts/*.sh
      echo "=== Build scripts installed ==="
    fi
  SHELL
end
