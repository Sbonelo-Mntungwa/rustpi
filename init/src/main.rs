use nix::mount::{mount, MsFlags};
use nix::sys::wait::{waitpid, WaitPidFlag, WaitStatus};
use nix::unistd::{execv, fork, ForkResult, Pid, sethostname, setsid};
use std::ffi::CString;
use std::fs::{self, OpenOptions};
use std::io::{self, Write};
use std::os::unix::io::AsRawFd;
use std::process::Command;
use std::thread;
use std::time::Duration;

fn main() {
    if std::process::id() != 1 {
        eprintln!("[init] Error: Must run as PID 1");
        std::process::exit(1);
    }

    println!();
    println!("=============================================");
    println!("  RustPi Init v0.5.0");
    println!("=============================================");
    println!();

    let _ = mount_filesystems();
    let _ = setup_hostname();
    let _ = setup_devices();
    print_system_info();
    
    // Start networking
    setup_networking();
    
    // Start SSH server
    start_ssh_server();
    
    // Start shell
    spawn_shell();

    loop {
        match waitpid(Pid::from_raw(-1), Some(WaitPidFlag::WNOHANG)) {
            Ok(WaitStatus::Exited(pid, _)) | Ok(WaitStatus::Signaled(pid, _, _)) => {
                println!("[init] Process {} exited, respawning shell...", pid);
                thread::sleep(Duration::from_secs(2));
                spawn_shell();
            }
            _ => {}
        }
        thread::sleep(Duration::from_millis(100));
    }
}

fn mount_filesystems() -> Result<(), String> {
    println!("[init] Mounting filesystems...");

    print!("[init]   /proc... ");
    io::stdout().flush().ok();
    match mount(Some("proc"), "/proc", Some("proc"), MsFlags::empty(), None::<&str>) {
        Ok(_) => println!("OK"),
        Err(e) => println!("SKIP ({})", e),
    }

    print!("[init]   /sys... ");
    io::stdout().flush().ok();
    match mount(Some("sysfs"), "/sys", Some("sysfs"), MsFlags::empty(), None::<&str>) {
        Ok(_) => println!("OK"),
        Err(e) => println!("SKIP ({})", e),
    }

    print!("[init]   /dev... ");
    io::stdout().flush().ok();
    if fs::read_dir("/dev").map(|mut d| d.next().is_some()).unwrap_or(false) {
        println!("ALREADY MOUNTED");
    } else {
        match mount(Some("devtmpfs"), "/dev", Some("devtmpfs"), MsFlags::empty(), None::<&str>) {
            Ok(_) => println!("OK"),
            Err(e) => println!("SKIP ({})", e),
        }
    }

    print!("[init]   /dev/pts... ");
    io::stdout().flush().ok();
    let _ = fs::create_dir_all("/dev/pts");
    match mount(Some("devpts"), "/dev/pts", Some("devpts"), MsFlags::empty(), Some("gid=5,mode=620,ptmxmode=0666")) {
        Ok(_) => println!("OK"),
        Err(e) => println!("SKIP ({})", e),
    }

    print!("[init]   /tmp... ");
    io::stdout().flush().ok();
    match mount(Some("tmpfs"), "/tmp", Some("tmpfs"), MsFlags::empty(), None::<&str>) {
        Ok(_) => println!("OK"),
        Err(e) => println!("SKIP ({})", e),
    }

    print!("[init]   /run... ");
    io::stdout().flush().ok();
    match mount(Some("tmpfs"), "/run", Some("tmpfs"), MsFlags::empty(), None::<&str>) {
        Ok(_) => println!("OK"),
        Err(e) => println!("SKIP ({})", e),
    }

    Ok(())
}

fn setup_hostname() -> Result<(), nix::Error> {
    let hostname = fs::read_to_string("/etc/hostname")
        .unwrap_or_else(|_| "rustpi".to_string())
        .trim()
        .to_string();
    print!("[init] Setting hostname: {}... ", hostname);
    io::stdout().flush().ok();
    sethostname(&hostname)?;
    println!("OK");
    Ok(())
}

fn setup_devices() -> Result<(), io::Error> {
    println!("[init] Setting up device nodes...");

    let symlinks = [
        ("/dev/fd", "/proc/self/fd"),
        ("/dev/stdin", "/proc/self/fd/0"),
        ("/dev/stdout", "/proc/self/fd/1"),
        ("/dev/stderr", "/proc/self/fd/2"),
    ];

    for (link, target) in symlinks {
        if !std::path::Path::new(link).exists() {
            let _ = std::os::unix::fs::symlink(target, link);
        }
    }

    if !std::path::Path::new("/dev/ptmx").exists() {
        let _ = std::os::unix::fs::symlink("/dev/pts/ptmx", "/dev/ptmx");
    }

    Ok(())
}

fn print_system_info() {
    println!();
    if let Ok(v) = fs::read_to_string("/proc/version") {
        println!("[init] Kernel: {}", v.split_whitespace().take(3).collect::<Vec<_>>().join(" "));
    }
    if let Ok(m) = fs::read_to_string("/proc/meminfo") {
        for line in m.lines().take(2) {
            println!("[init] {}", line);
        }
    }
    println!();
}

