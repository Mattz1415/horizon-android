//! JNI Bridge connecting HorizonGameActivity with Rust Engine.
//! Handles environment setup, IME soft keyboard events, and MediaStore screenshot saves.

use std::{
    path::PathBuf,
    sync::{Arc, Mutex, OnceLock},
};
use jni::{
    objects::{JByteArray, JClass, JObject, JString, JValue},
    sys::{jboolean, jint, JNI_TRUE, JNI_FALSE},
    JNIEnv, JavaVM,
};

static JVM: OnceLock<JavaVM> = OnceLock::new();
static IME_QUEUE: OnceLock<Arc<Mutex<Vec<ImeEvent>>>> = OnceLock::new();

#[derive(Clone, Debug)]
pub enum ImeEvent {
    Input(String),
    Backspace,
    Done,
}

fn get_ime_queue() -> &'static Arc<Mutex<Vec<ImeEvent>>> {
    IME_QUEUE.get_or_init(|| Arc::new(Mutex::new(Vec::with_capacity(32))))
}

/// Polls pending IME input events accumulated from Android Soft Keyboard.
pub fn drain_ime_events() -> Vec<ImeEvent> {
    let queue = get_ime_queue();
    if let Ok(mut lock) = queue.lock() {
        std::mem::take(&mut *lock)
    } else {
        Vec::new()
    }
}

/// JNI: Initializes working directories, Rayon threadpool, and parameters from HorizonGameActivity.
#[unsafe(no_mangle)]
pub extern "system" fn Java_dev_horizon_android_HorizonGameActivity_nativeInitEnvironment(
    mut env: JNIEnv,
    _class: JClass,
    game_data_dir: JString,
    resources_dir: JString,
    _ram_mb: jint,
    threads: jint,
    _backend: JString,
    touch_scheme: jint,
) {
    if JVM.get().is_none() {
        if let Ok(vm) = env.get_java_vm() {
            let _ = JVM.set(vm);
        }
    }

    let g_dir: String = env.get_string(&game_data_dir)
        .map(|s| s.into())
        .unwrap_or_else(|_| "/data/data/dev.horizon.android/files/game_data".into());

    let r_dir: String = env.get_string(&resources_dir)
        .map(|s| s.into())
        .unwrap_or_else(|_| "/data/data/dev.horizon.android/files/resources/26.3".into());

    let game_data_path = PathBuf::from(g_dir);
    let resources_path = PathBuf::from(r_dir);

    // Call android_init to set working directory, Rayon pool, and panic hook
    super::android_init::initialize_engine_environment(
        &game_data_path,
        &resources_path,
        threads as usize,
    );

    log::info!(
        "[HorizonBridge] Native environment initialized. Touch scheme: {}",
        touch_scheme
    );
}

/// JNI: Called when user types characters on Android Soft Keyboard.
#[unsafe(no_mangle)]
pub extern "system" fn Java_dev_horizon_android_HorizonGameActivity_nativeOnImeInput(
    mut env: JNIEnv,
    _class: JClass,
    text: JString,
) {
    if let Ok(chars) = env.get_string(&text) {
        let queue = get_ime_queue();
        if let Ok(mut lock) = queue.lock() {
            lock.push(ImeEvent::Input(chars.into()));
        }
    }
}

/// JNI: Called when user hits Backspace / DEL on Android Soft Keyboard.
#[unsafe(no_mangle)]
pub extern "system" fn Java_dev_horizon_android_HorizonGameActivity_nativeOnImeBackspace(
    _env: JNIEnv,
    _class: JClass,
) {
    let queue = get_ime_queue();
    if let Ok(mut lock) = queue.lock() {
        lock.push(ImeEvent::Backspace);
    }
}

/// JNI: Called when user completes typing (Enter / Done).
#[unsafe(no_mangle)]
pub extern "system" fn Java_dev_horizon_android_HorizonGameActivity_nativeOnImeDone(
    _env: JNIEnv,
    _class: JClass,
) {
    let queue = get_ime_queue();
    if let Ok(mut lock) = queue.lock() {
        lock.push(ImeEvent::Done);
    }
}

/// Calls Kotlin `HorizonGameActivity.requestShowIme(initial_text)` from Rust.
pub fn request_show_soft_keyboard(initial_text: &str) {
    let Some(vm) = JVM.get() else { return };
    if let Ok(mut env) = vm.attach_current_thread() {
        if let Ok(j_text) = env.new_string(initial_text) {
            let class_name = "dev/horizon/android/HorizonGameActivity";
            if let Ok(cls) = env.find_class(class_name) {
                let _ = env.call_static_method(
                    cls,
                    "requestShowIme",
                    "(Ljava/lang/String;)V",
                    &[JValue::Object(&j_text)],
                );
            }
        }
    }
}

/// Calls Kotlin `HorizonGameActivity.requestHideIme()` from Rust.
pub fn request_hide_soft_keyboard() {
    let Some(vm) = JVM.get() else { return };
    if let Ok(mut env) = vm.attach_current_thread() {
        let class_name = "dev/horizon/android/HorizonGameActivity";
        if let Ok(cls) = env.find_class(class_name) {
            let _ = env.call_static_method(cls, "requestHideIme", "()V", &[]);
        }
    }
}

/// Saves an in-game screenshot (F2 key trigger) to Android system gallery using MediaStore.
pub fn save_screenshot_to_mediastore(png_bytes: &[u8], filename: &str) -> bool {
    let Some(vm) = JVM.get() else { return false };
    if let Ok(mut env) = vm.attach_current_thread() {
        if let Ok(byte_array) = env.byte_array_from_slice(png_bytes) {
            if let Ok(j_filename) = env.new_string(filename) {
                let class_name = "dev/horizon/android/HorizonGameActivity";
                if let Ok(cls) = env.find_class(class_name) {
                    let result = env.call_static_method(
                        cls,
                        "saveScreenshotMediaStore",
                        "([BLjava/lang/String;)Z",
                        &[JValue::Object(&byte_array), JValue::Object(&j_filename)],
                    );
                    if let Ok(val) = result {
                        if let Ok(b) = val.z() {
                            return b;
                        }
                    }
                }
            }
        }
    }
    false
}
