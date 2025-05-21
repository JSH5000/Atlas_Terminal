const std = @import("std");
const c = @cImport({
    @cDefine("SDL_DISABLE_OLD_NAMES", {});
    @cDefine("SDL_MAIN_HANDLED", {});
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_revision.h");
    @cInclude("SDL3/SDL_main.h");
});

// Globals
const window_w = 640;
const window_h = 480;
var window: *c.SDL_Window = undefined;
var renderer: *c.SDL_Renderer = undefined;

const MaxLines = 100;
const MaxLineLength = 512;

var terminal_lines: [MaxLines][MaxLineLength]u8 = undefined;
var terminal_line_lengths: [MaxLines]usize = undefined;
var terminal_line_count: usize = 0;

pub fn main() !void {
    // Main Variables
    var event: c.SDL_Event = undefined;
    var input_buffer: [256]u8 = undefined; // buffer for input
    var input_len: usize = 0;

    // Init the video driver
    _ = c.SDL_Init(c.SDL_INIT_VIDEO);

    // Create the window
    _ = c.SDL_CreateWindowAndRenderer("Atlas Terminal", window_w, window_h, 0, @ptrCast(&window), @ptrCast(&renderer));
    _ = c.SDL_StartTextInput(window);
    _ = c.SDL_RaiseWindow(window);

    while (true) {
        _ = c.SDL_PollEvent(&event);
        if (event.type == c.SDL_EVENT_QUIT) {
            break;
        } else if (event.type == c.SDL_EVENT_TEXT_INPUT) {
            const text = std.mem.span(event.text.text);
            for (text) |char| {
                if (input_len < input_buffer.len - 1) {
                    input_buffer[input_len] = char;
                    input_len += 1;
                    input_buffer[input_len] = 0;
                }
            }
        } else if (event.type == c.SDL_EVENT_KEY_DOWN) {
            // Debug print the key pressed
            const keycode = c.SDL_GetKeyFromScancode(event.key.scancode, c.SDL_KMOD_NONE, true);
            if (keycode == c.SDLK_RETURN or keycode == c.SDLK_KP_ENTER) {
                input_buffer[input_len] = 0;

                var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
                defer arena.deinit();

                const allocator: *const std.mem.Allocator = &arena.allocator();

                const tokens = try parseCommand(input_buffer[0..input_len], allocator);
                if (tokens.len > 0) {
                    const cmd = tokens[0];
                    const args = tokens[1..];

                    if (try handleInternalCommand(cmd, args)) |output| {
                        appendOutputToTerminal(output); // add output to terminal
                    }
                }

                // Clear the input buffer
                input_len = 0;
                @memset(input_buffer[0..], 0);
            } else if (keycode == c.SDLK_BACKSPACE) {
                if (input_len > 0) {
                    input_len -= 1;
                    input_buffer[input_len] = 0; // Clear the deleted character
                }
            }
        }

        _ = c.SDL_SetRenderDrawColor(renderer, 0x00, 0x00, 0x00, 0xff);
        _ = c.SDL_RenderClear(renderer);

        _ = c.SDL_SetRenderDrawColor(renderer, 0xff, 0xff, 0xff, 0xff);

        // Draw terminal output
        for (0..terminal_line_count) |i| {
            const y = @as(f32, @floatFromInt(i * 16));
            const line_ptr: [*c]const u8 = &terminal_lines[i];
            _ = c.SDL_RenderDebugText(renderer, 5, y, line_ptr);
        }

        // Draw current input buffer below
        const input_y = 5 + @as(f32, @floatFromInt(terminal_line_count * 16));
        _ = c.SDL_RenderDebugText(renderer, 5, input_y, &input_buffer);

        _ = c.SDL_RenderPresent(renderer);
    }

    c.SDL_DestroyRenderer(renderer);
    c.SDL_DestroyWindow(window);
}

fn parseCommand(input: []const u8, allocator: *const std.mem.Allocator) ![][]const u8 {
    var tokens = std.ArrayList([]const u8).init(allocator.*);
    var it = std.mem.tokenizeAny(u8, input, " ");
    while (it.next()) |token| {
        try tokens.append(token);
    }
    return tokens.toOwnedSlice();
}

fn handleInternalCommand(cmd: []const u8, args: [][]const u8) !?[]const u8 {
    if (std.mem.eql(u8, cmd, "clear")) {
        resetTerminal();
        return null;
    }

    if (std.mem.eql(u8, cmd, "echo")) {
        // Build directly into a fixed buffer
        var static_buffer: [MaxLineLength]u8 = undefined;
        var index: usize = 0;

        for (args, 0..) |arg, i| {
            const arg_len = arg.len;
            if (index + arg_len >= MaxLineLength) break;

            std.mem.copyForwards(u8, static_buffer[index..][0..arg_len], arg);
            index += arg_len;

            if (i != args.len - 1 and index + 1 < MaxLineLength) {
                static_buffer[index] = ' ';
                index += 1;
            }
        }

        if (index < MaxLineLength - 1) {
            static_buffer[index] = '\n';
            index += 1;
        }

        return static_buffer[0..index];
    }

    return null;
}

fn appendOutputToTerminal(output: []const u8) void {
    if (terminal_line_count >= MaxLines) {
        // Scroll up: shift everything up
        for (0..MaxLines - 1) |i| {
            terminal_lines[i] = terminal_lines[i + 1];
            terminal_line_lengths[i] = terminal_line_lengths[i + 1];
        }
        terminal_line_count = MaxLines - 1;
    }

    const dest = &terminal_lines[terminal_line_count];
    const length = @min(output.len, MaxLineLength);
    std.mem.copyForwards(u8, dest[0..length], output[0..length]);
    terminal_line_lengths[terminal_line_count] = length;
    terminal_line_count += 1;
}

fn resetTerminal() void {
    terminal_line_count = 0;
    for (0..MaxLines) |i| {
        terminal_lines[i] = undefined;
        terminal_line_lengths[i] = 0;
    }
}
