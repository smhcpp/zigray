const rl = @import("raylib");
const std = @import("std");
const math = std.math;
const print = std.debug.print;
const Vec2f = @Vector(2, f32);
const Vec2i = @Vector(2, i32);
pub fn toRLVec(vec: Vec2f) rl.Vector2 {
    return .{ .x = vec[0], .y = vec[1] };
}

pub fn iToVec2f(v: Vec2i) Vec2f {
    return .{ @floatFromInt(v[0]), @floatFromInt(v[1]) };
}

pub fn iToVec2i(v: Vec2f) Vec2i {
    return .{ @intFromFloat(v[0]), @intFromFloat(v[1]) };
}

pub fn iToF32(v: i32) f32 {
    return @floatFromInt(v);
}

pub fn fToI32(v: f32) i32 {
    return @intFromFloat(v);
}

/// radius is the radius of half circles on top and bottom of capsule
/// height is 4*radius and width is 2*radius
const Player = struct {
    pos: Vec2f,
    r: f32 = 10,
    color: rl.Color = .blue,
    vel: Vec2f = Vec2f{ 0, 0 },
    maxvel: Vec2f = Vec2f{ 300, 500 },
    jump_power: f32 = 800,
    is_grounded: bool = false,

    pub fn draw(g: *Player) void {
        const baspos = toRLVec(g.pos);
        const cir1pos = baspos.subtract(toRLVec(.{ 0, g.r }));
        const cir2pos = baspos.add(toRLVec(.{ 0, g.r }));
        const recpos = baspos.subtract(toRLVec(.{ g.r, g.r }));
        rl.drawCircleV(cir1pos, g.r, g.color);
        rl.drawCircleV(cir2pos, g.r, g.color);
        rl.drawRectangleV(recpos, toRLVec(.{ g.r * 2, g.r * 2 }), g.color);
    }
};

/// Platforms are in the form of rectangle for now.
/// later on we can add more complex shapes like circles or polygons
/// if needed
pub const Platform = struct {
    pos: Vec2f,
    size: Vec2f,
    color: rl.Color = .gray,
};

pub const TileType = enum {
    empty,
    block,
};

