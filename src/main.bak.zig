const rl = @import("raylib");
const std = @import("std");
const math = std.math;
const print = std.debug.print;
const Vec2i = @Vector(2, i32);
const Vec2f = @Vector(2, f32);
pub fn toRLVec(vec: Vec2i) rl.Vector2 {
    return .{ .x = @floatFromInt(vec[0]), .y = @floatFromInt(vec[1]) };
}
pub fn toVec2i(vec: rl.Vector2) Vec2i {
    return .{ @intFromFloat(vec.x), @intFromFloat(vec.y) };
}

pub fn iToVec2f(v: Vec2i) Vec2f {
    return .{ @floatFromInt(v[0]), @floatFromInt(v[1]) };
}
pub fn fToVec2i(v: Vec2f) Vec2i {
    return .{ @intFromFloat(v[0]), @intFromFloat(v[1]) };
}

pub fn iToF32(v: i32) f32 {
    return @floatFromInt(v);
}

pub fn fToI32(v: f32) i32 {
    return @intFromFloat(v);
}

pub fn isColRecRec(pos1: Vec2i, size1: Vec2i, pos2: Vec2i, size2: Vec2i) bool {
    if (pos1[0] <= pos2[0] and pos1[0] + size1[0] >= pos2[0] and pos1[1] <= pos2[1] and pos1[1] + size1[1] >= pos2[1]) return true;
    if (pos2[0] <= pos1[0] and pos2[0] + size2[0] >= pos1[0] and pos2[1] <= pos1[1] and pos2[1] + size2[1] >= pos1[1]) return true;
    return false;
}

pub fn isColCapRec(player: *Player, plat: Platform) bool {
    // you must check if capsule circles collide with plat rectangle.
    return isColRecRec(player.pos, Vec2i{ 2 * player.r, 2 * player.r }, plat.pos, plat.size);
}
/// radius is the radius of half circles on top and bottom of capsule
/// height is 4*radius and width is 2*radius
const Player = struct {
    pos: Vec2i,
    r: i32 = 10,
    color: rl.Color = .red,
    vel: Vec2i = Vec2i{ 0, 0 },
    maxvel: Vec2i = Vec2i{ 300, 500 },
    jump_power: i32 = 800,

    pub fn draw(g: *Player) void {
        const baspos = toRLVec(g.pos);
        const cir1pos = baspos.subtract(toRLVec(.{ 0, g.r }));
        const cir2pos = baspos.add(toRLVec(.{ 0, g.r }));
        const recpos = baspos.subtract(toRLVec(.{ g.r, g.r }));
        rl.drawCircleV(cir1pos, iToF32(g.r), g.color);
        rl.drawCircleV(cir2pos, iToF32(g.r), g.color);
        rl.drawRectangleV(recpos, toRLVec(.{ g.r * 2, g.r * 2 }), g.color);
    }
};

/// Platforms are in the form of rectangle for now.
/// later on we can add more complex shapes like circles or polygons
/// if needed
pub const Platform = struct {
    pos: Vec2i,
    size: Vec2i,
    color: rl.Color = .gray,
};

pub const TileType = enum {
    empty,
    block,
};

pub const Side = enum {
    l,
    r,
    t,
    b,
    tl,
    tr,
    bl,
    br,
};

/// This function will return where player is with respect to a tile
/// so if player is on top left of the tile it should return tl
pub fn getPlayerTileSide(g: *Game, tilecoords: Vec2i) Side {
    const left = g.player.pos[0] < tilecoords[0] * Game.TileSize;
    const right = g.player.pos[0] > tilecoords[0] * Game.TileSize + Game.TileSize;
    const top = g.player.pos[1] < tilecoords[1] * Game.TileSize;
    const bot = g.player.pos[1] > tilecoords[1] * Game.TileSize + Game.TileSize;
    if (left and top) return .tl;
    if (right and top) return .tr;
    if (left and bot) return .bl;
    if (right and bot) return .br;
    if (left) return .l;
    if (right) return .r;
    if (top) return .t;
    if (bot) return .b;
    return .tl;
}

pub fn isPlayerMoveValid(g: *Game, newpos: Vec2i) ?Vec2i {
    const dir = newpos - g.player.pos;
    const distance = math.sqrt(iToF32(dir[0] * dir[0] + dir[1] * dir[1]));
    if (distance == 0) return newpos;
    const dirn = iToVec2f(dir) / Vec2f{distance, distance};
    var bucket: f32 = 0;
    const steps = [3]f32{ iToF32(g.player.r * 2 - 1), 4.0, 1.0 };
    const lastvalues = [3]f32{ distance - steps[0] + 1, bucket + steps[0], bucket + steps[1] };
    for (steps, 0..) |step, i| {
        while (bucket < lastvalues[i]) : (bucket += step) {
            const pos = g.player.pos + fToVec2i(dirn * Vec2f{ bucket + step, bucket + step });
            if (isPlayerColliding(g,pos)) break;
        }
    }
    return null;
}
pub fn isPlayerColliding(g: *Game,  newpos: Vec2i) bool {
    const capleft = newpos[0] - g.player.r;
    const capright = newpos[0] + g.player.r;
    const captop = newpos[1] - 2 * g.player.r;
    const capbot = newpos[1] + 2 * g.player.r;
    const imin = @divTrunc(capleft, Game.TileSize);
    const jmin = @divTrunc(captop, Game.TileSize);
    const imax = @divTrunc(capright, Game.TileSize);
    const jmax = @divTrunc(capbot, Game.TileSize);
    var i = imin;
    while (i <= imax) : (i += 1) {
        var j = jmin;
        while (j <= jmax) : (j += 1) {
            if (g.tileset.get(Vec2i{ i, j })) |tile| {
                if (tile == .block) return true;
            }
        }
    }
    return false;
}

