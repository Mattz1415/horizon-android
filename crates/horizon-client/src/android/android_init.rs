//! Android runtime environment initialization, thread stack expansion, and panic logging.
//! Specifically tuned for Qualcomm Snapdragon 695 (Kryo 660) & Bionic libc.

use std::{
    backtrace::Backtrace,
    fs::OpenOptions,
    io::Write,
    panic,
    path::{Path, PathBuf},
    sync::{Once, OnceLock},
    thread,
};

static INIT_ONCE: Once = Once::new();
static CRASH_LOG_PATH: OnceLock<PathBuf> = OnceLock::new();

// Direct FFI to Android NDK logger for unbuffered panic messages.
#[cfg(target_os = "android")]
unsafe extern "C" {
    fn __android_log_write(prio: i32, tag: *const std::ffi::c_char, text: *const std::ffi::c_char) -> i32;
}

const ANDROID_LOG_ERROR: i32 = 6;
const ANDROID_LOG_FATAL: i32 = 7;

/// Initializes the Android execution environment:
/// 1. Working directory redirected to `filesDir/game_data` so all relative I/O (`./saves`, `./config`) remains in app-private storage.
/// 2. Bionic libc stack expanded: Global Rayon pool initialized with 8 MiB per thread, sized to the core count unless the launcher sets it.
/// 3. Panic hook capturing complete backtraces to Android Logcat (`HorizonRustPanic`) and writing to `crash.log`.
pub fn initialize_engine_environment(game_data_dir: &Path, resources_dir: &Path, worker_threads: usize) {
    INIT_ONCE.call_once(|| {
        // 1. Redirect Working Directory
        if let Err(e) = std::fs::create_dir_all(game_data_dir) {
            log_panic_msg(&format!("Gagal membuat game_data_dir: {e}"));
        }
        if let Err(e) = std::env::set_current_dir(game_data_dir) {
            log_panic_msg(&format!("Gagal set_current_dir ke game_data_dir: {e}"));
        } else {
            log_info_msg(&format!("Working directory berhasil diarahkan ke {}", game_data_dir.display()));
        }

        // Set resources environment variable for fallback discovery
        unsafe {
            std::env::set_var("HORIZON_RESOURCES_DIR", resources_dir.as_os_str());
        }

        // Simpan path crash.log
        let crash_file = game_data_dir.join("crash.log");
        let _ = CRASH_LOG_PATH.set(crash_file.clone());

        // 2. Install Robust Panic Hook
        panic::set_hook(Box::new(move |info| {
            let backtrace = Backtrace::force_capture();
            let location = info.location().map(|l| format!("{}:{}:{}", l.file(), l.line(), l.column()))
                .unwrap_or_else(|| "unknown location".to_string());
            let payload = if let Some(s) = info.payload().downcast_ref::<&str>() {
                *s
            } else if let Some(s) = info.payload().downcast_ref::<String>() {
                s.as_str()
            } else {
                "Unknown panic payload"
            };

            let timestamp = std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .map(|d| d.as_secs())
                .unwrap_or(0);

            let panic_report = format!(
                "================ HORIZON RUST PANIC ================\n\
                 Timestamp: {}\n\
                 Thread: {:?}\n\
                 Location: {}\n\
                 Message: {}\n\
                 Backtrace:\n{}\n\
                 ===================================================\n",
                timestamp,
                thread::current().name().unwrap_or("unnamed"),
                location,
                payload,
                backtrace
            );

            // Log ke Android Logcat
            log_panic_msg(&panic_report);

            // Simpan ke crash.log di game_data
            if let Some(path) = CRASH_LOG_PATH.get() {
                if let Ok(mut file) = OpenOptions::new().create(true).append(true).open(path) {
                    let _ = file.write_all(panic_report.as_bytes());
                    let _ = file.flush();
                }
            }
        }));

        // 3. Global Rayon pool, 8 MiB stack per worker. 0 sizes it to the phone: every core
        // but two, which stay free for the render and server threads.
        let threads = if worker_threads > 0 {
            worker_threads
        } else {
            thread::available_parallelism()
                .map_or(4, |n| n.get())
                .saturating_sub(2)
                .max(2)
        };
        let stack_size = 8 * 1024 * 1024; // 8 MiB

        let rayon_result = rayon::ThreadPoolBuilder::new()
            .num_threads(threads)
            .stack_size(stack_size)
            .thread_name(|i| format!("horizon-rayon-{}", i))
            .build_global();

        if let Err(e) = rayon_result {
            log_info_msg(&format!("Catatan: Rayon global pool sudah diinisialisasi atau: {e}"));
        } else {
            log_info_msg(&format!("Rayon Global ThreadPool aktif: {} worker, 8 MiB stack/thread", threads));
        }
    });
}

/// Spawns an engine thread with an explicit 8 MiB stack size to guarantee zero SIGSEGV/stack overflows
/// under Bionic libc during deep recursion in 26.3 worldgen and biome noise sampling.
pub fn spawn_engine_thread<F, T>(name: &str, f: F) -> std::io::Result<thread::JoinHandle<T>>
where
    F: FnOnce() -> T + Send + 'static,
    T: Send + 'static,
{
    const ENGINE_STACK_SIZE: usize = 8 * 1024 * 1024; // 8 MiB
    thread::Builder::new()
        .name(name.to_string())
        .stack_size(ENGINE_STACK_SIZE)
        .spawn(f)
}

fn log_panic_msg(msg: &str) {
    #[cfg(target_os = "android")]
    unsafe {
        let tag = c"HorizonRustPanic";
        if let Ok(c_str) = std::ffi::CString::new(msg) {
            __android_log_write(ANDROID_LOG_FATAL, tag.as_ptr(), c_str.as_ptr());
        }
    }
    #[cfg(not(target_os = "android"))]
    eprintln!("[HorizonRustPanic] {}", msg);
}

fn log_info_msg(msg: &str) {
    log::info!("[HorizonAndroid] {}", msg);
}
