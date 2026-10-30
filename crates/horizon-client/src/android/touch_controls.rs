//! Complete Multi-Touch System for Android with 4 Schemes, Pointer ID Tracking,
//! Circular Mining Ring, and 32 Customizable Liquid Glass Action Buttons.

use std::{
    collections::BTreeMap,
    fs::File,
    io::{BufReader, BufWriter},
    path::Path,
    time::{Duration, Instant},
};
use serde::{Deserialize, Serialize};
use winit::keyboard::KeyCode;

pub const MAX_CUSTOM_BUTTONS: usize = 32;
pub const TAP_MAX_DURATION: Duration = Duration::from_millis(185);
pub const TAP_MAX_MOVE_SQUARED: f32 = 14.0 * 14.0;
pub const HOLD_MIN_DURATION: Duration = Duration::from_millis(200);

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub enum TouchScheme {
    JoystickCrosshair = 0,
    JoystickTap = 1,
    DpadCrosshair = 2,
    DpadTap = 3,
}

impl Default for TouchScheme {
    fn default() -> Self {
        TouchScheme::JoystickCrosshair
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum TouchRole {
    Unassigned,
    MovementThumb,
    LookAndMiningThumb,
    ActionButton(usize),
}

#[derive(Clone, Debug)]
pub struct ActiveTouch {
    pub pointer_id: u64,
    pub start_pos: [f32; 2],
    pub current_pos: [f32; 2],
    pub start_time: Instant,
    pub role: TouchRole,
    pub is_mining_held: bool,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct CustomButtonConfig {
    pub id: usize,
    pub label: String,
    pub key_code_name: String,
    pub norm_x: f32, // 0.0 - 1.0
    pub norm_y: f32, // 0.0 - 1.0
    pub size_dp: f32,
    pub opacity: f32, // 0.1 - 1.0
    pub visible: bool,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct SchemeLayoutConfig {
    pub scheme: TouchScheme,
    pub buttons: Vec<CustomButtonConfig>,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct TouchLayoutFile {
    pub layouts: Vec<SchemeLayoutConfig>,
}

pub struct TouchEngine {
    pub scheme: TouchScheme,
    pub active_touches: BTreeMap<u64, ActiveTouch>,
    pub buttons: Vec<CustomButtonConfig>,
    pub virtual_joystick_pos: Option<[f32; 2]>,
    pub virtual_joystick_delta: [f32; 2],
    pub mining_progress: f32, // 0.0 to 1.0
    pub mining_active: bool,
    pub mining_origin: [f32; 2],
    pub sneak_toggled: bool,
    pub layout_customize_mode: bool,
}

impl TouchEngine {
    pub fn new(scheme: TouchScheme) -> Self {
        let default_buttons = Self::generate_default_buttons();
        Self {
            scheme,
            active_touches: BTreeMap::new(),
            buttons: default_buttons,
            virtual_joystick_pos: None,
            virtual_joystick_delta: [0.0, 0.0],
            mining_progress: 0.0,
            mining_active: false,
            mining_origin: [0.0, 0.0],
            sneak_toggled: false,
            layout_customize_mode: false,
        }
    }

    /// Handles pointer down: tracks pointer_id independently for true multi-touch.
    pub fn on_touch_down(&mut self, id: u64, pos: [f32; 2], screen_w: f32, screen_h: f32) -> TouchAction {
        let is_left_half = pos[0] < (screen_w * 0.45);

        // Check if hitting a custom button
        for (idx, btn) in self.buttons.iter().enumerate() {
            if !btn.visible { continue; }
            let btn_x = btn.norm_x * screen_w;
            let btn_y = btn.norm_y * screen_h;
            let radius = btn.size_dp * 0.5;

            let dx = pos[0] - btn_x;
            let dy = pos[1] - btn_y;
            if (dx * dx + dy * dy) <= (radius * radius) {
                self.active_touches.insert(id, ActiveTouch {
                    pointer_id: id,
                    start_pos: pos,
                    current_pos: pos,
                    start_time: Instant::now(),
                    role: TouchRole::ActionButton(idx),
                    is_mining_held: false,
                });
                return TouchAction::ButtonDown(btn.key_code_name.clone());
            }
        }

        let role = if is_left_half {
            self.virtual_joystick_pos = Some(pos);
            self.virtual_joystick_delta = [0.0, 0.0];
            TouchRole::MovementThumb
        } else {
            TouchRole::LookAndMiningThumb
        };

        self.active_touches.insert(id, ActiveTouch {
            pointer_id: id,
            start_pos: pos,
            current_pos: pos,
            start_time: Instant::now(),
            role,
            is_mining_held: false,
        });

        TouchAction::None
    }

    /// Handles pointer move: updates virtual joystick or look rotation, and sustains hold mining.
    pub fn on_touch_move(&mut self, id: u64, pos: [f32; 2]) -> TouchAction {
        let Some(touch) = self.active_touches.get_mut(&id) else {
            return TouchAction::None;
        };

        let last_pos = touch.current_pos;
        touch.current_pos = pos;
        let delta = [pos[0] - last_pos[0], pos[1] - last_pos[1]];

        match touch.role {
            TouchRole::MovementThumb => {
                if let Some(center) = self.virtual_joystick_pos {
                    let jx = (pos[0] - center[0]).clamp(-60.0, 60.0) / 60.0;
                    let jy = (pos[1] - center[1]).clamp(-60.0, 60.0) / 60.0;
                    self.virtual_joystick_delta = [jx, jy];
                    return TouchAction::MoveAxis(jx, jy);
                }
            }
            TouchRole::LookAndMiningThumb => {
                let elapsed = touch.start_time.elapsed();
                if elapsed >= HOLD_MIN_DURATION && !touch.is_mining_held {
                    touch.is_mining_held = true;
                    self.mining_active = true;
                    self.mining_origin = match self.scheme {
                        TouchScheme::JoystickCrosshair | TouchScheme::DpadCrosshair => [0.5, 0.5], // Center
                        TouchScheme::JoystickTap | TouchScheme::DpadTap => touch.start_pos,
                    };
                }

                // If mining is held, camera rotation still functions simultaneously!
                return TouchAction::LookDelta(delta[0], delta[1], touch.is_mining_held);
            }
            TouchRole::ActionButton(_) => {}
            TouchRole::Unassigned => {}
        }

        TouchAction::None
    }

    /// Handles pointer up: evaluates short tap (<=185ms) for instant attack, or releases mining/buttons.
    pub fn on_touch_up(&mut self, id: u64, pos: [f32; 2]) -> TouchAction {
        let Some(touch) = self.active_touches.remove(&id) else {
            return TouchAction::None;
        };

        match touch.role {
            TouchRole::MovementThumb => {
                self.virtual_joystick_pos = None;
                self.virtual_joystick_delta = [0.0, 0.0];
                return TouchAction::MoveAxis(0.0, 0.0);
            }
            TouchRole::LookAndMiningThumb => {
                let elapsed = touch.start_time.elapsed();
                let dx = pos[0] - touch.start_pos[0];
                let dy = pos[1] - touch.start_pos[1];
                let dist_sq = dx * dx + dy * dy;

                if touch.is_mining_held {
                    self.mining_active = false;
                    self.mining_progress = 0.0;
                    return TouchAction::MiningReleased;
                } else if elapsed <= TAP_MAX_DURATION && dist_sq <= TAP_MAX_MOVE_SQUARED {
                    // Instant Short Tap -> Primary Attack
                    return match self.scheme {
                        TouchScheme::JoystickCrosshair | TouchScheme::DpadCrosshair => TouchAction::AttackCenter,
                        TouchScheme::JoystickTap | TouchScheme::DpadTap => TouchAction::AttackAtPoint(pos[0], pos[1]),
                    };
                }
            }
            TouchRole::ActionButton(idx) => {
                if let Some(btn) = self.buttons.get(idx) {
                    return TouchAction::ButtonUp(btn.key_code_name.clone());
                }
            }
            TouchRole::Unassigned => {}
        }

        TouchAction::None
    }

    /// Updates circular mining progress ring (0.0 to 1.0).
    pub fn update_mining_progress(&mut self, progress: f32) {
        self.mining_progress = progress.clamp(0.0, 1.0);
        if self.mining_progress >= 1.0 {
            // Block broken
            self.mining_progress = 0.0;
        }
    }

    /// Generates 32 comprehensive default Liquid Glass action buttons.
    fn generate_default_buttons() -> Vec<CustomButtonConfig> {
        let list = vec![
            ("JUMP", "Space", 0.92, 0.76, 52.0, 0.85),
            ("SNEAK", "ShiftLeft", 0.92, 0.90, 48.0, 0.85),
            ("PRI", "Attack", 0.82, 0.78, 54.0, 0.80),
            ("SEC", "Use", 0.82, 0.62, 54.0, 0.80),
            ("INV", "KeyE", 0.95, 0.10, 42.0, 0.75),
            ("CHAT", "KeyT", 0.58, 0.08, 38.0, 0.70),
            ("ESC", "Escape", 0.05, 0.08, 42.0, 0.80),
            ("F2", "F2", 0.42, 0.08, 36.0, 0.65), // Screenshot MediaStore
            ("F3", "F3", 0.48, 0.08, 36.0, 0.65), // Debug screen
            ("F5", "F5", 0.53, 0.08, 36.0, 0.65), // Third-person view
            ("DROP", "KeyQ", 0.75, 0.90, 40.0, 0.70),
            ("OFFHAND", "KeyF", 0.75, 0.76, 40.0, 0.70),
            ("1", "Digit1", 0.28, 0.92, 38.0, 0.80),
            ("2", "Digit2", 0.33, 0.92, 38.0, 0.80),
            ("3", "Digit3", 0.38, 0.92, 38.0, 0.80),
            ("4", "Digit4", 0.43, 0.92, 38.0, 0.80),
            ("5", "Digit5", 0.48, 0.92, 38.0, 0.80),
            ("6", "Digit6", 0.53, 0.92, 38.0, 0.80),
            ("7", "Digit7", 0.58, 0.92, 38.0, 0.80),
            ("8", "Digit8", 0.63, 0.92, 38.0, 0.80),
            ("9", "Digit9", 0.68, 0.92, 38.0, 0.80),
            ("SPRINT", "ControlLeft", 0.12, 0.88, 44.0, 0.70),
            ("PICK", "KeyB", 0.82, 0.48, 40.0, 0.65),
            ("LIST", "Tab", 0.36, 0.08, 36.0, 0.65),
            ("ZOOM", "KeyC", 0.88, 0.48, 40.0, 0.65),
            ("F1", "F1", 0.31, 0.08, 36.0, 0.65),
            ("F4", "F4", 0.64, 0.08, 36.0, 0.65),
            ("F8", "F8", 0.70, 0.08, 36.0, 0.65),
            ("EXTRA1", "KeyZ", 0.70, 0.62, 38.0, 0.50),
            ("EXTRA2", "KeyX", 0.70, 0.50, 38.0, 0.50),
            ("EXTRA3", "KeyV", 0.70, 0.38, 38.0, 0.50),
            ("EXTRA4", "KeyR", 0.75, 0.38, 38.0, 0.50),
        ];

        list.into_iter()
            .enumerate()
            .map(|(id, (lbl, key, nx, ny, sz, op))| CustomButtonConfig {
                id,
                label: lbl.to_string(),
                key_code_name: key.to_string(),
                norm_x: nx,
                norm_y: ny,
                size_dp: sz,
                opacity: op,
                visible: true,
            })
            .collect()
    }

    /// Loads custom touch button positions from `filesDir/game_data/config/touch_layout.json`.
    pub fn load_layout_file(config_dir: &Path) -> Option<Self> {
        let file_path = config_dir.join("touch_layout.json");
        if !file_path.exists() {
            return None;
        }

        let file = File::open(file_path).ok()?;
        let reader = BufReader::new(file);
        let layout_file: TouchLayoutFile = serde_json::from_reader(reader).ok()?;

        if let Some(first) = layout_file.layouts.first() {
            let mut engine = Self::new(first.scheme);
            engine.buttons = first.buttons.clone();
            Some(engine)
        } else {
            None
        }
    }

    /// Persists custom touch layout to `filesDir/game_data/config/touch_layout.json`.
    pub fn save_layout_file(&self, config_dir: &Path) -> std::io::Result<()> {
        let file_path = config_dir.join("touch_layout.json");
        if let Some(parent) = file_path.parent() {
            let _ = std::fs::create_dir_all(parent);
        }
        let file = File::create(file_path)?;
        let writer = BufWriter::new(file);

        let data = TouchLayoutFile {
            layouts: vec![SchemeLayoutConfig {
                scheme: self.scheme,
                buttons: self.buttons.clone(),
            }],
        };

        serde_json::to_writer_pretty(writer, &data)?;
        Ok(())
    }
}

pub enum TouchAction {
    None,
    MoveAxis(f32, f32),
    LookDelta(f32, f32, bool), // dx, dy, is_mining
    AttackCenter,
    AttackAtPoint(f32, f32),
    MiningReleased,
    ButtonDown(String),
    ButtonUp(String),
}
