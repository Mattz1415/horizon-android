//! Android's native entry point. The simulation and renderer are shared with desktop.
#![cfg(target_os = "android")]

#[allow(dead_code, clippy::collapsible_match)]
// Shared vanilla match structure and desktop harnesses.
mod game;
#[path = "android/launcher.rs"]
mod launcher;
// Share the desktop launcher's actual search, compatibility checks, downloads,
// dependency resolution and Java content porting; GPUI itself is desktop-only.
// These files are formatted in the launcher's separate Rust 2021 workspace.
#[rustfmt::skip]
#[allow(dead_code)]
#[path = "../../../launcher/src/account.rs"]
mod account;
#[rustfmt::skip]
#[allow(dead_code)]
#[path = "../../../launcher/src/browser.rs"]
mod browser;
#[path = "android/catalog.rs"]
mod catalog;
#[path = "android/display.rs"]
mod display;
#[path = "android/document_bridge.rs"]
mod document_bridge;
#[path = "android/document_provider.rs"]
mod document_provider;
#[path = "android/document_store.rs"]
mod document_store;
#[path = "android/documents.rs"]
mod documents;
#[path = "android/gallery.rs"]
mod gallery;
#[path = "android/native_ime.rs"]
mod native_ime;
#[path = "android/performance.rs"]
mod performance;
#[path = "android/platform.rs"]
mod platform;
#[path = "android/dns.rs"]
mod android_dns;
#[rustfmt::skip]
#[allow(dead_code)]
#[path = "../../../launcher/src/proxy.rs"]
mod proxy;
#[path = "android/search_queue.rs"]
mod search_queue;
#[path = "android/secure_store.rs"]
mod secure_store;
#[path = "android/shader_catalog.rs"]
mod shader_catalog;
#[path = "android/android_init.rs"]
pub mod android_init;
#[path = "android/chunk_builder.rs"]
pub mod chunk_builder;
#[path = "android/gui_pipeline.rs"]
pub mod gui_pipeline;
#[path = "android/touch_controls.rs"]
pub mod touch_controls;
#[path = "android/android_bridge.rs"]
pub mod android_bridge;
#[rustfmt::skip]
#[allow(dead_code)]
#[path = "../../../launcher/src/skins.rs"]
mod skins;
// The shared account protocol needs only the launcher's version and data path.
mod backend {
    pub const VERSION: &str = if crate::PUBLIC_BUILD {
        "0.7.5"
    } else {
        "0.7.5-dev"
    };
    static HOME: std::sync::OnceLock<std::path::PathBuf> = std::sync::OnceLock::new();
    pub fn initialize(home: std::path::PathBuf) {
        let _ = HOME.set(home);
    }
    pub fn game_home() -> std::path::PathBuf {
        data_dir()
    }
    pub fn game_mod_api_level() -> Option<u32> {
        Some(horizon_mods::api_level::LEVEL)
    }
    pub fn data_dir() -> std::path::PathBuf {
        HOME.get().expect("android_main sets account home").clone()
    }
}

use std::{cell::RefCell, path::PathBuf};
pub(crate) fn keyboard_mouse_input() -> bool {
    horizon_client::android_runtime::active_input() == catalog::InputHost::KeyboardMouse
}
pub(crate) fn configure_input_mode(mode: catalog::InputHost) {
    horizon_client::android_runtime::configure_input(mode);
}
pub(crate) fn touch_visible() -> bool {
    horizon_client::android_runtime::active_input() == catalog::InputHost::Touch
}
pub(crate) fn touch_input(touch: bool) {
    horizon_client::android_runtime::note_input(if touch {
        catalog::InputHost::Touch
    } else {
        catalog::InputHost::KeyboardMouse
    });
}
pub(crate) fn save_input_mode() {
    APP.with(|app| {
        if let Some(home) = app.borrow().as_ref().and_then(|a| a.internal_data_path()) {
            let mut config = catalog::Config::load(&home);
            let mode = horizon_client::android_runtime::input_mode();
            if config.input_host != mode {
                config.input_host = mode;
                if let Err(e) = config.save(&home) {
                    log::warn!("Saving input mode: {e}");
                }
            }
        }
    });
}
pub(crate) const PUBLIC_BUILD: bool = match option_env!("HORIZON_ANDROID_PUBLIC") {
    Some(value) => value.len() == 1 && value.as_bytes()[0] == b'1',
    None => true,
};

#[unsafe(no_mangle)]
fn android_on_create(state: &winit::platform::android::activity::OnCreateState<'_>) {
    init_logging();
    horizon_protocol::install_system_srv_lookup(android_dns::query_srv);
    if let Err(error) =
        unsafe { native_ime::initialize(state.vm_as_ptr().cast(), state.activity_as_ptr().cast()) }
    {
        log::error!("Android system keyboard initialization: {error}");
    }
}
use winit::{
    event_loop::EventLoop,
    platform::android::{EventLoopBuilderExtAndroid, activity::AndroidApp},
};

