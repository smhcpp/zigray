const std = @import("std");
const rl = @import("raylib");
const T = @import("types.zig");
const print = std.debug.print;
const Game = @import("game.zig").Game;
pub const Vision = struct {
    vision_step_id: u64 = 0,
    g: *Game,

    pub fn init(g: *Game) !*Vision {
        const v = try g.allocator.create(Vision);
        v.* = Vision{ .g = g };
        return v;
    }

    pub fn deinit(v: *Vision) void {
        v.g.allocator.destroy(v);
    }

    pub fn updatePlayerVision(v: *Vision) !void {
        v.vision_step_id += 1;
        print("vision step id: {}\n", .{v.vision_step_id});
        const g = v.g;
        var corners = try std.ArrayList(Corner).initCapacity(g.allocator, g.wmap.platforms.items.len);
        defer corners.deinit(g.allocator);
        const minpos = g.player.pos - T.Vec2f{ g.player.vision_r, g.player.vision_r };
        const maxpos = g.player.pos + T.Vec2f{ g.player.vision_r, g.player.vision_r };
        const minind = T.iToVec2i(minpos / T.WorldMap.GridSizeVec2f);
        const maxind = T.iToVec2i(maxpos / T.WorldMap.GridSizeVec2f);
        var j = minind[0];
        var k = minind[1];
        while (j <= maxind[0]) : (j += 1) {
            while (k <= maxind[1]) : (k += 1) {
                if (j < 0 or k < 0 or j >= T.WorldMap.GridCellNumberX or k >= T.WorldMap.GridCellNumberY) continue;
                // print("here is get corners function for platform {}\n", .{pid});
                for (g.wmap.grid[@intCast(j)][@intCast(k)].pids.items) |pid| {
                print("here is update vision function for platform {}\n", .{pid});
                    if (v.vision_step_id == g.wmap.platforms.items[pid].vision_step_id) continue;
                    print("here is update vision function(after vision step id check) for platform {}\n", .{pid});
                    const c = try v.getCorners(pid);
                    defer g.allocator.free(c);
                    try corners.appendSlice(g.allocator, c);
                    g.wmap.platforms.items[pid].vision_step_id = v.vision_step_id;
                }
            }
        }
        for (corners.items) |corner| {
            rl.drawLineV(T.toRLVec(v.g.player.pos), T.toRLVec(corner.pos), .orange);
        }
    }

    fn getCorners(v: *Vision, pid: usize) ![]const Corner {
        const g = v.g;
        var corners = try std.ArrayList(Corner).initCapacity(g.allocator, 4);
        defer corners.deinit(g.allocator);
        const p = &g.wmap.platforms.items[pid];
        const left = @max(p.pos[0], g.player.pos[0] - g.player.vision_r,0);
        const right = @min(p.pos[0] + p.size[0], g.player.pos[0] + g.player.vision_r,T.iToF32(g.screenWidth));
        const top = @max(p.pos[1], g.player.pos[1] - g.player.vision_r,0);
        const bottom = @min(p.pos[1] + p.size[1], g.player.pos[1] + g.player.vision_r,T.iToF32(g.screenHeight));
        const tl = T.Vec2f{ left, top };
        const tr = T.Vec2f{ right, top };
        const bl = T.Vec2f{ left, bottom };
        const br = T.Vec2f{ right, bottom };
        const atl = std.math.atan2(tl[1] - g.player.pos[1], tl[0] - g.player.pos[0]);
        const atr = std.math.atan2(tr[1] - g.player.pos[1], tr[0] - g.player.pos[0]);
        const abl = std.math.atan2(bl[1] - g.player.pos[1], bl[0] - g.player.pos[0]);
        const abr = std.math.atan2(br[1] - g.player.pos[1], br[0] - g.player.pos[0]);
        // we do not have to have all corners because there will be
        // at least one and at most two corners that are not
        // visible even when we have not considered other platforms
        print("here is get corners function for platform {}\n", .{pid});
        if (left < right and top < bottom) {
            print("here is get corners function inside if statement for platform {}\n", .{pid});
            try corners.append(g.allocator, Corner{ .pos = tl, .pid = pid, .angle = atl, .dist2 = T.dist2(tl, g.player.pos) });
            try corners.append(g.allocator, Corner{ .pos = tr, .pid = pid, .angle = atr, .dist2 = T.dist2(tr, g.player.pos) });
            try corners.append(g.allocator, Corner{ .pos = bl, .pid = pid, .angle = abl, .dist2 = T.dist2(bl, g.player.pos) });
            try corners.append(g.allocator, Corner{ .pos = br, .pid = pid, .angle = abr, .dist2 = T.dist2(br, g.player.pos) });
        }
        print("----------------------------------------\n",.{});
        return corners.toOwnedSlice(g.allocator);
    }

    pub fn drawPlayerVision(v: *Vision) void {
        rl.drawRectangleLines(T.fToI32(v.g.player.pos[0] - v.g.player.vision_r), T.fToI32(v.g.player.pos[1] - v.g.player.vision_r), T.fToI32(2 * v.g.player.vision_r), T.fToI32(2 * v.g.player.vision_r), .red);
    }
};

pub const Corner = struct {
    pos: T.Vec2f,
    pid: usize,
    angle: f32,
    dist2: f32,
};
