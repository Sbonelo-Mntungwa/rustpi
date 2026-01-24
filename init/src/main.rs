//! RustPi Init System
//!
//! A minimal init system (PID 1) for the RustPi Linux distribution.
//! Handles system initialization, service management, and process supervision.

use nix::mount::{mount, MsFlags};
use nix::sys::wait::{waitpid, WaitPidFlag, WaitStatus};
use nix::unistd::{chown, execv, fork, sethostname, ForkResult, Pid, Uid, Gid};
use std::ffi::CString;
use std::fs::{self, File, OpenOptions};
use std::io::{Read, Write};
use std::os::unix::fs::symlink;
use std::path::Path;
use std::process::Command;
use std::thread;
use std::time::Duration;

const VERSION: &str = "0.5.0";
const HOSTNAME_FILE: &str = "/etc/hostname";
const DEFAULT_HOSTNAME: &str = "rustpi";

fn main() {
    // Verify we're running as PID 1
    if std::process::id() != 1 {
        eprintln!("[init] Warning: Not running as PID 1 (running as PID {})", std::process::id());
        eprintln!("[init] This binary is designed to be the init process");
    }

    print_banner();

    // Initialize the system
    if let Err(e) = init_system() {
        eprintln!("[init] FATAL: System initialization failed: {}", e);
        emergency_shell();
    }

    // Main loop: reap zombie processes
    println!("[init] System ready. Entering main loop.");
    loop {
        match waitpid(Pid::from_raw(-1), Some(WaitPidFlag::WNOHANG)) {
            Ok(WaitStatus::Exited(pid, status)) => {
                println!("[init] Process {} exited with status {}", pid, status);
            }
            Ok(WaitStatus::Signaled(pid, signal, _)) => {
                println!("[init] Process {} killed by signal {:?}", pid, signal);
            }
            _ => {}
        }
        thread::sleep(Duration::from_millis(100));
    }
}

fn print_banner() {
    println!("=============================================");
    println!("  RustPi Init v{}", VERSION);
    println!("=============================================");
}

fn init_system() -> Result<(), Box<dyn std::error::Error>> {
    // Mount essential filesystems
    mount_filesystems()?;
    println!("[init] Mounted filesystems");

    // Setup hostname
    setup_hostname()?;

    // Setup device nodes
    setup_devices()?;
    println!("[init] Device nodes ready");

    // Load kernel modules for networking
    load_kernel_modules();

    // Setup networking
    setup_networking();

    // Generate SSH host keys if needed
    setup_ssh_keys();

    // Start SSH server
    start_ssh_server();

    // Spawn login shell on console
    spawn_shell();

    Ok(())
}

fn mount_filesystems() -> Result<(), Box<dyn std::error::Error>> {
    // Create mount points if they don't exist
    for dir in &["/proc", "/sys", "/dev", "/dev/pts", "/tmp", "/run"] {
        fs::create_dir_all(dir).ok();
    }

    // Mount proc
    mount(
        Some("proc"),
        "/proc",
        Some("proc"),
        MsFlags::MS_NOSUID | MsFlags::MS_NOEXEC | MsFlags::MS_NODEV,
        None::<&str>,
    )?;

    // Mount sysfs
    mount(
        Some("sysfs"),
        "/sys",
        Some("sysfs"),
        MsFlags::MS_NOSUID | MsFlags::MS_NOEXEC | MsFlags::MS_NODEV,
        None::<&str>,
    )?;

    // Mount devtmpfs
    mount(
        Some("devtmpfs"),
        "/dev",
        Some("devtmpfs"),
        MsFlags::MS_NOSUID,
        Some("mode=0755"),
    )?;

    // Mount devpts for PTY support
    mount(
        Some("devpts"),
        "/dev/pts",
        Some("devpts"),
        MsFlags::MS_NOSUID | MsFlags::MS_NOEXEC,
        Some("mode=0620,ptmxmode=0666"),
    )?;

    // Mount tmpfs on /tmp
    mount(
        Some("tmpfs"),
        "/tmp",
        Some("tmpfs"),
        MsFlags::MS_NOSUID | MsFlags::MS_NODEV,
        Some("mode=1777"),
    )?;

    // Mount tmpfs on /run
    mount(
        Some("tmpfs"),
        "/run",
        Some("tmpfs"),
        MsFlags::MS_NOSUID | MsFlags::MS_NODEV,
        Some("mode=0755"),
    )?;

    Ok(())
}

fn setup_hostname() -> Result<(), Box<dyn std::error::Error>> {
    let hostname = if Path::new(HOSTNAME_FILE).exists() {
        fs::read_to_string(HOSTNAME_FILE)
            .unwrap_or_else(|_| DEFAULT_HOSTNAME.to_string())
            .trim()
            .to_string()
    } else {
        DEFAULT_HOSTNAME.to_string()
    };

    sethostname(&hostname)?;
    println!("[init] Hostname set to: {}", hostname);

    Ok(())
}

fn setup_devices() -> Result<(), Box<dyn std::error::Error>> {
    // Create essential device symlinks
    let dev_links = [
        ("/dev/fd", "/proc/self/fd"),
        ("/dev/stdin", "/proc/self/fd/0"),
        ("/dev/stdout", "/proc/self/fd/1"),
        ("/dev/stderr", "/proc/self/fd/2"),
    ];

    for (link, target) in &dev_links {
        if !Path::new(link).exists() {
            symlink(target, link).ok();
        }
    }

    // Create /dev/ptmx symlink if needed
    if !Path::new("/dev/ptmx").exists() {
        symlink("/dev/pts/ptmx", "/dev/ptmx").ok();
    }

    Ok(())
}

