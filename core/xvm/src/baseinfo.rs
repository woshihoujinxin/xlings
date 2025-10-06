use std::sync::OnceLock;
use std::path::PathBuf;
use std::env;

static RUNDIR: OnceLock<PathBuf> = OnceLock::new();

pub static WORKSPACE_FILE : &str = ".workspace.xvm.yaml";

#[allow(dead_code)]
pub fn rundir() {
    RUNDIR.get_or_init(|| {
        // get current runtime directory
        env::current_dir().expect("Failed to get current directory")
    });
}

pub fn versiondb_file() -> String {
    format!("{}/versions.xvm.yaml", platform::xvm_datadir())
}

pub fn workspace_file() -> String {
    format!("{}/{}", platform::xvm_datadir(), WORKSPACE_FILE)
}

#[allow(dead_code)]
pub fn bindir() -> String {
    platform::xvm_homedir().join("bin").to_string_lossy().to_string()
}

#[allow(dead_code)]
pub fn libdir() -> String {
    platform::xvm_homedir().join("lib").to_string_lossy().to_string()
}

#[allow(dead_code)]
pub fn workspacedir() -> String {
    platform::xvm_homedir().to_string_lossy().to_string()
}

#[allow(dead_code)]
pub fn shimdir() -> String {
    format!("{}/shims", platform::xvm_datadir())
}

#[allow(dead_code)]
pub fn print_baseinfo() {
    println!("XVM Home: {}", platform::xvm_homedir().display());
    println!("XVM Data: {}", platform::xvm_datadir());
    println!("XVM Bindir: {}", bindir());
    println!("XVM VersionDB: {}", versiondb_file());
    println!("XVM Workspace: {}", workspace_file());
}

pub mod platform {
    //use std::env;
    use std::path::PathBuf;
/*
    use super::*;

    static HOMEDIR: OnceLock<String> = OnceLock::new();

    pub fn homedir() -> String {
        HOMEDIR.get_or_init(|| {
            #[cfg(target_os = "windows")]
            {
                env::var("USERPROFILE").expect("Failed to get USERPROFILE environment variable")
            }

            #[cfg(not(target_os = "windows"))]
            {
                env::var("HOME").expect("Failed to get HOME environment variable")
            }
        }).clone()
    }
*/
    // TODO: to support workspace dir, .xlings/xvm-workspace
    pub fn xvm_homedir() -> PathBuf {
        #[cfg(target_os = "windows")]
        {
            let home = std::env::var("XLINGS_HOME")
                .or_else(|_| std::env::var("USERPROFILE"))
                .unwrap_or_else(|_| String::from(r"C:\Users\Public\xlings"));
            PathBuf::from(format!("{}/.xlings_data", home))
        }
        #[cfg(target_os = "macos")]
        {
            let home = std::env::var("XLINGS_HOME")
                .or_else(|_| std::env::var("HOME"))
                .unwrap_or_else(|_| String::from("~"));
            PathBuf::from(format!("{}/.xlings_data", home))
        }
        #[cfg(not(any(target_os = "windows", target_os = "macos")))]
        {
            let home = std::env::var("XLINGS_HOME")
                .or_else(|_| std::env::var("HOME"))
                .unwrap_or_else(|_| String::from("~"));
            PathBuf::from(format!("{}/.xlings_data", home))
        }
    }

    // fixed path for xvm data directory
    pub fn xvm_datadir() -> String {
        #[cfg(target_os = "windows")]
        {
            let home = std::env::var("XLINGS_HOME")
                .or_else(|_| std::env::var("USERPROFILE"))
                .unwrap_or_else(|_| String::from(r"C:\Users\Public\xlings"));
            format!("{}/.xlings_data/xvm", home)
        }
        #[cfg(target_os = "macos")]
        {
            let home = std::env::var("XLINGS_HOME")
                .or_else(|_| std::env::var("HOME"))
                .unwrap_or_else(|_| String::from("~"));
            format!("{}/.xlings_data/xvm", home)
        }
        #[cfg(not(any(target_os = "windows", target_os = "macos")))]
        {
            let home = std::env::var("XLINGS_HOME")
                .or_else(|_| std::env::var("HOME"))
                .unwrap_or_else(|_| String::from("~"));
            format!("{}/.xlings_data/xvm", home)
        }
    }
}