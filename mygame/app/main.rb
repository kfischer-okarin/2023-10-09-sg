require 'app/colors.rb'
require 'app/collision.rb'
require 'app/enemies/crescent_moon.rb'
require 'app/player.rb'
require 'lib/animations.rb'
require 'lib/screen.rb'

def tick(args)
  setup(args) if args.state.tick_count.zero?

  args.state.player_inputs = process_input(args)

  update(args)

  render(args)
end

def setup(args)
  args.state.debug_allowed = !$gtk.production?
  args.state.screen = Screen::GBA_STYLE
  args.state.game_state = :playing
  args.state.player = Player.build(x: 1600, y: 900)
  args.state.crescent_moon = Enemies::CrescentMoon.build(x: 2000, y: 1000)
  args.state.moving_entities = [
    args.state.player,
    args.state.crescent_moon
  ]
  args.state.enemies = [
    args.state.crescent_moon
  ]
  args.state.charge_particles = []
  args.state.projectiles = []
  args.state.paused = false
  args.state.animations = []
  args.state.screen_flash = {
    x: 0, y: 0, w: args.state.screen[:x_resolution], h: args.state.screen[:y_resolution],
    path: :pixel, a: 0
  }
  prepare_sprites(args)
end

def prepare_sprites(args)
  args.state.sprites.triangle = prepare_triangle_sprite(args)
  args.state.sprites.circle = prepare_circle_sprite(args, :circle)
end

def prepare_triangle_sprite(args)
  render_target = args.outputs[:triangle]
  render_target.width = 3
  render_target.height = 5
  render_target.sprites << [
    { x: 0, y: 0, w: 1, h: 5, path: :pixel },
    { x: 1, y: 1, w: 1, h: 3, path: :pixel },
    { x: 2, y: 2, w: 1, h: 1, path: :pixel }
  ]
  { w: 3, h: 5, path: :triangle }
end

def prepare_circle_sprite(args, name, radius: 5)
  diameter = (radius * 2) + 1
  radius_squared = radius**2
  render_target = args.outputs[name]
  render_target.width = diameter
  render_target.height = diameter
  render_target.sprites << (0..radius).map do |y|
    segment_w = (2 * Math.sqrt(radius_squared - ((y + 0.5) - radius)**2)).round
    segment_w += 1 if segment_w.even?
    segment_x = (radius - segment_w.idiv(2)).floor
    [
      { x: segment_x, y: y, w: segment_w, h: 1, path: :pixel },
      { x: segment_x, y: diameter - y - 1, w: segment_w, h: 1, path: :pixel }
    ]
  end
  { w: diameter, h: diameter, path: name }
end

def process_input(args)
  keyboard_key_down = args.inputs.keyboard.key_down
  keyboard_key_held = args.inputs.keyboard.key_held
  left_right = args.inputs.left_right
  up_down = args.inputs.up_down
  {
    left: left_right.negative?,
    right: left_right.positive?,
    up: up_down.positive?,
    down: up_down.negative?,
    charge: keyboard_key_down.space || keyboard_key_held.space,
    pause: keyboard_key_down.escape,
    toggle_force_debug: keyboard_key_down.one
  }
end

def update(args)
  args.state.paused = !args.state.paused if args.state.player_inputs[:pause]

  unless args.state.paused
    player = args.state.player
    Player.tick(args, player)
    return if %i[won lost].include? args.state.game_state

    args.state.enemies.each do |enemy|
      next if enemy[:state][:type] == :dead

      enemy[:type].tick(args, enemy)
    end

    projectiles = args.state.projectiles
    projectiles.each do |projectile|
      projectile[:type].tick(args, projectile)
    end
    projectiles.select! { |projectile| projectile[:alive] }

    Player.handle_hits(args, player)

    (args.state.moving_entities + args.state.projectiles).each do |entity|
      entity[:x] += entity[:v_x]
      entity[:y] += entity[:v_y]
    end
  end

  handle_debug(args) if args.state.debug_allowed
end