thread_local! {
    static APP: RefCell<Option<AndroidApp>> = const { RefCell::new(None) };
}

pub(crate) fn android_event_loop() -> Result<EventLoop<()>, winit::error::EventLoopError> {
    APP.with(|app| {
        EventLoop::builder()
            .with_android_app(
                app.borrow()
                    .as_ref()
                    .expect("android_main sets APP")
                    .clone(),
            )
            .build()
    })
}

/// Development overrides for testing both of Horizon's single-player paths.
pub(crate) fn android_arguments() -> horizon_client::Result<Vec<String>> {
    let home = APP.with(|app| app.borrow().as_ref().unwrap().internal_data_path().unwrap());
    let config = catalog::Config::load(&home);
    let res_dir = std::env::var("HORIZON_RESOURCES_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(|_| {
            if home.join("resources/26.3").exists() {
                home.join("resources/26.3")
            } else {
                home.join(".local/horizon-client/26.3")
            }
        });
    let mut args = vec![
        "--resources".into(),
        res_dir.to_string_lossy().into_owned(),
    ];
    if !PUBLIC_BUILD {
        args.extend([
            "--control-socket".into(),
            home.join("control.json").to_string_lossy().into_owned(),
        ]);
    }
    if let Some(session) = crate::launcher::session_argument() {
        args.extend([
            "--session-file".into(),
            session.to_string_lossy().into_owned(),
        ]);
    } else if let Ok(custom_name) = std::env::var("HORIZON_USERNAME") {
        if !custom_name.is_empty() {
            args.extend(["--name".into(), custom_name]);
        }
    } else if !config.name.is_empty() {
        // Offline identity must never override a licensed session's profile.
        args.extend(["--name".into(), config.name.clone()]);
    }
    if !config.server.is_empty() {
        args.extend(["--server".into(), config.server.clone()]);
    }
    if !PUBLIC_BUILD {
        match std::fs::read(home.join("android-launch.json")) {
            Ok(bytes) => args.extend(serde_json::from_slice::<Vec<String>>(&bytes)?),
            Err(error) if error.kind() == std::io::ErrorKind::NotFound => {}
            Err(error) => return Err(error.into()),
        }
    }
    Ok(args)
}

fn init_logging() {
    let trace_gles = !PUBLIC_BUILD && std::env::var_os("HORIZON_GLES_TRACE").is_some();
    let mut logger = android_logger::Config::default()
        .with_max_level(if trace_gles {
            log::LevelFilter::Trace
        } else {
            log::LevelFilter::Info
        })
        .with_tag("Horizon");
    if trace_gles {
        logger = logger.with_filter(
            android_logger::FilterBuilder::new()
                .parse("info,wgpu_hal::gles=trace,wgpu_core::device=debug")
                .build(),
        );
    }
    android_logger::init_once(logger);
}

struct DirectGameApp {
    inner: Box<dyn winit::application::ApplicationHandler>,
}

impl DirectGameApp {
    fn check_exit(&mut self, event_loop: &winit::event_loop::ActiveEventLoop) -> bool {
        if horizon_client::android_runtime::take_launcher_return() {
            event_loop.exit();
            true
        } else {
            false
        }
    }
}

impl winit::application::ApplicationHandler for DirectGameApp {
    fn new_events(
        &mut self,
        event_loop: &winit::event_loop::ActiveEventLoop,
        cause: winit::event::StartCause,
    ) {
        if self.check_exit(event_loop) {
            return;
        }
        self.inner.new_events(event_loop, cause);
    }

    fn resumed(&mut self, event_loop: &winit::event_loop::ActiveEventLoop) {
        if self.check_exit(event_loop) {
            return;
        }
        self.inner.resumed(event_loop);
        let _ = self.check_exit(event_loop);
    }

    fn user_event(&mut self, event_loop: &winit::event_loop::ActiveEventLoop, event: ()) {
        if self.check_exit(event_loop) {
            return;
        }
        self.inner.user_event(event_loop, event);
    }

    fn window_event(
        &mut self,
        event_loop: &winit::event_loop::ActiveEventLoop,
        window_id: winit::window::WindowId,
        event: winit::event::WindowEvent,
    ) {
        if self.check_exit(event_loop) {
            return;
        }
        self.inner.window_event(event_loop, window_id, event);
        let _ = self.check_exit(event_loop);
    }

    fn device_event(
        &mut self,
        event_loop: &winit::event_loop::ActiveEventLoop,
        device_id: winit::event::DeviceId,
        event: winit::event::DeviceEvent,
    ) {
        if self.check_exit(event_loop) {
            return;
        }
        self.inner.device_event(event_loop, device_id, event);
    }

    fn about_to_wait(&mut self, event_loop: &winit::event_loop::ActiveEventLoop) {
        if self.check_exit(event_loop) {
            return;
        }
        self.inner.about_to_wait(event_loop);
        let _ = self.check_exit(event_loop);
    }

