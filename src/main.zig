const std = @import("std");
const c = @cImport({
    @cDefine("SDL_DISABLE_OLD_NAMES", {});
    @cDefine("SDL_MAIN_HANDLED", {});
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_revision.h");
    @cInclude("SDL3/SDL_main.h");
});

const window_w = 640;
const window_h = 480;
var window: *c.SDL_Window = undefined;
var renderer: *c.SDL_Renderer = undefined;

pub fn main() !void {
    // Variables
    var event: c.SDL_Event = undefined;
    var input_buffer: [256]u8 = undefined; // buffer for input
    var input_len: usize = 0;

    // Init the video driver
    _ = c.SDL_Init(c.SDL_INIT_VIDEO);

    // Create the window
    _ = c.SDL_CreateWindowAndRenderer("Hello World", window_w, window_h, 0, @ptrCast(&window), @ptrCast(&renderer));

    while (true) {
        _ = c.SDL_PollEvent(&event);
        if (event.type == c.SDL_EVENT_QUIT) {
            break;
        } else if (event.type == c.SDL_EVENT_KEY_DOWN) {
            const keycode = c.SDL_GetKeyFromScancode(event.key.scancode, c.SDL_KMOD_NONE, true);
            if (keycode == c.SDLK_RETURN or keycode == c.SDLK_KP_ENTER) {
                // Enter pressed: process input (here, just clear it)
                input_len = 0;
            } else if (keycode == c.SDLK_BACKSPACE) {
                if (input_len > 0) input_len -= 1;
            } else {
                // Only handle printable ASCII
                if (keycode >= 32 and keycode < 127 and input_len < input_buffer.len - 1) {
                    input_buffer[input_len] = @intCast(keycode);
                    input_len += 1;
                }
            }
        }
        _ = c.SDL_SetRenderDrawColor(renderer, 0x00, 0x00, 0x00, 0xff);
        _ = c.SDL_RenderClear(renderer);

        _ = c.SDL_SetRenderDrawColor(renderer, 0xff, 0xff, 0xff, 0xff);
        _ = c.SDL_RenderDebugText(renderer, 5, 5, &input_buffer);

        _ = c.SDL_RenderPresent(renderer);
    }

    c.SDL_DestroyRenderer(renderer);
    c.SDL_DestroyWindow(window);
}
