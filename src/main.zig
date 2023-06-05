const c = @cImport({
    @cInclude("SDL2/SDL.h");
});

const WINDOW_WIDTH = 858;
const WINDOW_HEIGHT = 525;

const PADDLE_WIDTH = 10;
const PADDLE_HEIGHT = 50;
const PADDLE_OFFSET = 30;
const PADDLE_SPEED = 15;

const BALL_SIZE = 10;
const BALL_SPEED = 7;

const Paddle = struct {
    rect: c.SDL_Rect,
    dy: i32 = PADDLE_SPEED,

    pub fn init(x: i32, y: i32) Paddle {
        const rect = c.SDL_Rect{ .x = x, .y = y, .w = PADDLE_WIDTH, .h = PADDLE_HEIGHT };
        return Paddle{ .rect = rect };
    }

    pub fn move(self: *Paddle, dir: i32) void {
        const max_height = WINDOW_HEIGHT - self.rect.h;
        const new_y = self.rect.y + dir * self.dy;
        if (new_y >= 0 and new_y <= max_height) {
            self.rect.y = new_y;
        } else if (new_y < 0) {
            self.rect.y = 0;
        } else if (new_y > max_height) {
            self.rect.y = max_height;
        }
    }

    pub fn draw(self: *Paddle, renderer: *c.SDL_Renderer) void {
        _ = c.SDL_SetRenderDrawColor(renderer, 0xFF, 0xFF, 0xFF, 0xFF);
        _ = c.SDL_RenderFillRect(renderer, &self.rect);
    }
};

const Ball = struct {
    rect: c.SDL_Rect,
    dx: i32,
    dy: i32,

    pub fn init() Ball {
        const rect = c.SDL_Rect{
            .x = (WINDOW_WIDTH - BALL_SIZE) / 2,
            .y = (WINDOW_HEIGHT - BALL_SIZE) / 2,
            .w = BALL_SIZE,
            .h = BALL_SIZE,
        };

        return Ball{ .rect = rect, .dx = BALL_SPEED, .dy = BALL_SPEED };
    }

    // TODO(eugenhotaj): This is just a quick and dirty way to handle collisions. Technically
    // we need to reposition the ball by reflecting it about the collision normal.
    pub fn update(self: *Ball, player: Paddle, enemy: Paddle) void {
        const max_y = WINDOW_HEIGHT - self.rect.h;
        const new_y = self.rect.y + self.dy;
        if (new_y >= 0 and new_y <= max_y) {
            self.rect.y = new_y;
        } else if (new_y < 0) {
            self.rect.y = 0;
            self.dy *= -1;
        } else if (new_y > max_y) {
            self.rect.y = max_y;
            self.dy *= -1;
        }

        if (c.SDL_HasIntersection(&self.rect, &player.rect) == c.SDL_TRUE) {
            self.rect.x = player.rect.x + player.rect.w;
            self.dx *= -1;
        }

        if (c.SDL_HasIntersection(&self.rect, &enemy.rect) == c.SDL_TRUE) {
            self.rect.x = enemy.rect.x - self.rect.w;
            self.dx *= -1;
        }

        const max_x = WINDOW_WIDTH - self.rect.w;
        const new_x = self.rect.x + self.dx;
        if (new_x >= 0 and new_x <= max_x) {
            self.rect.x = new_x;
        } else if (new_x < 0) {
            self.rect.x = (WINDOW_WIDTH - BALL_SIZE) / 2;
            self.rect.y = (WINDOW_HEIGHT - BALL_SIZE) / 2;
            self.dx *= -1;
        } else if (new_x > max_x) {
            self.rect.x = (WINDOW_WIDTH - BALL_SIZE) / 2;
            self.rect.y = (WINDOW_HEIGHT - BALL_SIZE) / 2;
            self.dx *= -1;
        }
    }

    pub fn draw(self: *Ball, renderer: *c.SDL_Renderer) void {
        _ = c.SDL_SetRenderDrawColor(renderer, 0xFF, 0xFF, 0xFF, 0xFF);
        _ = c.SDL_RenderFillRect(renderer, &self.rect);
    }
};

pub fn main() !void {
    if (c.SDL_Init(c.SDL_INIT_VIDEO) < 0) {
        c.SDL_Log("Unable to initialize SDL: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    }
    defer c.SDL_Quit();

    const window = c.SDL_CreateWindow("Zong", 0, 0, WINDOW_WIDTH, WINDOW_HEIGHT, 0) orelse
        {
        c.SDL_Log("Unable to create window: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer c.SDL_DestroyWindow(window);

    const renderer = c.SDL_CreateRenderer(window, -1, 0) orelse {
        c.SDL_Log("Unable to create window: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer c.SDL_DestroyRenderer(renderer);

    const keyboard = c.SDL_GetKeyboardState(null);

    const mid_screen = (WINDOW_HEIGHT - PADDLE_HEIGHT) / 2;
    var player = Paddle.init(PADDLE_OFFSET, mid_screen);
    var enemy = Paddle.init(WINDOW_WIDTH - PADDLE_WIDTH - PADDLE_OFFSET, mid_screen);
    var ball = Ball.init();

    var quit = false;
    while (!quit) {
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event) != 0) {
            switch (event.type) {
                c.SDL_QUIT => {
                    quit = true;
                },
                else => {},
            }
        }

        var enemy_dir: i32 = 0;
        if (keyboard[c.SDL_SCANCODE_UP] != 0) {
            enemy_dir = -1;
        }
        if (keyboard[c.SDL_SCANCODE_DOWN] != 0) {
            enemy_dir = 1;
        }

        var player_dir: i32 = 0;
        if (keyboard[c.SDL_SCANCODE_W] != 0) {
            player_dir = -1;
        }
        if (keyboard[c.SDL_SCANCODE_S] != 0) {
            player_dir = 1;
        }

        // Update players.
        player.move(player_dir);
        enemy.move(enemy_dir);
        ball.update(player, enemy);

        // Clear screen and render background.
        _ = c.SDL_SetRenderDrawColor(renderer, 0x18, 0x18, 0x18, 0xFF);
        _ = c.SDL_RenderClear(renderer);

        // Render players.
        player.draw(renderer);
        enemy.draw(renderer);
        ball.draw(renderer);

        c.SDL_RenderPresent(renderer);
        c.SDL_Delay(17);
    }
}
