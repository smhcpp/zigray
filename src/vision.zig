const std = @import("std");
const rl = @import("raylib");
const T = @import("types.zig");
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
        const g = v.g;
        var corners = try std.ArrayList(Corner).initCapacity(g.allocator, g.wmap.platforms.items.len);
        defer corners.deinit(g.allocator);
        const minpos = g.player.pos - T.Vec2f{ g.player.r, 2 * g.player.r };
        const maxpos = g.player.pos + T.Vec2f{ g.player.r, 2 * g.player.r };
        const minind = T.iToVec2i(minpos / T.WorldMap.GridSizeVec2f);
        const maxind = T.iToVec2i(maxpos / T.WorldMap.GridSizeVec2f);
        var j = minind[0];
        var k = minind[1];
        while (j <= maxind[0]) : (j += 1) {
            while (k <= maxind[1]) : (k += 1) {
                if (j < 0 or k < 0 or j >= T.WorldMap.GridCellNumberX or k >= T.WorldMap.GridCellNumberY) continue;
                for (g.wmap.grid[@intCast(j)][@intCast(k)].pids.items) |pid| {
                    if (v.vision_step_id == g.wmap.platforms.items[pid].vision_step_id) continue;
                    const c = try v.getCorners(pid);
                    try corners.appendSlice(g.allocator, c);
                    g.wmap.platforms.items[pid].vision_step_id = v.vision_step_id;
                }
            }
        }
    }

    fn getCorners(v: *Vision, pid: usize) ![]const Corner {
        const g = v.g;
        var corners = try std.ArrayList(Corner).initCapacity(g.allocator, 4);
        defer corners.deinit(g.allocator);
        const p = &g.wmap.platforms.items[pid];
        const tl = p.pos;
        const tr = p.pos + T.Vec2f{ p.size[0], 0 };
        const bl = p.pos + T.Vec2f{ 0, p.size[1] };
        const br = p.pos + T.Vec2f{ p.size[0], p.size[1] };
        const atl = std.math.atan2(tl[1] - g.player.pos[1], tl[0] - g.player.pos[0]);
        const atr = std.math.atan2(tr[1] - g.player.pos[1], tr[0] - g.player.pos[0]);
        const abl = std.math.atan2(bl[1] - g.player.pos[1], bl[0] - g.player.pos[0]);
        const abr = std.math.atan2(br[1] - g.player.pos[1], br[0] - g.player.pos[0]);
        try corners.append(g.allocator, Corner{ .pos = tl, .pid = pid, .angle = atl, .dist2 = T.dist2(tl, g.player.pos) });
        try corners.append(g.allocator, Corner{ .pos = tr, .pid = pid, .angle = atr, .dist2 = T.dist2(tr, g.player.pos) });
        try corners.append(g.allocator, Corner{ .pos = bl, .pid = pid, .angle = abl, .dist2 = T.dist2(bl, g.player.pos) });
        try corners.append(g.allocator, Corner{ .pos = br, .pid = pid, .angle = abr, .dist2 = T.dist2(br, g.player.pos) });
        return corners.toOwnedSlice(g.allocator);
    }

    pub fn drawPlayerVision(v: *Vision) void {
        _ = v;
    }
};

pub const Corner = struct {
    pos: T.Vec2f,
    pid: usize,
    angle: f32,
    dist2: f32,
};
