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
    maxvel: Vec2f = Vec2f{ 400, 600 },
    speedX: f32 = 250,
    jump_power: f32 = 500,
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
    collision_frame_id: i64 = 0,
    // vision_frame_id:f64,
    pos: Vec2f,
    size: Vec2f,
    color: rl.Color = .gray,
};

pub const GridCell = struct {
    pids: std.ArrayList(usize),
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
    var xcollision = false;
    var ycollision = false;
    while ((!xcollision or !ycollision) and i < number_of_steps) : (i += 1) {
        bucket += velocity_step;
        const pos = g.player.pos + bucket;
        const minpos = pos - Vec2f{ g.player.r, 2 * g.player.r };
        const maxpos = pos + Vec2f{ g.player.r, 2 * g.player.r };
        const minind = iToVec2i(minpos / WorldMap.GridSizeVec2f);
        const maxind = iToVec2i(maxpos / WorldMap.GridSizeVec2f);
        var j = minind[0];
        var k = minind[1];
        while (j <= maxind[0]) : (j += 1) {
            while (k <= maxind[1]) : (k += 1) {
                for (g.wmap.grid[@intCast(j)][@intCast(k)].pids.items) |pid| {
                    // movement fix, platforms get processed multiple times if they exist in multiple grid cells
                    // if (g.collision_frame_id == g.wmap.platforms.items[pid].collision_frame_id) continue;
                    retvel = checkPlayerCollision(pos, g.player.r, g.player.vel, g.wmap.platforms.items[pid], &poschange);
                    if (g.player.vel[0] != retvel[0]) {
                        xcollision = true;
                    }
                    if (g.player.vel[1] != retvel[1]) {
                        ycollision = true;
                    }
                    // g.wmap.platforms.items[pid].collision_frame_id = g.collision_frame_id;
                }
            }
        }
    }
    if (ycollision) {
        retvel[1] = 0;
    }
    if (xcollision) {
        retvel[0] = 0;
    }
    g.player.pos += bucket + poschange;
    g.player.vel = retvel;
}