def update_face_angle(entity, direction_x, direction_y)
  entity[:face_angle] = Math.atan2(direction_y, direction_x)
end

def moving?(entity)
  entity[:v_x].nonzero? || entity[:v_y].nonzero?
end

def moving_diagonally?(entity)
  entity[:v_x].nonzero? && entity[:v_y].nonzero?
end

def moving_entity_collisions(entity, targets)
  targets.select { |target|
    Collision.sphere_capsule_collision?(
      target[:x], target[:y], target[:collision_radius],
      entity[:x], entity[:y], entity[:x] + entity[:v_x], entity[:y] + entity[:v_y], entity[:collision_radius]
    )
  }
end

def render(args)
  screen = args.state.screen
  screen_render_target = Screen.build_render_target(args, screen)
  screen_render_target.sprites << {
    x: 0, y: 0, w: screen[:x_resolution], h: screen[:y_resolution],
    path: :pixel, **Colors::BACKGROUND
  }

  args.state.animations.each do |animation|
    Animations.perform_tick animation
  end
  args.state.animations.reject! { |animation| Animations.finished? animation }

  screen_render_target.sprites << Enemies::CrescentMoon.sprite(args.state.crescent_moon)

  player = args.state.player
  screen_render_target.sprites << Player.sprite(player)
  player_facing_triangle = facing_triangle(player, args.state.sprites.triangle)

  player_state = player[:state]
  case player_state[:type]
  when :charging
    screen_render_target.sprites << args.state.charge_particles
    player_facing_triangle[:a] = 128
    if player_state[:ready]
      predicted_distance_on_screen = scaled_to_screen(player_state[:predicted_distance])
      player_facing_triangle = facing_triangle(
        player,
        args.state.sprites.triangle.merge(w: predicted_distance_on_screen, a: 128),
        distance: 10 + predicted_distance_on_screen.idiv(2)
      )
    end
  end

  screen_render_target.sprites << player_facing_triangle

  screen_render_target.sprites << args.state.projectiles.map { |projectile|
    projectile.merge(x: scaled_to_screen(projectile[:x]), y: scaled_to_screen(projectile[:y]))
  }

  screen_render_target.sprites << Player.hp_bar_sprite(player)

  screen_render_target.sprites << args.state.screen_flash

  game_state = args.state.game_state
  if game_state == :won && player_state[:type] == :movement
    screen_render_target.labels << {
      x: 160, y: 90, text: 'You Win!', size_px: 39, font: 'fonts/notalot.ttf',
      alignment_enum: 1, vertical_alignment_enum: 1, **Colors::TEXT
    }
  end

  if game_state == :lost && player_state[:type] == :movement
    screen_render_target.labels << {
      x: 160, y: 90, text: 'You Lose!', size_px: 39, font: 'fonts/notalot.ttf',
      alignment_enum: 1, vertical_alignment_enum: 1, **Colors::TEXT
    }
  end

  if args.state.paused
    screen_render_target.labels << {
      x: 160, y: 120, text: 'Paused', size_px: 13, font: 'fonts/notalot.ttf',
      alignment_enum: 1, vertical_alignment_enum: 1, **Colors::TEXT
    }
  end

  args.outputs.sprites << Screen.sprite(screen)
  args.outputs.labels << { x: 0, y: 720, text: args.gtk.current_framerate.to_i.to_s, **Colors::TEXT }

  render_debug(args, screen_render_target) if args.state.debug_allowed
end

def facing_triangle(entity, triangle_sprite, distance: 10)
  triangle_sprite.to_sprite(
    x: scaled_to_screen(entity[:x]) + Math.cos(entity[:face_angle]) * distance - triangle_sprite[:w].idiv(2),
    y: scaled_to_screen(entity[:y]) + Math.sin(entity[:face_angle]) * distance - triangle_sprite[:h].idiv(2),
    angle: entity[:face_angle].to_degrees,
    angle_anchor_x: 0.5, angle_anchor_y: 0.5,
    **Colors::DIRECTION_TRIANGLE
  )
end