fn setup_networking() {
    println!("[init] Setting up networking...");

    // Bring up loopback
    print!("[init]   Loopback (lo)... ");
    io::stdout().flush().ok();
    let lo_result = Command::new("/bin/ifconfig")
        .args(["lo", "127.0.0.1", "netmask", "255.0.0.0", "up"])
        .status();
    match lo_result {
        Ok(s) if s.success() => println!("OK"),
        _ => println!("FAILED"),
    }

    // List available network interfaces
    println!("[init]   Available interfaces:");
    if let Ok(entries) = fs::read_dir("/sys/class/net") {
        for entry in entries.flatten() {
            let name = entry.file_name().to_string_lossy().to_string();
            println!("[init]     - {}", name);
        }
    }

    // Try to find any non-loopback network interface
    let mut eth_interface: Option<String> = None;
    if let Ok(entries) = fs::read_dir("/sys/class/net") {
        for entry in entries.flatten() {
            let name = entry.file_name().to_string_lossy().to_string();
            if name != "lo" {
                eth_interface = Some(name);
                break;
            }
        }
    }

    let iface = match eth_interface {
        Some(i) => i,
        None => {
            println!("[init]   No ethernet interface found!");
            return;
        }
    };

    println!("[init]   Using interface: {}", iface);

    // Bring up interface
    print!("[init]   Bringing up {}... ", iface);
    io::stdout().flush().ok();
    let _ = Command::new("/bin/ifconfig")
        .args([&iface, "up"])
        .status();
    println!("OK");

    print!("[init]   Getting IP via DHCP... ");
    io::stdout().flush().ok();
    let dhcp_result = Command::new("/bin/udhcpc")
        .args(["-i", &iface, "-n", "-q", "-s", "/etc/udhcpc/default.script"])
        .status();
    match dhcp_result {
        Ok(s) if s.success() => println!("OK"),
        _ => {
            println!("FAILED - trying static IP fallback");

            print!("[init]   Assigning 192.168.1.100/24... ");
            io::stdout().flush().ok();
            let static_result = Command::new("/bin/ifconfig")
                .args([&iface, "192.168.1.100", "netmask", "255.255.255.0", "up"])
                .status();
            match static_result {
                Ok(s) if s.success() => println!("OK"),
                _ => println!("FAILED"),
            }

            print!("[init]   Adding default route via 192.168.1.1... ");
            io::stdout().flush().ok();
            let route_result = Command::new("/bin/ip")
                .args(["route", "add", "default", "via", "192.168.1.1"])
                .status();
            match route_result {
                Ok(s) if s.success() => println!("OK"),
                _ => println!("FAILED"),
            }
        }
    }

    // Show IP address
    if let Ok(output) = Command::new("/bin/ifconfig").arg(&iface).output() {
        let output_str = String::from_utf8_lossy(&output.stdout);
        for line in output_str.lines() {
            if line.contains("inet ") || line.contains("inet addr") {
                println!("[init]   {}", line.trim());
            }
        }
    }
}

fn start_ssh_server() {
    println!("[init] Starting SSH server...");

    // Create host keys if they don't exist
    let key_path = "/etc/dropbear/dropbear_rsa_host_key";
    if !std::path::Path::new(key_path).exists() {
        print!("[init]   Generating host key... ");
        io::stdout().flush().ok();
        let _ = fs::create_dir_all("/etc/dropbear");
        let keygen = Command::new("/bin/dropbearkey")
            .args(["-t", "rsa", "-f", key_path])
            .status();
        match keygen {
            Ok(s) if s.success() => println!("OK"),
            _ => println!("FAILED"),
        }
    }

    // Start dropbear SSH server
    print!("[init]   Starting dropbear... ");
    io::stdout().flush().ok();
    let dropbear = Command::new("/bin/dropbear")
        .args(["-R", "-E", "-p", "0.0.0.0:22"])
        .spawn();
    match dropbear {
        Ok(_) => println!("OK (port 22)"),
        Err(e) => println!("FAILED ({})", e),
    }

    // Also start telnetd as backup
    print!("[init]   Starting telnetd... ");
    io::stdout().flush().ok();
    let telnetd = Command::new("/bin/telnetd")
        .args(["-l", "/bin/sh"])
        .spawn();
    match telnetd {
        Ok(_) => println!("OK (port 23)"),
        Err(e) => println!("FAILED ({})", e),
    }
}


fn spawn_shell() -> Option<Pid> {
    println!("[init] Starting shell...");

    match unsafe { fork() } {
        Ok(ForkResult::Parent { child }) => Some(child),
        Ok(ForkResult::Child) => {
            let _ = setsid();

            if let Ok(console) = OpenOptions::new().read(true).write(true).open("/dev/console") {
                let fd = console.as_raw_fd();
                unsafe {
                    libc::ioctl(fd, libc::TIOCSCTTY, 0);
                    libc::dup2(fd, 0);
                    libc::dup2(fd, 1);
                    libc::dup2(fd, 2);
                }
            }

            std::env::set_var("HOME", "/root");
            std::env::set_var("PATH", "/bin:/sbin:/usr/bin:/usr/sbin");
            std::env::set_var("TERM", "linux");
            std::env::set_var("PS1", "rustpi# ");

            let shell = CString::new("/bin/sh").unwrap();
            let arg0 = CString::new("-sh").unwrap();
            let _ = execv(&shell, &[arg0]);

            eprintln!("[init] Failed to start shell!");
            std::process::exit(1);
        }
        Err(e) => {
            eprintln!("[init] Fork failed: {}", e);
            None
        }
    }
}