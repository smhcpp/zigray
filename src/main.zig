const rl = @import("raylib");
const std = @import("std");
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

pub fn isColPlayerPlatform(player: *Player, plat: Platform) bool {
    return isColRecRec(player.pos, Vec2i{ 2 * player.r, 2 * player.r }, plat.pos, plat.size);
}
/// radius is the radius of half circles on top and bottom of capsule
/// height is 4*radius and width is 2*radius
const Player = struct {
    pos: Vec2i,
    r: i32 = 10,
    color: rl.Color = .blue,
    vel: Vec2i = Vec2i{ 0, 0 },
    maxvel: Vec2i = Vec2i{ 300, 500 },
    jump_power: i32 = 800,

    pub fn draw(self: *Player) void {
        const baspos = toRLVec(self.pos);
        const cir1pos = baspos.subtract(toRLVec(.{ 0, self.r }));
        const cir2pos = baspos.add(toRLVec(.{ 0, self.r }));
        const recpos = baspos.subtract(toRLVec(.{ self.r, self.r }));
        rl.drawCircleV(cir1pos, iToF32(self.r), self.color);
        rl.drawCircleV(cir2pos, iToF32(self.r), self.color);
        rl.drawRectangleV(recpos, toRLVec(.{ self.r * 2, self.r * 2 }), self.color);
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

pub fn isPlayerMoveValid(g: *Game, newpos: Vec2i) bool {
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
// pub const TileSet = struct{
// tiles: std.AutoHashMap(Vec2i, TileType),
// };

pub const Game = struct {
    pub const TileSize: i32 = 32;
    pub const TileNumberX: i32 = 32;
    pub const TileNumberY: i32 = 20;
    pub const TileSizeVec2i = Vec2i{ TileSize, TileSize };

    fps: i32 = 240,
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
    } = .{
        .right = false,
        .left = false,
        .up = false,
        .down = false,
        .jump = false,
        .dash = false,
        .attack = false,
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
    }

    fn setup(self: *Game) !void {
        self.dt = 1.0 / iToF32(self.fps);
        self.dt2 = self.dt * self.dt;
        self.player = Player{
            .pos = .{ @divTrunc(self.screenWidth, 2), @divTrunc(self.screenHeight, 2) },
        };

        try self.platforms.append(self.allocator, Platform{
            .pos = .{ 3, 5 },
            .size = .{ 5, 7 },
        });

        try self.platforms.append(self.allocator, Platform{
            .pos = .{ 0, 19 },
            .size = .{ 32, 1 },
        });
        for (self.platforms.items) |platform| {
            var i: usize = @intCast(platform.pos[0]);
            var j: usize = undefined;
            const imax: usize = @intCast(platform.pos[0] + platform.size[0]);
            const jmax: usize = @intCast(platform.pos[1] + platform.size[1]);
            while (i < imax) : (i += 1) {
                j = @intCast(platform.pos[1]);
                while (j < jmax) : (j += 1) {
                    try self.tileset.put(.{ @intCast(i), @intCast(j) }, .block);
                }
            }
        }
    }

    fn draw(self: *Game) void {
        for (self.platforms.items) |platform| {
            rl.drawRectangleV(toRLVec(platform.pos * Vec2i{ TileSize, TileSize }), toRLVec(platform.size * Vec2i{ TileSize, TileSize }), platform.color);
        }
        self.drawTileLines();
    }

    fn drawTileLines(self: *Game) void {
        var iter = self.tileset.iterator();
        while (iter.next()) |entry| {
            const pos = entry.key_ptr.* * TileSizeVec2i;
            rl.drawRectangleLines(pos[0], pos[1], TileSize, TileSize, .yellow);
        }
        self.player.draw();
    }

    pub fn process(g: *Game) void {
        g.updateInputs();
        if (g.inputs.left) {
            g.player.vel[0] = -g.player.maxvel[0];
            // print("left: \n", .{});
        } else if (g.inputs.right) {
            g.player.vel[0] = g.player.maxvel[0];
            // print("right: \n", .{});
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
        // print("position change: {}\n", .{newpos2-g.player.pos});
        // print("--------------------\n", .{});
        const col2 = isPlayerMoveValid(g, newpos2);
        // print("Player velocity: {}\n", .{g.player.vel});
        if (col2 and col1) {
            g.player.vel = Vec2i{ 0, 0 };
        } else if (col2 and !col1) {
            g.player.vel[1] = 0;
            g.player.pos = newpos1;
            // print("Player bottom position: {}\n", .{g.player.pos + Vec2i{ 0, 2*g.player.r }});
            // std.process.exit(0);
        } else {
            g.player.pos = newpos2;
        }
    }

    pub fn run(self: *Game) void {
        rl.initWindow(self.screenWidth, self.screenHeight, "raylib-zig [core] example - basic window");
        defer rl.closeWindow(); // Close window and OpenGL context
        // const ofps: i32 = 240;
        rl.setTargetFPS(self.fps); // Set our game to run at 60 frames-per-second
        // var bucket: f32 = 0;
        while (!rl.windowShouldClose()) { // Detect window close button or ESC key
            rl.beginDrawing();
            defer rl.endDrawing();
            rl.clearBackground(.black);
            // rl.drawText("Congrats! You created your first window!", 190, 200, 20, .light_gray);
            //----------------------------------------------------------------------------------
            // bucket += 1 / iToF32(ofps);
            // if (bucket >= iToF32(self.fps)) {
            // bucket = 0;
            self.process();
            // }
            self.draw();
        }
    }
    pub fn deinit(self: *Game) void {
        self.tileset.deinit();
        self.platforms.deinit(self.allocator);
        self.allocator.destroy(self);
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
