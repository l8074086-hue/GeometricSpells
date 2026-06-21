package main
import "vendor:raylib"

GameState :: enum {
	MAIN_MENU,
	SKILL_SELECT,
	PLAYING,
	GAME_OVER,
}

bullet :: struct {
	position: raylib.Vector2,
	size:     raylib.Vector2,
	velocity: raylib.Vector2,
	damage:   f32,
}

card :: struct {
	position:    raylib.Vector2,
	size:        raylib.Vector2,
	name:        cstring,
	description: cstring,
	hover:       bool,
}

trail_point :: struct {
	pos:  raylib.Vector2,
	life: f32,
}

enemy :: struct {
	position:  raylib.Vector2,
	size:      raylib.Vector2,
	velocity:  raylib.Vector2,
	attacking: bool,
	color:     raylib.Color,
	damage:    f32,
	hp:        f32,
}
spawn_cards :: proc(cards: ^[dynamic]card) {
	CARD_W: f32 = 120
	CARD_H: f32 = 160
	names := [3]cstring{"ATTACK", "SPEED", "HEALTH"}
	spacing: f32 = CARD_W + 40
	center_x := f32(800) / 2
	start_x := center_x - spacing - CARD_W / 2
	y := f32(600) / 2 - CARD_H / 2
	for i in 0 ..< 3 {
		pos := raylib.Vector2{start_x + spacing * f32(i), y}
		append(cards, card{pos, {CARD_W, CARD_H}, names[i], cstring("UPGRADE"), false})
	}
}

spawn_enemies :: proc(enemies: ^[dynamic]enemy, num: i32) {
	size: raylib.Vector2 = {50, 50}
	velocity: raylib.Vector2 = {0, 0}
	for _ in 0 ..< num {
		pos := raylib.Vector2 {
			f32(raylib.GetRandomValue(0, 800 - i32(size.x))),
			f32(raylib.GetRandomValue(0, 600 - i32(size.y))),
		}
		append(enemies, enemy{pos, size, velocity, false, raylib.BLUE, 10, 2})
	}
}

new_wave :: proc(enemies: ^[dynamic]enemy, wave: i32) {
	spawn_enemies(enemies, wave * 1)
}

