//! Heap-allocated chunk volume storage for Minecraft 26.3 world generation and meshing.
//! Eliminates stack allocations (>192 KiB) that trigger Bionic libc SIGSEGV during terrain synthesis.

pub const CHUNK_WIDTH: usize = 16;
pub const CHUNK_DEPTH: usize = 16;
pub const CHUNK_HEIGHT: usize = 384; // y from -64 to +320
pub const CHUNK_VOLUME: usize = CHUNK_WIDTH * CHUNK_DEPTH * CHUNK_HEIGHT; // 98,304 blocks

/// A dedicated chunk voxel buffer allocated entirely on the heap.
/// Prevents local stack frame overflows during 26.3 world generation.
#[derive(Clone, Debug)]
pub struct ChunkBlockBuffer {
    data: Box<[u16]>,
}

impl ChunkBlockBuffer {
    /// Creates a zero-initialized chunk buffer directly on the heap.
    #[inline]
    pub fn new() -> Self {
        Self {
            data: vec![0u16; CHUNK_VOLUME].into_boxed_slice(),
        }
    }

    /// Creates a chunk buffer filled with a default block state (e.g. air or stone).
    #[inline]
    pub fn filled(block_state: u16) -> Self {
        Self {
            data: vec![block_state; CHUNK_VOLUME].into_boxed_slice(),
        }
    }

    /// Computes the 1D index from 3D coordinates.
    #[inline(always)]
    fn index(x: usize, y: usize, z: usize) -> usize {
        debug_assert!(x < CHUNK_WIDTH, "x out of range: {}", x);
        debug_assert!(y < CHUNK_HEIGHT, "y out of range: {}", y);
        debug_assert!(z < CHUNK_DEPTH, "z out of range: {}", z);
        (y * CHUNK_WIDTH * CHUNK_DEPTH) + (z * CHUNK_WIDTH) + x
    }

    /// Gets a block state at (x, y, z).
    #[inline(always)]
    pub fn get(&self, x: usize, y: usize, z: usize) -> u16 {
        self.data[Self::index(x, y, z)]
    }

    /// Sets a block state at (x, y, z).
    #[inline(always)]
    pub fn set(&mut self, x: usize, y: usize, z: usize, block_state: u16) {
        let idx = Self::index(x, y, z);
        self.data[idx] = block_state;
    }

    /// Exposes read-only slice access to raw voxels.
    #[inline]
    pub fn as_slice(&self) -> &[u16] {
        &self.data
    }

    /// Exposes mutable slice access to raw voxels.
    #[inline]
    pub fn as_mut_slice(&mut self) -> &mut [u16] {
        &mut self.data
    }
}

impl Default for ChunkBlockBuffer {
    fn default() -> Self {
        Self::new()
    }
}
