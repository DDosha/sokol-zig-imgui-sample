const std = @import("std");
const ig = @import("cimgui");
const gizmo = @import("cimguizmo");
const sokol = @import("sokol");
const slog = sokol.log;
const sg = sokol.gfx;
const sapp = sokol.app;
const sglue = sokol.glue;
const simgui = sokol.imgui;
const zm = @import("zmath");

var objectMatrix: [16]f32 = .{
    1.0, 0.0, 0.0, 0.0,
    0.0, 1.0, 0.0, 0.0,
    0.0, 0.0, 1.0, 0.0,
    0.0, 0.0, 0.0, 1.0,
};

var viewMatrix: [16]f32 = undefined;
var projMatrix: [16]f32 = undefined;
const state = struct {
    var pass_action: sg.PassAction = .{};
};

export fn init() void {
    // initialize sokol-gfx
    sg.setup(.{
        .environment = sglue.environment(),
        .logger = .{ .func = slog.func },
    });
    // initialize sokol-imgui
    simgui.setup(.{
        .logger = .{ .func = slog.func },
    });

    // initial clear color
    state.pass_action.colors[0] = .{
        .load_action = .CLEAR,
        .clear_value = .{ .r = 0.0, .g = 0.5, .b = 1.0, .a = 1.0 },
    };

    viewMatrix = createLookAtMatrix(
        .{ 5, 5, 5 }, // eye
        .{ 0, 0, 0 }, // center
        .{ 0, 1, 0 }, // up
    );

    // Initialize projection matrix
    projMatrix = createPerspectiveMatrix(
        std.math.degreesToRadians(45.0),
        800.0 / 600.0,
        0.1,
        100.0,
    );
}

export fn frame() void {
    // call simgui.newFrame() before any ImGui calls
    simgui.newFrame(.{
        .width = sapp.width(),
        .height = sapp.height(),
        .delta_time = sapp.frameDuration(),
        .dpi_scale = sapp.dpiScale(),
    });

    //=== UI CODE STARTS HERE
    ig.igSetNextWindowPos(.{ .x = 10, .y = 10 }, ig.ImGuiCond_Once, .{ .x = 0, .y = 0 });
    ig.igSetNextWindowSize(.{ .x = 400, .y = 100 }, ig.ImGuiCond_Once);
    _ = ig.igBegin("Hello Dear ImGui!", 0, ig.ImGuiWindowFlags_None);
    _ = ig.igColorEdit3("Background", &state.pass_action.colors[0].clear_value.r, ig.ImGuiColorEditFlags_None);
    ig.igEnd();
    //=== UI CODE ENDS HERE

    //=== GIZMO CODE HERE
    gizmo.ImGuizmo_BeginFrame();
    gizmo.ImGuizmo_SetOrthographic(false);
    gizmo.ImGuizmo_SetRect(0, 0, @floatFromInt(sapp.width()), @floatFromInt(sapp.height()));

    _ = gizmo.ImGuizmo_Manipulate(
        &viewMatrix,
        &projMatrix,
        gizmo.UNIVERSAL,
        gizmo.LOCAL,
        &objectMatrix,
        null,
        null,
        null,
        null,
    );
    //=== GIZMO CODE ENDS HERE

    // call simgui.render() inside a sokol-gfx pass
    sg.beginPass(.{ .action = state.pass_action, .swapchain = sglue.swapchain() });
    simgui.render();
    sg.endPass();
    sg.commit();
}

export fn cleanup() void {
    simgui.shutdown();
    sg.shutdown();
}

export fn event(ev: [*c]const sapp.Event) void {
    // forward input events to sokol-imgui
    _ = simgui.handleEvent(ev.*);
}

pub fn main() void {
    sapp.run(.{
        .init_cb = init,
        .frame_cb = frame,
        .cleanup_cb = cleanup,
        .event_cb = event,
        .window_title = "sokol-zig + Dear Imgui",
        .width = 800,
        .height = 600,
        .icon = .{ .sokol_default = true },
        .logger = .{ .func = slog.func },
    });
}

// Helper functions for matrix creation
fn createLookAtMatrix(eye: [3]f32, center: [3]f32, up: [3]f32) [16]f32 {
    const f = normalize(subtract(center, eye));
    const s = normalize(cross(f, up));
    const u = cross(s, f);

    return .{
        s[0],         u[0],         -f[0],       0.0,
        s[1],         u[1],         -f[1],       0.0,
        s[2],         u[2],         -f[2],       0.0,
        -dot(s, eye), -dot(u, eye), dot(f, eye), 1.0,
    };
}

fn createPerspectiveMatrix(fovy: f32, aspect: f32, near: f32, far: f32) [16]f32 {
    const f = 1.0 / std.math.tan(fovy / 2.0);
    const nf = 1.0 / (near - far);

    return .{
        f / aspect, 0.0, 0.0,                   0.0,
        0.0,        f,   0.0,                   0.0,
        0.0,        0.0, (far + near) * nf,     -1.0,
        0.0,        0.0, 2.0 * far * near * nf, 0.0,
    };
}

// Vector operations
fn subtract(a: [3]f32, b: [3]f32) [3]f32 {
    return .{ a[0] - b[0], a[1] - b[1], a[2] - b[2] };
}

fn cross(a: [3]f32, b: [3]f32) [3]f32 {
    return .{
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0],
    };
}

fn dot(a: [3]f32, b: [3]f32) f32 {
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
}

fn normalize(v: [3]f32) [3]f32 {
    const length = @sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);
    return .{ v[0] / length, v[1] / length, v[2] / length };
}
