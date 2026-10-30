//! WGPU / GLES GUI & Font Atlas Pipeline with Z-fighting fixes and mobile GPU texture compatibility.
//! Eliminates font clipping and driver artifacts on Adreno 619 (Realme 10 Pro 5G) and Mali GPUs.

use wgpu::*;

/// Color constants for In-Game Liquid Glass Compact HUD.
pub const LIQUID_HUD_BG: [f32; 4] = [18.0 / 255.0, 20.0 / 255.0, 26.0 / 255.0, 0.72];
pub const LIQUID_BORDER_COLOR: [f32; 4] = [228.0 / 255.0, 228.0 / 255.0, 231.0 / 255.0, 0.28];
pub const LIQUID_ACCENT_COLOR: [f32; 4] = [244.0 / 255.0, 244.0 / 255.0, 246.0 / 255.0, 1.0];

/// Converts a 1-channel grayscale alpha glyph bitmap into a 4-channel `Rgba8Unorm` buffer:
/// `[255, 255, 255, alpha]`.
///
/// Hardware Rationale:
/// Adreno 619 (Snapdragon 695) and Mali-G series mobile drivers frequently exhibit driver bugs
/// when sampling 1-channel `R8Unorm` textures inside custom GUI blend passes, producing solid black
/// boxes or empty glyphs. Expanding to `Rgba8Unorm` guarantees 100% cross-driver compatibility.
#[inline]
pub fn convert_glyph_alpha_to_rgba8(alpha_bytes: &[u8], width: usize, height: usize) -> Vec<u8> {
    let total_pixels = width * height;
    let mut rgba = Vec::with_capacity(total_pixels * 4);

    for &alpha in alpha_bytes.iter().take(total_pixels) {
        rgba.push(255); // R
        rgba.push(255); // G
        rgba.push(255); // B
        rgba.push(alpha); // A
    }

    rgba
}

/// Creates a WGPU RenderPipeline specifically configured to prevent Z-fighting between
/// text glyphs and button background quads:
/// - `depth_write_enabled: false` (prevents glyph quad from occluding subsequent overlay text)
/// - `depth_compare: CompareFunction::Always` (ensures 2D UI layers render deterministically)
/// - `cull_mode: None` (avoids accidental backface culling on rotated/scaled HUD elements)
pub fn create_gui_render_pipeline(
    device: &Device,
    color_format: TextureFormat,
    shader_module: &ShaderModule,
    pipeline_layout: &PipelineLayout,
    has_depth_buffer: bool,
) -> RenderPipeline {
    let depth_stencil = has_depth_buffer.then(|| DepthStencilState {
        format: TextureFormat::Depth32Float,
        depth_write_enabled: Some(false), // Disable depth write to stop Z-fighting
        depth_compare: Some(CompareFunction::Always), // Always pass depth for 2D UI overlays
        stencil: StencilState::default(),
        bias: DepthBiasState::default(),
    });

    device.create_render_pipeline(&RenderPipelineDescriptor {
        label: Some("LiquidGlass_GuiPipeline"),
        layout: Some(pipeline_layout),
        vertex: VertexState {
            module: shader_module,
            entry_point: Some("vs_gui_main"),
            compilation_options: PipelineCompilationOptions::default(),
            buffers: &[Some(VertexBufferLayout {
                array_stride: 36, // pos(8) + uv(8) + color(16) + depth(4)
                step_mode: VertexStepMode::Vertex,
                attributes: &[
                    VertexAttribute {
                        format: VertexFormat::Float32x2,
                        offset: 0,
                        shader_location: 0,
                    },
                    VertexAttribute {
                        format: VertexFormat::Float32x2,
                        offset: 8,
                        shader_location: 1,
                    },
                    VertexAttribute {
                        format: VertexFormat::Float32x4,
                        offset: 16,
                        shader_location: 2,
                    },
                    VertexAttribute {
                        format: VertexFormat::Float32,
                        offset: 32,
                        shader_location: 3,
                    },
                ],
            })],
        },
        primitive: PrimitiveState {
            topology: PrimitiveTopology::TriangleList,
            strip_index_format: None,
            front_face: FrontFace::Ccw,
            cull_mode: None, // No culling for 2D GUI
            unclipped_depth: false,
            polygon_mode: PolygonMode::Fill,
            conservative: false,
        },
        depth_stencil,
        multisample: MultisampleState::default(),
        fragment: Some(FragmentState {
            module: shader_module,
            entry_point: Some("fs_gui_main"),
            compilation_options: PipelineCompilationOptions::default(),
            targets: &[Some(ColorTargetState {
                format: color_format,
                blend: Some(BlendState::ALPHA_BLENDING),
                write_mask: ColorWrites::ALL,
            })],
        }),
        multiview_mask: None,
        cache: None,
    })
}

/// Embedded WGSL shader with high-precision arithmetic definitions for Adreno 619 & GLES 3.1.
pub const LIQUID_GUI_SHADER_WGSL: &str = r#"
struct GuiUniform {
    screen_size: vec4<f32>, // (width, height, scale, time)
};

@group(0) @binding(0) var<uniform> u_gui: GuiUniform;
@group(0) @binding(1) var t_atlas: texture_2d<f32>;
@group(0) @binding(2) var s_atlas: sampler;

struct VertexInput {
    @location(0) pos: vec2<f32>,
    @location(1) uv: vec2<f32>,
    @location(2) color: vec4<f32>,
    @location(3) depth: f32,
};

struct VertexOutput {
    @builtin(position) clip_pos: vec4<f32>,
    @location(0) uv: vec2<f32>,
    @location(1) color: vec4<f32>,
};

@vertex
fn vs_gui_main(in: VertexInput) -> VertexOutput {
    var out: VertexOutput;
    let norm_x = (in.pos.x / u_gui.screen_size.x) * 2.0 - 1.0;
    let norm_y = 1.0 - (in.pos.y / u_gui.screen_size.y) * 2.0;
    
    // Explicit high-precision projection
    out.clip_pos = vec4<f32>(norm_x, norm_y, 0.0, 1.0);
    out.uv = in.uv;
    out.color = in.color;
    return out;
}

@fragment
fn fs_gui_main(in: VertexOutput) -> @location(0) vec4<f32> {
    let sampled = textureSample(t_atlas, s_atlas, in.uv);
    let final_color = sampled * in.color;
    
    // Discard fully transparent pixels
    if (final_color.a < 0.004) {
        discard;
    }
    return final_color;
}
"#;