pub fn movePlayer(g: *Game) void {
    const total_delta = g.player.vel * Vec2f{ g.dt, g.dt };
    const stepsize = Vec2f{ 2 * g.player.r - 1, 4 * g.player.r - 1 };
    const temp = total_delta / stepsize;
    const number_of_steps = @max(@floor(@abs(temp[0])), @floor(@abs(temp[1]))) + 1;
    var bucket = Vec2f{ 0, 0 };
    var poschange = Vec2f{ 0, 0 };
    const velocity_step = total_delta / Vec2f{ number_of_steps, number_of_steps };
    var i: f32 = 0;
    var retvel = Vec2f{ 0, 0 };
    var collision = false;
    while (!collision and i < number_of_steps) : (i += 1) {
        bucket += velocity_step;
        for (g.platforms.items) |plat| {
            retvel = checkPlayerCollision(g.player.pos + bucket, g.player.r, g.player.vel, plat, &poschange);
            if (bucket[0] != retvel[0] or bucket[1] != retvel[1]) {
                collision = true;
            }
        }
    }
    if (collision) {
        g.player.pos += poschange;
    } else {
        g.player.pos += total_delta;
    }
    g.player.vel = retvel;
}
pub fn checkPlayerCollision(pos: Vec2f, capr: f32, vel: Vec2f, plat: Platform, poschange: *Vec2f) Vec2f {
    var retvel = vel;
    const captop = pos[1] - capr;
    const capbot = pos[1] + capr;
    const cappos = pos[0];
    // find closest point on platform to the capsule's center
    const closest_plat_point_x = math.clamp(cappos, plat.pos[0] * Game.TileSize, plat.pos[0] * Game.TileSize + plat.size[0] * Game.TileSize);
    const closest_plat_point_y = math.clamp(cappos, plat.pos[1] * Game.TileSize, plat.pos[1] * Game.TileSize + plat.size[1] * Game.TileSize);

    // find closest point on capsule central vertical segment to the closest point of the platform
    // that we found above
    const closest_cap_point_y = math.clamp(closest_plat_point_y, captop, capbot);
    const closest_cap_point_x = cappos;

    // find their distance^2:
    const dx = closest_cap_point_x - closest_plat_point_x;
    const dy = closest_cap_point_y - closest_plat_point_y;
    const dist2 = dx * dx + dy * dy;

    // if there is collision
    if (dist2 < capr * capr and dist2 > 0) {
        const dist = math.sqrt(dist2);
        const overlap = capr - dist;
        const dx_norm = dx / dist;
        const dy_norm = dy / dist;

        poschange[0] += dx_norm * overlap;
        poschange[1] += dy_norm * overlap;

        // if player is moving down and colliding with platform
        if (dy_norm < -0.7) {
            if (vel[1] > 0) retvel[1] = 0;
        }
        // if player is hitting the platform from below
        if (dy_norm > 0.7 and retvel[1] < 0) {
            retvel[1] = 0;
        }
        // if player is hitting the platform from the side
        if (@abs(dx_norm) > 0.7) {
            retvel[0] = 0;
        }
    }
    return retvel;
}
// pub fn isPlayerColliding(g: *Game,  newpos: Vec2i) bool {
//     const capleft = newpos[0] - g.player.r;
//     const capright = newpos[0] + g.player.r;
//     const captop = newpos[1] - 2 * g.player.r;
//     const capbot = newpos[1] + 2 * g.player.r;
//     const imin = @divTrunc(capleft, Game.TileSize);
//     const jmin = @divTrunc(captop, Game.TileSize);
//     const imax = @divTrunc(capright, Game.TileSize);
//     const jmax = @divTrunc(capbot, Game.TileSize);
//     var i = imin;
//     while (i <= imax) : (i += 1) {
//         var j = jmin;
//         while (j <= jmax) : (j += 1) {
//             if (g.tileset.get(Vec2i{ i, j })) |tile| {
//                 if (tile == .block) return true;
//             }
//         }
//     }
//     return false;
// }

