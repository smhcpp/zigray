const std = @import("std");
const rl = @import("raylib");
const T = @import("types.zig");
const print = std.debug.print;
const Game = @import("game.zig").Game;
pub const Vision = struct {
    vision_step_id: u64 = 0,
    hits: std.ArrayList(Corner),
    g: *Game,

    pub fn init(g: *Game) !*Vision {
        const v = try g.allocator.create(Vision);
        v.* = Vision{ .g = g, .hits = try std.ArrayList(Corner).initCapacity(g.allocator, g.wmap.platforms.items.len), };
        return v;
    }

    pub fn deinit(v: *Vision) void {
        v.hits.deinit(v.g.allocator);
        v.g.allocator.destroy(v);
    }

    pub fn updatePlayerVision(v: *Vision) !void {
        v.vision_step_id += 1;
        // print("vision step id: {}\n", .{v.vision_step_id});
        const g = v.g;
        var corners = try std.ArrayList(Corner).initCapacity(g.allocator, g.wmap.platforms.items.len);
        defer corners.deinit(g.allocator);
        const minpos = g.player.pos - T.Vec2f{ g.player.vision_r, g.player.vision_r };
        const maxpos = g.player.pos + T.Vec2f{ g.player.vision_r, g.player.vision_r };
        const minind = T.iToVec2i(minpos / T.WorldMap.GridSizeVec2f);
        const maxind = T.iToVec2i(maxpos / T.WorldMap.GridSizeVec2f);
        const left = @max( g.player.pos[0] - g.player.vision_r,0);
        const right = @min( g.player.pos[0] + g.player.vision_r,T.iToF32(g.screenWidth));
        const top = @max( g.player.pos[1] - g.player.vision_r,0);
        const bottom = @min( g.player.pos[1] + g.player.vision_r,T.iToF32(g.screenHeight));
        try corners.append(g.allocator,Corner{ .pos = T.Vec2f{left, top}, .pid = null, .angle = std.math.atan2(top - g.player.pos[1], left - g.player.pos[0]),.dist2 = T.dist2(T.Vec2f{left, top}, g.player.pos)});
        try corners.append(g.allocator,Corner{ .pos = T.Vec2f{right, top}, .pid = null, .angle = std.math.atan2(top - g.player.pos[1], right - g.player.pos[0]),.dist2 = T.dist2(T.Vec2f{right, top}, g.player.pos)});
        try corners.append(g.allocator,Corner{ .pos = T.Vec2f{right, bottom}, .pid = null, .angle = std.math.atan2(bottom - g.player.pos[1], right - g.player.pos[0]),.dist2 = T.dist2(T.Vec2f{right, bottom}, g.player.pos)});
        try corners.append(g.allocator,Corner{ .pos = T.Vec2f{left, bottom}, .pid = null, .angle = std.math.atan2(bottom - g.player.pos[1], left - g.player.pos[0]),.dist2 = T.dist2(T.Vec2f{left, bottom}, g.player.pos)});
        var j = minind[0];
        while (j <= maxind[0]) : (j += 1) {
            var k = minind[1];
            while (k <= maxind[1]) : (k += 1) {
                // print("here is update vision function {},{}\n", .{j,k});
                if (j < 0 or k < 0 or j >= T.WorldMap.GridCellNumberX or k >= T.WorldMap.GridCellNumberY) continue;
                // print("here is get corners function for platform {}\n", .{pid});
                for (g.wmap.grid[@intCast(j)][@intCast(k)].pids.items) |pid| {
                // print("here is update vision function for platform {}\n", .{pid});
                    if (v.vision_step_id == g.wmap.platforms.items[pid].vision_step_id) continue;
                    // print("here is update vision function(after vision step id check) for platform {}\n", .{pid});
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
        v.updateHits(&corners,minind,maxind);
    }

    fn updateHits(v: *Vision, corners: *std.ArrayList(Corner),minind:T.Vec2f,maxind:T.Vec2f) !void {
        const g = v.g;
        var i = minind[0];
        while(i<=maxind[0]):(i+=1){
            var j = minind[1];
            while(j<=maxind[1]):(j+=1){
                for (g.wmap.grid[@intCast(j)][@intCast(k)].pids.items) |pid| {
                    for (corners.items) |corner| {
                        const collision= try v.getCollision(pid, &corner,v.g.player.pos)
                        if (collision)|col|{
                            try v.hits.append(v.g.allocator, .{.pos=col,.pid=corner.pid,.angle=corner.angle,.dist2=corner.dist2});
                        }
                    }
                }
            }
        }
    }

    fn getCollision(v:*Vision, pid:usize, corner:*Corner, player_pos:T.Vec2f) !?T.Vec2f {
        const p = v.g.platforms.items[pid];
        const segtop = Segment{.start=p.pos,.end=p.pos + T.Vec2f{p.size[0],0}};
        const segleft = Segment{.start=p.pos,.end=p.pos + T.Vec2f{0,p.size[1]}};
        const segright = Segment{.start=p.pos + T.Vec2f{p.size[0],0},.end=p.pos + T.Vec2f{p.size[0],p.size[1]}};
        const segbottom = Segment{.start=p.pos + T.Vec2f{0,p.size[1]},.end=p.pos + T.Vec2f{p.size[0],p.size[1]}};
        const segs = [_]Segment{segtop,segleft,segright,segbottom};
        var cols = std.ArrayList(T.Vec2f).initCapacity(v.g.allocator, 2);
        defer cols.deinit(v.g.allocator);
        for(segs) |seg| {
            const collision = getColSegSeg(seg, .{.start=v.g.player.pos,.end= corner.pos});
            if(collision) |col| {
                try cols.append(v.g.allocator, col);
            }
        }
        var closest_col:?T.Vec2f=null;
        for (cols.items)|col|{
            if (closest_col) |closest|{
                if (T.dist2(col,v.g.player.pos) < T.dist2(closest,v.g.player.pos)) {
                    closest_col = col;
                }
            }else{
                closest_col = col;
            }
        }
        return closest_col;
    }

    pub fn drawPlayerVision(v: *Vision) void {
        const g = v.g;
        const left = @max( g.player.pos[0] - g.player.vision_r,0);
        const right = @min( g.player.pos[0] + g.player.vision_r,T.iToF32(g.screenWidth));
        const top = @max( g.player.pos[1] - g.player.vision_r,0);
        const bottom = @min( g.player.pos[1] + g.player.vision_r,T.iToF32(g.screenHeight));
        rl.drawRectangleLines(T.fToI32(left), T.fToI32(top), T.fToI32(right - left), T.fToI32(bottom - top), .red);
    }
};

/// returns the closest collision point between a segment and a platform segment
/// return value could be null if no collision is detected
pub fn getColSegPSeg(seg:Segment,pseg:Segment) ?T.Vec2f{


    return null;
}
pub const Segment = struct{
    start: T.Vec2f,
    end: T.Vec2f,
};

pub const Corner = struct {
    pos: T.Vec2f,
    pid: ?usize,
    angle: f32,
    dist2: f32,
};