pub const Game = struct {
    pub const TileSize: i32 = 32;
    pub const TileNumberX: i32 = 32;
    pub const TileNumberY: i32 = 20;
    pub const TileSizeVec2i = Vec2i{ TileSize, TileSize };

    pause: bool = false,
    fps: i32 = 60,
    gravity: i32 = 400,
    friction: i32 = 5,
    dt: f32 = undefined,
    dt2: f32 = undefined,
    allocator: std.mem.Allocator,
    player: Player = undefined,
    screenWidth: i32 = TileNumberX * TileSize,
    screenHeight: i32 = TileNumberY * TileSize,
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
        if (g.inputs.escape) g.pause = !g.pause;
        print("escape: {}\n", .{g.pause});
    }

    fn setup(g: *Game) !void {
        g.dt = 1.0 / iToF32(g.fps);
        g.dt2 = g.dt * g.dt;
        g.player = Player{
            .pos = .{ @divTrunc(g.screenWidth, 2), @divTrunc(g.screenHeight, 2) },
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
            var i: usize = @intCast(platform.pos[0]);
            var j: usize = undefined;
            const imax: usize = @intCast(platform.pos[0] + platform.size[0]);
            const jmax: usize = @intCast(platform.pos[1] + platform.size[1]);
            while (i < imax) : (i += 1) {
                j = @intCast(platform.pos[1]);
                while (j < jmax) : (j += 1) {
                    try g.tileset.put(.{ @intCast(i), @intCast(j) }, .block);
                }
            }
        }
    }

    fn draw(g: *Game) void {
        for (g.platforms.items) |platform| {
            rl.drawRectangleV(toRLVec(platform.pos * Vec2i{ TileSize, TileSize }), toRLVec(platform.size * Vec2i{ TileSize, TileSize }), platform.color);
        }
        g.drawTileLines();
    }

    fn drawTileLines(g: *Game) void {
        var iter = g.tileset.iterator();
        while (iter.next()) |entry| {
            const pos = entry.key_ptr.* * TileSizeVec2i;
            rl.drawRectangleLines(pos[0], pos[1], TileSize, TileSize, .yellow);
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
        // if (rl.isKeyDown(rl.KeyboardKey.up)){
        // g.player.vel[1] = -dx;
        // print("up\n",.{});
        // }else if(rl.isKeyDown(rl.KeyboardKey.down)){
        // g.player.vel[1] = dx;
        // print("down\n",.{});
        // }else {
        // g.player.vel[1] = 0;
        // }

        // Horizental movement checking:
        const newpos1 = g.player.pos + fToVec2i(Vec2f{ iToF32(g.player.vel[0]), 0 } * Vec2f{ g.dt, g.dt });
        // print("position change: {}\n", .{newpos1-g.player.pos});
        const col1 = isPlayerMoveValid(g, newpos1);
        // Horizental and Vertical movement checking
        const gr = if (g.player.vel[1] < 0) fToI32(iToF32(2 * g.gravity) * g.dt) else fToI32(iToF32(g.gravity) * g.dt);
        g.player.vel[1] = if (g.player.vel[1] <= g.player.maxvel[1]) g.player.vel[1] + gr else g.player.maxvel[1];
        // y= y0 + v*dt +1/2 * g* dt2
        const newpos2 = g.player.pos + fToVec2i(iToVec2f(g.player.vel) * Vec2f{ g.dt, g.dt });
        const col2 = isPlayerMoveValid(g, newpos2);
        if(col1) |precol1|{
            if(col2)|precol2|{
                g.player.vel = Vec2i{ 0, 0 };
                g.player.pos = precol2;
            }else {
                g.player.vel[0]=0;
                g.player.pos=Vec2i{precol1[0], newpos2[1]};
            }
        }else{
            if(col2)|precol2|{
                g.player.vel[1]=0;
                g.player.pos=Vec2i{newpos1[0], precol2[1]};
            }else{
                g.player.pos=newpos2;
            }
        }
        // if (col2 and col1) {
            // g.player.vel = Vec2i{ 0, 0 };
        // } else if (col2 and !col1) {
            // g.player.vel[1] = 0;
            // g.player.pos = newpos1;
        // } else {
        //     g.player.pos = newpos2;
        // }
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