pub fn checkPlayerCollision(pos: Vec2f, capr: f32, vel: Vec2f, plat: Platform, poschange: *Vec2f) Vec2f {
    var retvel = vel;
    const captop = pos[1] - capr;
    const capbot = pos[1] + capr;
    // find closest point on platform to the capsule's center
    const closest_plat_point_x = math.clamp(pos[0], plat.pos[0], plat.pos[0] + plat.size[0]);
    const closest_plat_point_y = math.clamp(pos[1], plat.pos[1], plat.pos[1] + plat.size[1]);

    // find closest point on capsule central vertical segment to the closest point of the platform
    // that we found above
    const closest_cap_point_y = math.clamp(closest_plat_point_y, captop, capbot);
    const closest_cap_point_x = pos[0];

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

pub const WorldMap = struct {
    pub const GridSize: f32 = 128;
    pub const GridCellNumberX: f32 = 10;
    pub const GridCellNumberY: f32 = 6;
    pub const GridSizeVec2f = Vec2f{ GridSize, GridSize };
    grid: [GridCellNumberX][GridCellNumberY]GridCell,
    platforms: std.ArrayList(Platform),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !*WorldMap {
        const map = try allocator.create(WorldMap);
        map.* = .{
            .allocator = allocator,
            .grid = undefined,
            .platforms = try std.ArrayList(Platform).initCapacity(allocator, 10),
        };
        try map.setup();
        return map;
    }

    pub fn setup(map: *WorldMap) !void {
        for (0..GridCellNumberX) |x| {
            for (0..GridCellNumberY) |y| {
                map.grid[x][y] = .{ .pids = try std.ArrayList(usize).initCapacity(map.allocator, 10) };
            }
        }

        try map.platforms.append(map.allocator, Platform{
            .pos = .{ 100, 50 },
            .size = .{ 100, 200 },
        });

        try map.platforms.append(map.allocator, Platform{
            .pos = .{ 200, 200 },
            .size = .{ 300, 150 },
        });

        try map.platforms.append(map.allocator, Platform{
            .pos = .{ 0, GridSize * GridCellNumberY - 11 },
            .size = .{ GridSize * GridCellNumberX - 1, 10 },
        });

        for (map.platforms.items, 0..) |platform, pid| {
            const imin: usize = @intFromFloat(platform.pos[0] / iToF32(WorldMap.GridSize));
            const jmin: usize = @intFromFloat(platform.pos[1] / iToF32(WorldMap.GridSize));
            const imax: usize = @intFromFloat((platform.pos[0] + platform.size[0]) / iToF32(WorldMap.GridSize));
            const jmax: usize = @intFromFloat((platform.pos[1] + platform.size[1]) / iToF32(WorldMap.GridSize));
            var i = imin;
            while (i <= imax) : (i += 1) {
                var j = jmin;
                while (j <= jmax) : (j += 1) {
                    try map.grid[i][j].pids.append(map.allocator, pid);
                }
            }
        }
    }

    pub fn deinit(map: *WorldMap) void {
        for (0..GridCellNumberX) |x| {
            for (0..GridCellNumberY) |y| {
                map.grid[x][y].pids.deinit(map.allocator);
            }
        }
        map.allocator.destroy(map);
    }
};

pub const Game = struct {
    collision_frame_id: i64 = 1,
    pause: bool = false,
    fps: i32 = 60,
    gravity: f32 = 500,
    friction: f32 = 10,
    dt: f32 = undefined,
    dt2: f32 = undefined,
    allocator: std.mem.Allocator,
    player: Player = undefined,
    wmap: *WorldMap = undefined,
    screenWidth: i32 = fToI32(WorldMap.GridSize * WorldMap.GridCellNumberX),
    screenHeight: i32 = fToI32(WorldMap.GridSize * WorldMap.GridCellNumberY),
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
        g.wmap = try WorldMap.init(g.allocator);
        g.dt = 1.0 / iToF32(g.fps);
        g.dt2 = g.dt * g.dt;
        g.player = Player{
            .pos = .{ iToF32(@divTrunc(g.screenWidth, 2)), iToF32(@divTrunc(g.screenHeight, 2)) },
        };
    }

    fn draw(g: *Game) void {
        if (g.pause) g.drawGridLines();
        for (g.wmap.platforms.items) |platform| {
            rl.drawRectangleV(toRLVec(platform.pos), toRLVec(platform.size), platform.color);
        }
        g.player.draw();
    }

    fn drawGridLines(g: *Game) void {
        var i: i32 = 0;
        while (i < WorldMap.GridCellNumberY) : (i += 1) {
            rl.drawLineV(rl.Vector2{ .x = 0, .y = iToF32(i) * WorldMap.GridSize }, rl.Vector2{ .x = iToF32(g.screenWidth), .y = iToF32(i) * WorldMap.GridSize }, .yellow);
        }
        i = 0;
        while (i < WorldMap.GridCellNumberX) : (i += 1) {
            rl.drawLineV(rl.Vector2{ .x = iToF32(i) * WorldMap.GridSize, .y = 0 }, rl.Vector2{ .x = iToF32(i) * WorldMap.GridSize, .y = iToF32(g.screenHeight) }, .yellow);
        }
    }

    pub fn process(g: *Game) void {
        if (g.inputs.left) {
            g.player.vel[0] = -g.player.speedX;
            if (g.player.vel[0] < -g.player.maxvel[0]) g.player.vel[0] = -g.player.maxvel[0];
        } else if (g.inputs.right) {
            g.player.vel[0] = g.player.speedX;
            if (g.player.vel[0] > g.player.maxvel[0]) g.player.vel[0] = g.player.maxvel[0];
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
            g.collision_frame_id += 1;
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
        g.wmap.deinit();
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