main :: proc() {
	state: GameState = .MAIN_MENU
	windowX: i32 = 800
	windowY: i32 = 600
	debug_mode: bool = false
	raylib.InitWindow(windowX, windowY, "Roguelike")
	defer raylib.CloseWindow()

	position: raylib.Vector2 = {50, 50}
	size: raylib.Vector2 = {30, 30}
	SPEED: f32 = 200
	BULLET_SPEED: f32 = 400
	BULLET_SIZE: raylib.Vector2 = {10, 10}
	cards: [dynamic]card
	defer delete(cards)
	center: raylib.Vector2 = {}
	enemies: [dynamic]enemy

	last_dir: raylib.Vector2 = {0, -1}
	bullets: [dynamic]bullet
	defer delete(bullets)
	wave: i32 = 1
	health: f32 = 100
	max_health: f32 = 100
	player_damage: f32 = 1
	inv_timer: f32 = 0
	dash_timer: f32 = 0
	DASH_SPEED: f32 = 600
	DASH_DURATION: f32 = 0.15
	dash_cooldown: f32 = 0
	trail: [dynamic]trail_point
	defer delete(trail)
	camera: raylib.Camera2D

	for !raylib.WindowShouldClose() {
		dT := raylib.GetFrameTime()
		mousePos := raylib.GetMousePosition()
		mouse := raylib.Rectangle{mousePos.x, mousePos.y, 5, 5}

		#partial switch state {
		case .MAIN_MENU:
			if raylib.IsKeyPressed(raylib.KeyboardKey.ENTER) {
				state = .PLAYING
			}
			raylib.BeginDrawing()
			raylib.ClearBackground(raylib.BLACK)
			title := cstring("ROGUELIKE")
			tw := raylib.MeasureText(title, 60)
			color: raylib.Color = raylib.WHITE
			raylib.DrawText(title, 400 - tw / 2, 200, 60, color)
			prompt := cstring("Press ENTER to start")
			pw := raylib.MeasureText(prompt, 25)
			raylib.DrawText(prompt, 400 - pw / 2, 300, 25, raylib.GRAY)
			raylib.EndDrawing()

		case .PLAYING:
			camera.target = position + size * 0.5
			camera.offset = {400, 300}
			camera.zoom = 1
			dir := raylib.Vector2(0)
			if raylib.IsKeyDown(raylib.KeyboardKey.A) {dir.x -= 1}
			if raylib.IsKeyDown(raylib.KeyboardKey.D) {dir.x += 1}
			if raylib.IsKeyDown(raylib.KeyboardKey.W) {dir.y -= 1}
			if raylib.IsKeyDown(raylib.KeyboardKey.S) {dir.y += 1}

			if raylib.IsKeyPressed(raylib.KeyboardKey.F1) {
				debug_mode = !debug_mode
			}

			if dash_timer > 0 {
				dash_timer -= dT
				position += raylib.Vector2Normalize(last_dir) * DASH_SPEED * dT
				append(&trail, trail_point{position, 0.3})
			}
			for i := len(trail) - 1; i >= 0; i -= 1 {
				trail[i].life -= dT
				if trail[i].life <= 0 {
					unordered_remove(&trail, i)
				}
			}
			if dir != raylib.Vector2(0) && dash_timer <= 0 {
				last_dir = dir
				position += raylib.Vector2Normalize(dir) * SPEED * dT
			}
			if dash_cooldown > 0 {
				dash_cooldown -= dT
			}

			if raylib.IsKeyPressed(raylib.KeyboardKey.SPACE) {
				center = position + size * 0.5 - BULLET_SIZE * 0.5
				append(
					&bullets,
					bullet{center, BULLET_SIZE, last_dir * BULLET_SPEED, player_damage},
				)
			}
			if raylib.IsKeyPressed(raylib.KeyboardKey.LEFT_SHIFT) && dash_cooldown <= 0 {
				dash_timer = DASH_DURATION
				dash_cooldown = 0.5
				inv_timer = DASH_DURATION
			}
			if raylib.IsKeyPressed(raylib.KeyboardKey.F) {
				clear(&cards)
				spawn_cards(&cards)
			}
			if raylib.IsKeyPressed(raylib.KeyboardKey.Q) {
				pop(&cards)
			}
			if raylib.IsKeyPressed(raylib.KeyboardKey.I) && !debug_mode {
				new_wave(&enemies, wave)
				wave += 1
			}
			if raylib.IsMouseButtonPressed(raylib.MouseButton.LEFT) {
				for i := len(cards) - 1; i >= 0; i -= 1 {
					card_rect := raylib.Rectangle {
						cards[i].position.x,
						cards[i].position.y,
						cards[i].size.x,
						cards[i].size.y,
					}
					if raylib.CheckCollisionRecs(mouse, card_rect) {
						if cards[i].name == "SPEED" {
							SPEED += 50
						} else if cards[i].name == "ATTACK" {
							player_damage += 1
						} else if cards[i].name == "HEALTH" {
							max_health += 25
							health = max_health
						}
						clear(&cards)
						if !debug_mode {
							new_wave(&enemies, wave)
						}
						wave += 1
						break
					}
				}
			}

			for i := len(bullets) - 1; i >= 0; i -= 1 {
				bullets[i].position += bullets[i].velocity * dT
				p := bullets[i].position
				s := bullets[i].size
				if raylib.Vector2Distance(p, position) > 800 {
					unordered_remove(&bullets, i)
					continue
				}
				for j := len(enemies) - 1; j >= 0; j -= 1 {
					if raylib.CheckCollisionRecs(
						{p.x, p.y, s.x, s.y},
						{
							enemies[j].position.x,
							enemies[j].position.y,
							enemies[j].size.x,
							enemies[j].size.y,
						},
					) {
						enemies[j].hp -= bullets[i].damage
						unordered_remove(&bullets, i)
						if enemies[j].hp <= 0 {
							unordered_remove(&enemies, j)
						}
						break
					}
				}
			}

			ENEMY_SPEED: f32 = 80
			for i := len(enemies) - 1; i >= 0; i -= 1 {
				e := &enemies[i]
				e_dir := raylib.Vector2Normalize(position - e.position)
				e.position += e_dir * ENEMY_SPEED * dT
			}

			if inv_timer > 0 {
				inv_timer -= dT
			}
			player_rect := raylib.Rectangle{position.x, position.y, size.x, size.y}
			for i := len(enemies) - 1; i >= 0; i -= 1 {
				enemy_rect := raylib.Rectangle {
					enemies[i].position.x,
					enemies[i].position.y,
					enemies[i].size.x,
					enemies[i].size.y,
				}
				if raylib.CheckCollisionRecs(player_rect, enemy_rect) {
					if inv_timer <= 0 {
						health -= enemies[i].damage
						inv_timer = 0.5
					}
					if health <= 0 {
						state = .GAME_OVER
					}
				}
			}

			if len(enemies) == 0 && len(cards) == 0 && (!debug_mode || wave == 1) {
				spawn_cards(&cards)
			}

			raylib.BeginDrawing()
			raylib.ClearBackground(raylib.BLACK)
			raylib.BeginMode2D(camera)
			for t in trail {
				a := u8(80 * (t.life / 0.3))
				raylib.DrawRectangleV(t.pos, size, raylib.Color{255, 0, 0, a})
			}
			raylib.DrawRectangleV(position, size, raylib.RED)
			for b in bullets {
				raylib.DrawRectangleV(b.position, b.size, raylib.YELLOW)
			}
			for e in enemies {
				raylib.DrawRectangleV(e.position, e.size, e.color)
			}
			raylib.EndMode2D()
			for &c in cards {
				card_rect := raylib.Rectangle{c.position.x, c.position.y, c.size.x, c.size.y}
				c.hover = raylib.CheckCollisionRecs(mouse, card_rect)
				color := c.hover ? raylib.VIOLET : raylib.DARKPURPLE
				raylib.DrawRectangleV(c.position, c.size, color)
				padding: i32 = 10
				fs: i32 = 25
				for fs > 6 && raylib.MeasureText(c.name, fs) > i32(c.size.x) - padding * 2 {
					fs -= 1
				}
				raylib.DrawText(
					c.name,
					i32(c.position.x) + padding,
					i32(c.position.y) + padding,
					fs,
					raylib.BLACK,
				)
				raylib.DrawText(
					c.description,
					i32(c.position.x),
					i32(c.position.y) + 30,
					25,
					raylib.BLACK,
				)
			}
			raylib.DrawRectangleV(mousePos, {5, 5}, raylib.GREEN)
			raylib.DrawRectangle(10, 10, 200, 20, raylib.RED)
			raylib.DrawRectangle(10, 10, i32(200 * health / max_health), 20, raylib.GREEN)
			raylib.DrawRectangleLines(10, 10, 200, 20, raylib.WHITE)
			if debug_mode {
				raylib.DrawText("DEBUG", 220, 10, 20, raylib.ORANGE)
			}
			raylib.EndDrawing()

		case .GAME_OVER:
			if raylib.IsKeyPressed(raylib.KeyboardKey.ENTER) {
				position = {50, 50}
				SPEED = 200
				health = 100
				max_health = 100
				player_damage = 1
				wave = 1
				inv_timer = 0
				dash_timer = 0
				dash_cooldown = 0
				clear(&enemies)
				clear(&bullets)
				clear(&cards)
				clear(&trail)
				state = .MAIN_MENU
			}
			raylib.BeginDrawing()
			raylib.ClearBackground(raylib.BLACK)
			game_over := cstring("GAME OVER")
			gw := raylib.MeasureText(game_over, 60)
			raylib.DrawText(game_over, 400 - gw / 2, 200, 60, raylib.RED)
			prompt := cstring("Press ENTER to restart")
			pw := raylib.MeasureText(prompt, 25)
			raylib.DrawText(prompt, 400 - pw / 2, 300, 25, raylib.GRAY)
			raylib.EndDrawing()
		}
	}
}