pub const Game = struct {
    pub const TileSize: f32 = 32;
    pub const TileNumberX: f32 = 32;
    pub const TileNumberY: f32 = 20;
    pub const TileSizeVec2f = Vec2f{ TileSize, TileSize };

    pause: bool = false,
    fps: i32 = 60,
    gravity: f32 = 400,
    friction: f32 = 5,
    dt: f32 = undefined,
    dt2: f32 = undefined,
    allocator: std.mem.Allocator,
    player: Player = undefined,
    screenWidth: i32 = fToI32(TileNumberX * TileSize),
    screenHeight: i32 = fToI32(TileNumberY * TileSize),
    platforms: std.ArrayList(Platform),
    tileset: std.AutoHashMap(Vec2i, TileType),
    inputs: struct {
        right: bool,
        left: bool,
        up: bool,
        down: bool,
        jump: bool,
        dash: bool,
        attack: bool,
        escape: bool,
    } = .{
        .right = false,
        .left = false,
        .up = false,
        .down = false,
        .jump = false,
        .dash = false,
        .attack = false,
        .escape = false,
    },

    pub fn init(allocator: std.mem.Allocator) !*Game {
        const game = try allocator.create(Game);
        game.* = .{
            .allocator = allocator,
            .platforms = try std.ArrayList(Platform).initCapacity(allocator, 10),
            .tileset = std.AutoHashMap(Vec2i, TileType).init(allocator),
        };
        try game.setup();
        return game;
    }

    fn updateInputs(g: *Game) void {
        g.inputs.right = rl.isKeyDown(rl.KeyboardKey.right);
        g.inputs.left = rl.isKeyDown(rl.KeyboardKey.left);
        g.inputs.up = rl.isKeyDown(rl.KeyboardKey.up);
        g.inputs.down = rl.isKeyDown(rl.KeyboardKey.down);
        g.inputs.jump = rl.isKeyDown(rl.KeyboardKey.space);
        g.inputs.dash = rl.isKeyDown(rl.KeyboardKey.e);
        g.inputs.attack = rl.isKeyDown(rl.KeyboardKey.r);
        g.inputs.escape = rl.isKeyPressed(rl.KeyboardKey.escape);
        if (g.inputs.escape) {
            g.pause = !g.pause;
            print("Pause: {}\n", .{g.pause});
        }
    }

    fn setup(g: *Game) !void {
        g.dt = 1.0 / iToF32(g.fps);
        g.dt2 = g.dt * g.dt;
        g.player = Player{
            .pos = .{ iToF32(@divTrunc(g.screenWidth, 2)), iToF32(@divTrunc(g.screenHeight, 2)) },
        };

        try g.platforms.append(g.allocator, Platform{
            .pos = .{ 3, 5 },
            .size = .{ 5, 7 },
        });

        try g.platforms.append(g.allocator, Platform{
            .pos = .{ 0, 19 },
            .size = .{ 32, 1 },
        });
        for (g.platforms.items) |platform| {
            var i: usize = @intFromFloat(platform.pos[0]);
            var j: usize = undefined;
            const imax: usize = @intFromFloat(platform.pos[0] + platform.size[0]);
            const jmax: usize = @intFromFloat(platform.pos[1] + platform.size[1]);
            while (i < imax) : (i += 1) {
                j = @intFromFloat(platform.pos[1]);
                while (j < jmax) : (j += 1) {
                    try g.tileset.put(.{ @intCast(i), @intCast(j) }, .block);
                }
            }
        }
    }

    fn draw(g: *Game) void {
        for (g.platforms.items) |platform| {
            rl.drawRectangleV(toRLVec(platform.pos * Vec2f{ TileSize, TileSize }), toRLVec(platform.size * Vec2f{ TileSize, TileSize }), platform.color);
        }
        g.drawTileLines();
    }

    fn drawTileLines(g: *Game) void {
        var iter = g.tileset.iterator();
        while (iter.next()) |entry| {
            const pos = iToVec2f(entry.key_ptr.*) * TileSizeVec2f;
            rl.drawRectangleLines(fToI32(pos[0]), fToI32(pos[1]), fToI32(TileSize), fToI32(TileSize), .yellow);
        }
        g.player.draw();
    }

    pub fn process(g: *Game) void {
        if (g.inputs.left) {
            g.player.vel[0] = -g.player.maxvel[0];
        } else if (g.inputs.right) {
            g.player.vel[0] = g.player.maxvel[0];
        } else {
            if (g.player.vel[0] > 0) g.player.vel[0] -= g.friction;
            if (g.player.vel[0] < 0) g.player.vel[0] += g.friction;
        }
        if (rl.isKeyPressed(rl.KeyboardKey.space)) {
            g.player.vel[1] = -g.player.jump_power;
        }

        const gr = if (g.player.vel[1] > 0) 2 * g.gravity * g.dt else g.gravity * g.dt;
        g.player.vel[1] = if (g.player.vel[1] <= g.player.maxvel[1]) g.player.vel[1] + gr else g.player.maxvel[1];
        movePlayer(g);
    }

    pub fn run(g: *Game) void {
        rl.initWindow(g.screenWidth, g.screenHeight, "raylib-zig [core] example - basic window");
        defer rl.closeWindow(); // Close window and OpenGL context
        rl.setExitKey(rl.KeyboardKey.null);
        rl.setTargetFPS(g.fps); // Set our game to run at 60 frames-per-second
        while (!rl.windowShouldClose()) { // Detect window close button or ESC key
            g.updateInputs();
            if (!g.pause) {
                g.process();
            }

            rl.beginDrawing();
            defer rl.endDrawing();
            rl.clearBackground(.black);
            g.draw();
        }
    }
    pub fn deinit(g: *Game) void {
        g.tileset.deinit();
        g.platforms.deinit(g.allocator);
        g.allocator.destroy(g);
    }
};

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const g = try Game.init(allocator);
    g.run();
    g.deinit();
    const leak = gpa.deinit(); // Checks for leaks in debug
    print("\nLeaks:\n {}", .{leak});
}
