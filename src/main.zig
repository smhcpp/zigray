const rl = @import("raylib");
const std = @import("std");
const print = std.debug.print;
const Vec2i = @Vector(2, i32);
pub fn toRLVec(vec: Vec2i) rl.Vector2 {
    return .{ .x = @floatFromInt(vec[0]), .y = @floatFromInt(vec[1]) };
}
pub fn toVec2i(vec: rl.Vector2) Vec2i {
    return .{ @intFromFloat(vec.x), @intFromFloat(vec.y) };
}

pub fn iToF32(v:i32) f32{
    return @floatFromInt(v);
}
/// radius is the radius of half circles on top and bottom of capsule
/// height is 4*radius and width is 2*radius
const Player = struct {
    pos:Vec2i,
    r:i32=10,
    color:rl.Color=.blue,

    pub fn draw(self:*Player)void{
        const baspos= toRLVec(self.pos);
        const cir1pos= baspos.subtract(toRLVec(.{0,self.r}));
        const cir2pos= baspos.add(toRLVec(.{0,self.r}));
        const recpos= baspos.subtract(toRLVec(.{self.r,self.r}));
        rl.drawCircleV(cir1pos, iToF32(self.r), self.color);
        rl.drawCircleV(cir2pos, iToF32(self.r), self.color);
        rl.drawRectangleV(recpos, toRLVec(.{self.r * 2, self.r * 2}), self.color);
    }
};

/// Platforms are in the form of rectangle for now.
/// later on we can add more complex shapes like circles or polygons
/// if needed
pub const Platform = struct{
    pos:Vec2i,
    size:Vec2i,
    color:rl.Color=.gray,
};

pub const TileType = enum{
    empty,
    block,
};
// pub const TileSet = struct{
    // tiles: std.AutoHashMap(Vec2i, TileType),
// };

pub const Game = struct {
    pub const TileSize: i32 =32;
    pub const TileNumberX:i32 = 32;
    pub const TileNumberY:i32 = 20;
    pub const TileSetVec2i = Vec2i{TileSize, TileSize};
    allocator: std.mem.Allocator,
    player: Player=undefined,
    screenWidth:i32=TileNumberX*TileSize,
    screenHeight:i32=TileNumberY*TileSize,
    platforms: std.ArrayList(Platform),
    tileset: std.AutoHashMap(Vec2i, TileType),

    pub fn init(allocator: std.mem.Allocator) !*Game{
        const game = try allocator.create(Game);
        game.* = .{
            .allocator = allocator,
            .platforms = try std.ArrayList(Platform).initCapacity(allocator, 10),
            .tileset = std.AutoHashMap(Vec2i, TileType).init(allocator),
        };
        try game.setup();
        return game;
    }

    fn setup(self:*Game) !void {
        self.player = Player{
            .pos = .{@divTrunc(self.screenWidth, 2), @divTrunc(self.screenHeight, 2)},
        };

        try self.platforms.append(self.allocator,Platform{
            .pos = .{3, 5},
            .size = .{5, 7},
        });

        for (self.platforms.items) |platform| {
            var i :usize = @intCast( platform.pos[0]);
            var j :usize = undefined;
            const imax: usize = @intCast(platform.pos[0] + platform.size[0]);
            const jmax: usize = @intCast(platform.pos[1] + platform.size[1]);
            while(i<imax):(i+=1){
                 j  = @intCast( platform.pos[1]);
                 while(j<jmax):(j+=1){
                     try self.tileset.put(.{@intCast(i), @intCast(j)}, .block);
                 }
            }
        }
    }

    fn draw(self:*Game) void{
        for(self.platforms.items) |platform|{
            rl.drawRectangleV(toRLVec(platform.pos * Vec2i{TileSize, TileSize}),toRLVec(platform.size * Vec2i{TileSize, TileSize}),platform.color);
        }
        var iter = self.tileset.iterator();
        defer iter.deinit();
        while(iter.next())|key||value| {
            const pos = value * TileSetVec2i;
            rl.drawRectangleLines(pos[0], pos[1],TileSize,TileSize, .yellow);
        }
        self.player.draw();
    }

    pub fn run(self:*Game) void{
        rl.initWindow(self.screenWidth, self.screenHeight, "raylib-zig [core] example - basic window");
        defer rl.closeWindow(); // Close window and OpenGL context
        rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second
        while (!rl.windowShouldClose()) { // Detect window close button or ESC key
            rl.beginDrawing();
            defer rl.endDrawing();
            rl.clearBackground(.black);
            // rl.drawText("Congrats! You created your first window!", 190, 200, 20, .light_gray);
            //----------------------------------------------------------------------------------
            self.draw();
        }
    }
    pub fn deinit(self:*Game) void{
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
