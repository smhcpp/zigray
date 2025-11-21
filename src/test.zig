const std = @import("std");
const math = std.math;
const rl = @import("raylib"); // Assuming raylib-zig wrapper based on your code

// --- Constants ---
const SCREEN_WIDTH = 800;
const SCREEN_HEIGHT = 600;
const G = 800.0; // Gravity
const JUMP_FORCE = -550.0;
const MOVE_SPEED = 300.0;

// --- Math Helpers ---

fn clamp(val: f32, min: f32, max: f32) f32 {
    if (val < min) return min;
    if (val > max) return max;
    return val;
}

// --- Structs ---

const Player = struct {
    pos: rl.Vector2, // Center of the capsule
    vel: rl.Vector2,
    r: f32 = 20.0,   // Radius
    // Capsule total height is determined implicitly:
    // The "body" is a vertical segment from (y-r) to (y+r)
    // Total visual height = 4*r.

    is_grounded: bool = false,
    color: rl.Color = rl.Color.blue,

    pub fn draw(self: *Player) void {
        // Draw the Capsule shape
        // 1. Center Rectangle
        const d = self.r * 2.0;
        const rect_pos = rl.Vector2{ .x = self.pos.x - self.r, .y = self.pos.y - self.r };
        rl.drawRectangleV(rect_pos, rl.Vector2{ .x = d, .y = d }, self.color);

        // 2. Top Circle
        rl.drawCircleV(rl.Vector2{ .x = self.pos.x, .y = self.pos.y - self.r }, self.r, self.color);

        // 3. Bottom Circle
        rl.drawCircleV(rl.Vector2{ .x = self.pos.x, .y = self.pos.y + self.r }, self.r, self.color);
    }
};

const Platform = struct {
    rect: rl.Rectangle,
    color: rl.Color = rl.Color.gray,
};

// --- Core Logic ---

fn resolveCollision(p: *Player, plat: Platform) void {
    // 1. Define the Capsule's Inner Vertical Segment
    // The segment runs from (player.y - r) to (player.y + r)
    const seg_top = p.pos.y - p.r;
    const seg_bot = p.pos.y + p.r;
    const seg_x = p.pos.x;

    // 2. Find point on Platform Rectangle closest to the Player's center (AABB clamp)
    const closest_rect_x = clamp(p.pos.x, plat.rect.x, plat.rect.x + plat.rect.width);
    const closest_rect_y = clamp(p.pos.y, plat.rect.y, plat.rect.y + plat.rect.height);

    // 3. Find point on Capsule Segment closest to that Rectangle point
    // Since our segment is vertical, we just clamp the Y.
    const closest_seg_y = clamp(closest_rect_y, seg_top, seg_bot);
    const closest_seg_x = seg_x;

    // 4. Calculate distance between these two points
    const dx = closest_seg_x - closest_rect_x;
    const dy = closest_seg_y - closest_rect_y;
    const dist_sq = (dx * dx) + (dy * dy);

    // 5. Resolve if distance < radius
    // We use a small epsilon (0.001) to prevent divide by zero
    if (dist_sq < (p.r * p.r) and dist_sq > 0.001) {
        const dist = math.sqrt(dist_sq);
        const overlap = p.r - dist;

        // Normal vector (direction to push player)
        const nx = dx / dist;
        const ny = dy / dist;

        // Apply push
        p.pos.x += nx * overlap;
        p.pos.y += ny * overlap;

        // Physics response
        // If we hit something below us (ny is negative, pointing up), we are grounded
        // Note: In Raylib Y is down, so "up" is negative Y.
        // If the normal pushes us UP (ny < 0), we are on top of something.
        if (ny < -0.7) {
            p.is_grounded = true;
            if (p.vel.y > 0) p.vel.y = 0; // Stop falling
        }
        // If we hit a ceiling
        if (ny > 0.7 and p.vel.y < 0) {
            p.vel.y = 0;
        }
        // Wall collision (cancel horizontal velocity)
        if (@abs(nx) > 0.7) {
            p.vel.x = 0;
        }
    }
}

pub fn main() anyerror!void {
    rl.initWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Minimal Capsule Platformer");
    defer rl.closeWindow();
    rl.setTargetFPS(60);

    // Setup Player
    var player = Player{
        .pos = rl.Vector2{ .x = 400, .y = 300 },
        .vel = rl.Vector2{ .x = 0, .y = 0 },
    };

    // Setup Platforms
    var platforms = try std.ArrayList(Platform).initCapacity(std.heap.page_allocator, 10);
    defer platforms.deinit(std.heap.page_allocator);

    // Floor
    try platforms.append(std.heap.page_allocator,Platform{ .rect = rl.Rectangle{ .x = 0, .y = 550, .width = 800, .height = 50 } });
    // Box 1
    try platforms.append(std.heap.page_allocator,Platform{ .rect = rl.Rectangle{ .x = 200, .y = 400, .width = 100, .height = 50 } });
    // Box 2
    try platforms.append(std.heap.page_allocator,Platform{ .rect = rl.Rectangle{ .x = 500, .y = 300, .width = 200, .height = 30 } });
    // Wall
    try platforms.append(std.heap.page_allocator,Platform{ .rect = rl.Rectangle{ .x = 700, .y = 100, .width = 50, .height = 400 } });

    while (!rl.windowShouldClose()) {
        const dt = rl.getFrameTime();

        // --- Update ---

        // 1. Input
        if (rl.isKeyDown(rl.KeyboardKey.left)) {
            player.vel.x = -MOVE_SPEED;
        } else if (rl.isKeyDown(rl.KeyboardKey.right)) {
            player.vel.x = MOVE_SPEED;
        } else {
            player.vel.x = 0;
        }

        if (rl.isKeyPressed(rl.KeyboardKey.space) and player.is_grounded) {
            player.vel.y = JUMP_FORCE;
            player.is_grounded = false;
        }

        // 2. Apply Gravity
        player.vel.y += G * dt;

        // 3. Move Position
        player.pos.x += player.vel.x * dt;
        player.pos.y += player.vel.y * dt;

        // 4. Resolve Collisions
        player.is_grounded = false; // Reset before checking
        for (platforms.items) |plat| {
            resolveCollision(&player, plat);
        }

        // Keep inside screen (optional)
        if (player.pos.x < 0) player.pos.x = 0;
        if (player.pos.x > SCREEN_WIDTH) player.pos.x = SCREEN_WIDTH;

        // --- Draw ---
        rl.beginDrawing();
        rl.clearBackground(rl.Color.black);

        for (platforms.items) |plat| {
            rl.drawRectangleRec(plat.rect, plat.color);
            rl.drawRectangleLinesEx(plat.rect, 2, rl.Color.dark_gray);
        }

        player.draw();

        rl.drawText("Arrows to Move, Space to Jump", 10, 10, 20, rl.Color.white);

        rl.endDrawing();
    }
}
