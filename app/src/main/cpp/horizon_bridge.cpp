#include <jni.h>
#include <string>
#include <android/log.h>
#include <android/native_window.h>
#include <android/native_window_jni.h>
#include <vulkan/vulkan.h>
#include <mutex>
#include <queue>

#define TAG "HorizonBridge"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, TAG, __VA_ARGS__)

static ANativeWindow* g_native_window = nullptr;
static std::mutex g_window_mutex;

struct InputEvent {
    int type; // 1 = key, 2 = mouse motion, 3 = mouse button
    int code;
    bool pressed;
    float x;
    float y;
};

static std::queue<InputEvent> g_event_queue;
static std::mutex g_queue_mutex;

extern "C" {

JNIEXPORT jboolean JNICALL
Java_dev_playhorizon_launcher_core_HorizonNativeBridge_nativeInit(
    JNIEnv* env,
    jobject /* this */,
    jobject surface,
    jint width,
    jint height,
    jstring dataDir
) {
    std::lock_guard<std::mutex> lock(g_window_mutex);

    if (g_native_window != nullptr) {
        ANativeWindow_release(g_native_window);
        g_native_window = nullptr;
    }

    g_native_window = ANativeWindow_fromSurface(env, surface);
    if (!g_native_window) {
        LOGE("Failed to get ANativeWindow from Surface");
        return JNI_FALSE;
    }

    ANativeWindow_setBuffersGeometry(g_native_window, width, height, WINDOW_FORMAT_RGBA_8888);

    const char* native_data_dir = env->GetStringUTFChars(dataDir, nullptr);
    LOGI("Horizon Native initialized: Window=%p, Resolution=%dx%d, DataDir=%s",
         g_native_window, width, height, native_data_dir);
    env->ReleaseStringUTFChars(dataDir, native_data_dir);

    return JNI_TRUE;
}

JNIEXPORT void JNICALL
Java_dev_playhorizon_launcher_core_HorizonNativeBridge_nativeSendKeyEvent(
    JNIEnv* /* env */,
    jobject /* this */,
    jint keyCode,
    jboolean isPressed
) {
    std::lock_guard<std::mutex> lock(g_queue_mutex);
    InputEvent ev{};
    ev.type = 1;
    ev.code = keyCode;
    ev.pressed = (isPressed == JNI_TRUE);
    g_event_queue.push(ev);
}

JNIEXPORT void JNICALL
Java_dev_playhorizon_launcher_core_HorizonNativeBridge_nativeSendMouseMotion(
    JNIEnv* /* env */,
    jobject /* this */,
    jfloat deltaX,
    jfloat deltaY
) {
    std::lock_guard<std::mutex> lock(g_queue_mutex);
    InputEvent ev{};
    ev.type = 2;
    ev.x = deltaX;
    ev.y = deltaY;
    g_event_queue.push(ev);
}

JNIEXPORT void JNICALL
Java_dev_playhorizon_launcher_core_HorizonNativeBridge_nativeSendMouseButton(
    JNIEnv* /* env */,
    jobject /* this */,
    jint button,
    jboolean isPressed
) {
    std::lock_guard<std::mutex> lock(g_queue_mutex);
    InputEvent ev{};
    ev.type = 3;
    ev.code = button;
    ev.pressed = (isPressed == JNI_TRUE);
    g_event_queue.push(ev);
}

JNIEXPORT void JNICALL
Java_dev_playhorizon_launcher_core_HorizonNativeBridge_nativeResize(
    JNIEnv* /* env */,
    jobject /* this */,
    jint width,
    jint height
) {
    std::lock_guard<std::mutex> lock(g_window_mutex);
    if (g_native_window) {
        ANativeWindow_setBuffersGeometry(g_native_window, width, height, WINDOW_FORMAT_RGBA_8888);
        LOGI("Horizon Native Resized: %dx%d", width, height);
    }
}

JNIEXPORT void JNICALL
Java_dev_playhorizon_launcher_core_HorizonNativeBridge_nativeStop(
    JNIEnv* /* env */,
    jobject /* this */
) {
    std::lock_guard<std::mutex> lock(g_window_mutex);
    if (g_native_window) {
        LOGI("Releasing ANativeWindow: %p", g_native_window);
        ANativeWindow_release(g_native_window);
        g_native_window = nullptr;
    }
}

} // extern "C"
