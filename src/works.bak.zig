const std = @import("std");
const math = std.math;
const rl = @import("raylib");

// --- Constants ---
const SCREEN_WIDTH = 800;
const SCREEN_HEIGHT = 600;
const G = 800.0;
const JUMP_FORCE = -550.0;
const MOVE_SPEED = 300.0;
const TILE_SIZE = 40.0; // Size of one tile

// --- Math Helpers ---

fn clamp(val: f32, min: f32, max: f32) f32 {
    if (val < min) return min;
    if (val > max) return max;
    return val;
}

// --- Tile System Logic ---

// In your real game, this would check your HashMap:
// return tileset.contains(.{x, y});
fn isTileSolid(x: i32, y: i32) bool {
    // Create a floor
    if (y >= 13) return true;

    // Create some walls/structures procedurally for the demo
    if (x == 5 and y == 10) return true;
    if (x == 6 and y == 10) return true;
    if (x == 7 and y == 10) return true;

    if (x == 12 and y == 9) return true;
    if (x == 12 and y == 8) return true;

    return false;
}

// --- Structs ---

const Player = struct {
    pos: rl.Vector2,
    vel: rl.Vector2,
    r: f32 = 18.0, // Radius slightly smaller than half-tile usually feels good

    is_grounded: bool = false,
    color: rl.Color = rl.Color.blue,

    pub fn draw(self: *Player) void {
        const d = self.r * 2.0;
        const rect_pos = rl.Vector2{ .x = self.pos.x - self.r, .y = self.pos.y - self.r };
        rl.drawRectangleV(rect_pos, rl.Vector2{ .x = d, .y = d }, self.color);
        rl.drawCircleV(rl.Vector2{ .x = self.pos.x, .y = self.pos.y - self.r }, self.r, self.color);
        rl.drawCircleV(rl.Vector2{ .x = self.pos.x, .y = self.pos.y + self.r }, self.r, self.color);
    }
};

// We don't need a Platform struct anymore, we generate rects on the fly

// --- Core Logic ---

// Note: We changed the signature to take a raw Rectangle now
fn resolveCollision(p: *Player, rect: rl.Rectangle) void {
    // 1. Define Capsule Segment
    const seg_top = p.pos.y - p.r;
    const seg_bot = p.pos.y + p.r;
    const seg_x = p.pos.x;

    // 2. Find closest point on Tile Rectangle
    const closest_rect_x = clamp(p.pos.x, rect.x, rect.x + rect.width);
    const closest_rect_y = clamp(p.pos.y, rect.y, rect.y + rect.height);

    // 3. Find closest point on Capsule Segment
    const closest_seg_y = clamp(closest_rect_y, seg_top, seg_bot);
    const closest_seg_x = seg_x;

    // 4. Distance Check
    const dx = closest_seg_x - closest_rect_x;
    const dy = closest_seg_y - closest_rect_y;
    const dist_sq = (dx * dx) + (dy * dy);

    if (dist_sq < (p.r * p.r) and dist_sq > 0.001) {
        const dist = math.sqrt(dist_sq);
        const overlap = p.r - dist;
        const nx = dx / dist;
        const ny = dy / dist;

        p.pos.x += nx * overlap;
        p.pos.y += ny * overlap;

        // Physics response
        if (ny < -0.7) {
            p.is_grounded = true;
            if (p.vel.y > 0) p.vel.y = 0;
        }
        if (ny > 0.7 and p.vel.y < 0) {
            p.vel.y = 0;
        }
        if (@abs(nx) > 0.7) {
            p.vel.x = 0;
        }
    }
}

fn checkMapCollisions(p: *Player) void {
    p.is_grounded = false;

    // 1. Calculate Grid Bounds
    // We want to check every tile that the capsule *might* be touching.
    // The capsule extends from (x-r, y-2r) to (x+r, y+2r) roughly.
    const start_x = @as(i32, @intFromFloat((p.pos.x - p.r) / TILE_SIZE));
    const end_x   = @as(i32, @intFromFloat((p.pos.x + p.r) / TILE_SIZE));
    const start_y = @as(i32, @intFromFloat((p.pos.y - (p.r * 2.0)) / TILE_SIZE));
    const end_y   = @as(i32, @intFromFloat((p.pos.y + (p.r * 2.0)) / TILE_SIZE));

    // 2. Iterate ONLY through those tiles
    var y = start_y;
    while (y <= end_y) : (y += 1) {
        var x = start_x;
        while (x <= end_x) : (x += 1) {

            if (isTileSolid(x, y)) {
                // 3. Create a temporary rectangle for this tile
                const tile_rect = rl.Rectangle{
                    .x = @as(f32, @floatFromInt(x)) * TILE_SIZE,
                    .y = @as(f32, @floatFromInt(y)) * TILE_SIZE,
                    .width = TILE_SIZE,
                    .height = TILE_SIZE,
                };

                // 4. Run standard collision logic
                resolveCollision(p, tile_rect);
            }
        }
    }
}

pub fn main() anyerror!void {
    rl.initWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Capsule Tile Collision");
    defer rl.closeWindow();
    rl.setTargetFPS(60);

    var player = Player{
        .pos = rl.Vector2{ .x = 400, .y = 300 },
        .vel = rl.Vector2{ .x = 0, .y = 0 },
    };

    while (!rl.windowShouldClose()) {
        const dt = rl.getFrameTime();

        // --- Input ---
        if (rl.isKeyDown(rl.KeyboardKey.left)) {
            player.vel.x = -MOVE_SPEED;
        } else if (rl.isKeyDown(rl.KeyboardKey.right)) {
            player.vel.x = MOVE_SPEED;
        } else {
            player.vel.x = 0;
        }

        if (rl.isKeyPressed(rl.KeyboardKey.space) and player.is_grounded) {
            player.vel.y = JUMP_FORCE;
        }

        // --- Physics ---
        player.vel.y += G * dt;
        player.pos.x += player.vel.x * dt;
        player.pos.y += player.vel.y * dt;

        // --- Collision ---
        // Replaces the loop over the array list
        checkMapCollisions(&player);

        // Boundary check
        if (player.pos.x < 0) player.pos.x = 0;
        if (player.pos.x > SCREEN_WIDTH) player.pos.x = SCREEN_WIDTH;

        // --- Draw ---
        rl.beginDrawing();
        rl.clearBackground(rl.Color.black);

        // Draw Tiles (Visual only)
        var y: i32 = 0;
        while (y < 20) : (y += 1) {
            var x: i32 = 0;
            while (x < 25) : (x += 1) {
                if (isTileSolid(x, y)) {
                    rl.drawRectangle(
                        x * @as(i32, @intFromFloat(TILE_SIZE)),
                        y * @as(i32, @intFromFloat(TILE_SIZE)),
                        @as(i32, @intFromFloat(TILE_SIZE)),
                        @as(i32, @intFromFloat(TILE_SIZE)),
                        rl.Color.gray
                    );
                    rl.drawRectangleLines(
                        x * @as(i32, @intFromFloat(TILE_SIZE)),
                        y * @as(i32, @intFromFloat(TILE_SIZE)),
                        @as(i32, @intFromFloat(TILE_SIZE)),
                        @as(i32, @intFromFloat(TILE_SIZE)),
                        rl.Color.dark_gray
                    );
                }
            }
        }

        player.draw();
        rl.drawText("Tile-Based Collision", 10, 10, 20, rl.Color.white);
        rl.endDrawing();
    }
}