fn load_kernel_modules() {
    println!("[init] Loading kernel modules...");

    // Common USB-Ethernet drivers
    let modules = [
        "dm9601",      // Davicom DM9601
        "asix",        // ASIX AX88xxx
        "cdc_ether",   // CDC Ethernet
        "r8152",       // Realtek RTL8152/RTL8153
        "smsc95xx",    // SMSC LAN95xx
    ];

    for module in &modules {
        let result = Command::new("/sbin/modprobe")
            .arg(module)
            .output();

        match result {
            Ok(output) if output.status.success() => {
                println!("[init] Loaded module: {}", module);
            }
            _ => {
                // Module might not exist or already loaded, that's okay
            }
        }
    }

    // Wait for devices to settle
    thread::sleep(Duration::from_secs(2));
}

fn setup_networking() {
    println!("[init] Configuring network...");

    // Find available network interface
    let interface = find_network_interface();

    if let Some(iface) = interface {
        println!("[init] Found network interface: {}", iface);

        // Bring interface up
        Command::new("/sbin/ifconfig")
            .args([&iface, "up"])
            .output()
            .ok();

        // Start DHCP client
        let dhcp_result = Command::new("/sbin/udhcpc")
            .args([
                "-i", &iface,
                "-s", "/usr/share/udhcpc/default.script",
                "-p", "/var/run/udhcpc.pid",
                "-b",  // Background after lease
            ])
            .output();

        match dhcp_result {
            Ok(output) if output.status.success() => {
                println!("[init] DHCP client started on {}", iface);
            }
            Ok(output) => {
                eprintln!("[init] DHCP failed: {}", String::from_utf8_lossy(&output.stderr));
            }
            Err(e) => {
                eprintln!("[init] Failed to start DHCP: {}", e);
            }
        }

        // Wait for IP address
        thread::sleep(Duration::from_secs(3));

        // Show IP address
        if let Ok(output) = Command::new("/sbin/ifconfig").arg(&iface).output() {
            let output_str = String::from_utf8_lossy(&output.stdout);
            for line in output_str.lines() {
                if line.contains("inet ") {
                    println!("[init] {}", line.trim());
                }
            }
        }
    } else {
        eprintln!("[init] No network interface found");
    }
}

fn find_network_interface() -> Option<String> {
    // Check for common interface names
    let interfaces = ["eth0", "usb0", "enp0s", "end0"];

    for iface in &interfaces {
        let path = format!("/sys/class/net/{}", iface);
        if Path::new(&path).exists() {
            return Some(iface.to_string());
        }
    }

    // Scan /sys/class/net for any non-loopback interface
    if let Ok(entries) = fs::read_dir("/sys/class/net") {
        for entry in entries.flatten() {
            let name = entry.file_name().to_string_lossy().to_string();
            if name != "lo" && !name.starts_with("wlan") {
                return Some(name);
            }
        }
    }

    None
}

fn setup_ssh_keys() {
    let key_types = [
        ("rsa", "/etc/dropbear/dropbear_rsa_host_key"),
        ("ecdsa", "/etc/dropbear/dropbear_ecdsa_host_key"),
    ];

    // Create dropbear directory
    fs::create_dir_all("/etc/dropbear").ok();

    for (key_type, key_path) in &key_types {
        if !Path::new(key_path).exists() {
            println!("[init] Generating {} host key...", key_type);
            Command::new("/bin/dropbearkey")
                .args(["-t", key_type, "-f", key_path])
                .output()
                .ok();
        }
    }
}

fn start_ssh_server() {
    println!("[init] Starting SSH server...");

    match unsafe { fork() } {
        Ok(ForkResult::Child) => {
            // Child process - start dropbear
            let args = [
                CString::new("/bin/dropbear").unwrap(),
                CString::new("-F").unwrap(),  // Foreground
                CString::new("-E").unwrap(),  // Log to stderr
                CString::new("-R").unwrap(),  // Create host keys if needed
            ];

            let arg_refs: Vec<&CString> = args.iter().collect();
            execv(&args[0], &arg_refs).ok();
            std::process::exit(1);
        }
        Ok(ForkResult::Parent { child }) => {
            println!("[init] SSH server started (PID {})", child);
        }
        Err(e) => {
            eprintln!("[init] Failed to fork SSH server: {}", e);
        }
    }
}

fn spawn_shell() {
    println!("[init] Spawning login shell...");

    match unsafe { fork() } {
        Ok(ForkResult::Child) => {
            // Child process - spawn shell
            let args = [
                CString::new("/bin/sh").unwrap(),
                CString::new("-l").unwrap(),  // Login shell
            ];

            // Set environment variables
            std::env::set_var("HOME", "/root");
            std::env::set_var("TERM", "linux");
            std::env::set_var("PATH", "/bin:/sbin:/usr/bin:/usr/sbin");
            std::env::set_var("SHELL", "/bin/sh");

            let arg_refs: Vec<&CString> = args.iter().collect();
            execv(&args[0], &arg_refs).ok();
            std::process::exit(1);
        }
        Ok(ForkResult::Parent { child }) => {
            println!("[init] Shell spawned (PID {})", child);
        }
        Err(e) => {
            eprintln!("[init] Failed to spawn shell: {}", e);
        }
    }
}

fn emergency_shell() {
    eprintln!("[init] Dropping to emergency shell...");

    // Try to spawn a shell directly
    let args = [
        CString::new("/bin/sh").unwrap(),
    ];
    let arg_refs: Vec<&CString> = args.iter().collect();
    execv(&args[0], &arg_refs).ok();

    // If that fails, just loop
    loop {
        thread::sleep(Duration::from_secs(1));
    }
}