def player_charge_particle(args, circle_sprite)
  sprite = circle_sprite.to_sprite(
    angle_from_player: rand * 2 * Math::PI,
    distance: 300,
    w: 11, h: 11,
    r: 255, g: 128, b: 0, a: 128
  )
  sprite[:animation] = Animations.lerp(
    sprite,
    to: { distance: 0, a: 255, w: 1, h: 1 },
    duration: 20
  )
  args.state.animations << sprite[:animation]
  sprite
end

WORLD_TO_SCREEN_SCALE = 10

def scaled_to_screen(value)
  (value / WORLD_TO_SCREEN_SCALE).round
end

def handle_debug(args)
  player_inputs = args.state.player_inputs
  args.state.force_debug = !args.state.force_debug if player_inputs[:toggle_force_debug]
end

def render_debug(args, screen_render_target)
  args.state.debug_label_y = 720
  render_force_debug(args, screen_render_target) if args.state.force_debug
end

def render_force_debug(args, screen_render_target)
  args.outputs.labels << {
    x: 1280, y: args.state.debug_label_y, text: 'FORCE DEBUG', alignment_enum: 2,
    **Colors::TEXT
  }
  args.state.debug_label_y -= 20

  mouse_position = { x: args.inputs.mouse.x, y: args.inputs.mouse.y }
  screen_mouse_position = Screen.to_screen_position(args.state.screen, mouse_position)
  world_mouse_position = {
    x: screen_mouse_position.x * WORLD_TO_SCREEN_SCALE,
    y: screen_mouse_position.y * WORLD_TO_SCREEN_SCALE
  }
  player = args.state.player

  x = mouse_position[:x] + 10
  y = mouse_position[:y] + 50
  args.outputs.labels << {
    x: x, y: y, text: "World Position: #{world_mouse_position}",
    **Colors::TEXT
  }
  y -= 20
  crescent_moon = args.state.crescent_moon
  crescent_moon_state = crescent_moon[:state]
  if crescent_moon[:state][:attack_position]
    goal_attraction_force = Enemies::CrescentMoon.goal_attraction_force(
      crescent_moon_state[:attack_position],
      world_mouse_position
    )
    screen_render_target.sprites << {
      x: scaled_to_screen(crescent_moon_state[:attack_position][:x]) - 1,
      y: scaled_to_screen(crescent_moon_state[:attack_position][:y]) - 1,
      w: 3, h: 3, path: :circle, **Colors::TEXT
    }
    args.outputs.labels << {
      x: x, y: y, text: "Goal Attraction: #{format_vector(goal_attraction_force)}",
      **Colors::TEXT
    }
    y -= 20
  end
  player_repulsion_force = Enemies::CrescentMoon.player_repulsion_force(player, world_mouse_position)
  args.outputs.labels << {
    x: x, y: y, text: "Player Repulsion: #{format_vector(player_repulsion_force)}",
    **Colors::TEXT
  }
end

def positions_around(position, distance:, count: 8)
  offset = rand * (Math::PI / 4)
  angle_between_positions = (2 * Math::PI) / count
  (0...count).map { |i|
    angle = offset + (angle_between_positions * i)
    {
      x: position[:x] + Math.cos(angle) * distance,
      y: position[:y] + Math.sin(angle) * distance
    }
  }
end

def on_screen?(position)
  position[:x].between?(0, 3199) && position[:y].between?(0, 1799)
end

def point_inside_rect?(point, rect)
  point[:x].between?(rect[:x], rect[:x] + rect[:w] - 1) &&
    point[:y].between?(rect[:y], rect[:y] + rect[:h] - 1)
end

def unit_vector(vector)
  length = Math.sqrt((vector[:x] * vector[:x]) + (vector[:y] * vector[:y]))
  { x: vector[:x] / length, y: vector[:y] / length }
end

def format_vector(vector)
  '[%.2f, %.2f] (%.2f)' % [vector[:x], vector[:y], Math.sqrt((vector[:x] * vector[:x]) + (vector[:y] * vector[:y]))]
end

$gtk.reset