    fn suspended(&mut self, event_loop: &winit::event_loop::ActiveEventLoop) {
        self.inner.suspended(event_loop);
    }

    fn exiting(&mut self, event_loop: &winit::event_loop::ActiveEventLoop) {
        self.inner.exiting(event_loop);
    }

    fn memory_warning(&mut self, event_loop: &winit::event_loop::ActiveEventLoop) {
        self.inner.memory_warning(event_loop);
    }
}

#[unsafe(no_mangle)]
fn android_main(app: AndroidApp) {
    use winit::platform::android::activity::input::Axis;
    for axis in [
        Axis::Vscroll,
        Axis::Hscroll,
        Axis::RelativeX,
        Axis::RelativeY,
    ] {
        app.enable_motion_axis(axis);
    }
    init_logging();
    let Some(home) = app.internal_data_path() else {
        log::error!("Android supplied no application data directory");
        return;
    };
    let game_data = home.join("game_data");
    let _ = std::fs::create_dir_all(&game_data);
    let resources_dir = home.join("resources/26.3");
    android_init::initialize_engine_environment(&game_data, &resources_dir, 4);
    backend::initialize(game_data.clone());
    if let Ok(vm) = unsafe { jni::JavaVM::from_raw(app.vm_as_ptr().cast()) } {
        secure_store::initialize(vm);
    }
    let engine_data = app
        .asset_manager()
        .open(c"horizon-facts-26.3.zip")
        .or_else(|| app.asset_manager().open(c"engine-data.zip"));
    APP.with(|slot| *slot.borrow_mut() = Some(app));
    let Some(cache) = platform::cache_dir() else {
        log::error!("Android supplied no application cache directory");
        return;
    };
    horizon_client::android_runtime::configure_cache_dir(cache.clone());
    horizon_client::official_install::configure_download_cache_dir(cache);
    horizon_client::android_runtime::install_clipboard(
        horizon_client::android_runtime::ClipboardHooks {
            get: platform::clipboard_get,
            set: platform::clipboard_set,
        },
    );
    if let Err(error) = std::env::set_current_dir(&game_data) {
        log::error!("Cannot set current dir to {}: {error}", game_data.display());
        let _ = std::env::set_current_dir(&home);
    }
    #[cfg(debug_assertions)]
    if secure_store::development_probe() {
        return;
    }
    horizon_client::crash::install(game_data.clone(), "client");
    let _ = std::fs::remove_file(game_data.join("android-error.txt"));
    if let Some(mut data) = engine_data {
        let copied = (|| -> std::io::Result<()> {
            let mut file = std::fs::File::create(home.join("engine-data.partial"))?;
            std::io::copy(&mut data, &mut file)?;
            drop(file);
            std::fs::rename(
                home.join("engine-data.partial"),
                home.join("engine-data.zip"),
            )
        })();
        if let Err(error) = copied {
            log::error!("Cannot unpack engine data: {error}");
        }
    }
    let engine_zip = home.join("engine-data.zip");
    if engine_zip.is_file() {
        let _ = horizon_client::android_resources::repair_structure_transforms(
            &engine_zip,
            &resources_dir,
        );
        let _ = horizon_client::android_resources::repair_structure_transforms(
            &engine_zip,
            &home.join(".local/horizon-client/26.3"),
        );
    }
    let direct_game = std::env::var("HORIZON_DIRECT_GAME").map(|v| v != "0").unwrap_or(true);
    let result = if direct_game {
        log::info!("Directly booting into Minecraft 26.3 game simulation...");
        match game::android_game() {
            Ok(game_app) => {
                let mut direct_app = DirectGameApp { inner: game_app };
                android_event_loop()
                    .map_err(|e| -> Box<dyn std::error::Error> { e.into() })
                    .and_then(|events| events.run_app(&mut direct_app).map_err(Into::into))
            }
            Err(error) => {
                log::warn!("Direct game boot failed ({error}), falling back to internal launcher");
                let mut launcher = launcher::Launcher::new(home.clone());
                android_event_loop()
                    .map_err(|e| -> Box<dyn std::error::Error> { e.into() })
                    .and_then(|events| events.run_app(&mut launcher).map_err(Into::into))
            }
        }
    } else {
        let mut launcher = launcher::Launcher::new(home.clone());
        android_event_loop()
            .map_err(|e| -> Box<dyn std::error::Error> { e.into() })
            .and_then(|events| events.run_app(&mut launcher).map_err(Into::into))
    };
    if let Err(error) = result {
        log::error!("Horizon: {error}");
        horizon_client::crash::report_error(&game_data, "client", &*error);
        let _ = std::fs::write(game_data.join("android-error.txt"), error.to_string());
    }
    platform::finish();
    APP.with(|slot| *slot.borrow_mut() = None);
    std::process::exit(0);
}
