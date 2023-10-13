require 'app/colors.rb'
require 'app/collision.rb'
require 'lib/animations.rb'
require 'lib/screen.rb'

def tick(args)
  setup(args) if args.state.tick_count.zero?

  args.state.player_inputs = process_input(args)

  update(args)

  render(args)
end

def setup(args)
  args.state.screen = Screen::GBA_STYLE
  args.state.game_state = :playing
  args.state.player = {
    x: 160, y: 90, w: 9, h: 9,
    face_angle: 0, v_x: 0, v_y: 0,
    state: { type: :movement }
  }
  args.state.crescent_moon = {
    x: 200, y: 100, w: 11, h: 11,
    face_angle: 0, v_x: 0, v_y: 0,
    state: { type: :movement }
  }
  args.state.moving_entities = [
    args.state.player,
    args.state.crescent_moon
  ]
  args.state.enemies = [
    args.state.crescent_moon
  ]
  args.state.charge_particles = []
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
    charge: keyboard_key_down.space || keyboard_key_held.space
  }
end

def update(args)
  player = args.state.player
  player_state = player[:state]

  send("handle_player_#{player_state[:type]}", args, player)
  return if args.state.game_state == :won

  args.state.moving_entities.each do |entity|
    entity[:x] += entity[:v_x]
    entity[:y] += entity[:v_y]
  end
end

def handle_player_movement(args, player)
  return if args.state.game_state == :won

  player_inputs = args.state.player_inputs

  update_player_velocity(player, player_inputs)
  update_face_angle(player, player[:v_x], player[:v_y]) if moving?(player)
  return unless player_inputs[:charge]

  start_charging(args, player)
end

def update_player_velocity(player, player_inputs)
  player[:v_x] = 0
  player[:v_y] = 0

  if player_inputs[:left]
    player[:v_x] -= 1
  elsif player_inputs[:right]
    player[:v_x] += 1
  end

  if player_inputs[:up]
    player[:v_y] += 1
  elsif player_inputs[:down]
    player[:v_y] -= 1
  end
end

def update_face_angle(entity, direction_x, direction_y)
  entity[:face_angle] = Math.atan2(direction_y, direction_x)
end

def moving?(entity)
  entity[:v_x].nonzero? || entity[:v_y].nonzero?
end

def start_charging(args, player)
  player[:state] = { type: :charging, ticks: 0, power: 0 }
  player[:v_x] = 0
  player[:v_y] = 0

  args.state.charge_particles = []
end

def handle_player_charging(args, player)
  player_inputs = args.state.player_inputs
  charging_state = player[:state]

  if player_inputs[:charge]
    charging_state[:ticks] += 1
    charging_state[:power] = [charging_state[:ticks], 120].min
    charging_state[:ready] = charging_state[:power] >= 40

    particles = args.state.charge_particles
    particles << player_charge_particle(player, args.state.sprites.circle)

    particles.each do |particle|
      Animations.perform_tick(particle[:animation])
      particle[:x] = player[:x] + Math.cos(particle[:angle_from_player]) * particle[:distance]
      particle[:y] = player[:y] + Math.sin(particle[:angle_from_player]) * particle[:distance]
    end
    particles.reject! { |particle| Animations.finished?(particle[:animation]) }

    charging_state[:predicted_distance] = predict_rush_distance(player) if charging_state[:ready]
  else
    if charging_state[:ready]
      player[:state] = { type: :rushing, power: charging_state[:power] }
    else
      player[:state] = { type: :movement }
    end
  end
end

def predict_rush_distance(player)
  simulated_player = player.dup
  simulated_player[:state] = { type: :rushing, power: player[:state][:power] }
  distance_x = 0
  distance_y = 0
  until simulated_player[:state][:power].zero?
    execute_rush(simulated_player)
    distance_x += simulated_player[:v_x]
    distance_y += simulated_player[:v_y]
  end
  Math.sqrt((distance_x**2) + (distance_y**2))
end

def handle_player_rushing(args, player)
  rushing_state = player[:state]
  execute_rush(player)

  damage_enemies_hit_by_rush(player, args.state.enemies)
  args.state.game_state = :won if args.state.enemies.all? { |enemy| enemy[:state][:type] == :dead }

  player[:state] = { type: :movement } if rushing_state[:power].zero?
end

def execute_rush(player)
  rushing_state = player[:state]
  rushing_state[:power] = [rushing_state[:power] - 10, 0].max
  return if rushing_state[:power].zero?

  rush_speed = rushing_state[:power].idiv(2)
  player[:v_x] = Math.cos(player[:face_angle]) * rush_speed
  player[:v_y] = Math.sin(player[:face_angle]) * rush_speed
end

def damage_enemies_hit_by_rush(player, enemies)
  enemies.each do |enemy|
    has_collided = sphere_capsule_collision?(
      enemy[:x], enemy[:y], 5,
      player[:x], player[:y], player[:x] + player[:v_x], player[:y] + player[:v_y], 5
    )
    next unless has_collided

    enemy[:state] = { type: :dead, ticks: 0 }
  end
end

def render(args)
  screen = args.state.screen
  screen_render_target = Screen.build_render_target(args, screen)
  screen_render_target.sprites << {
    x: 0, y: 0, w: screen[:x_resolution], h: screen[:y_resolution],
    path: :pixel, **Colors::BACKGROUND
  }

  screen_render_target.sprites << crescent_moon_sprite(args.state.crescent_moon)

  player = args.state.player
  screen_render_target.sprites << player_sprite(player)
  player_facing_triangle = facing_triangle(player, args.state.sprites.triangle)

  player_state = player[:state]
  case player_state[:type]
  when :charging
    screen_render_target.sprites << args.state.charge_particles
    player_facing_triangle[:a] = 128
    if player_state[:ready]
      player_facing_triangle = facing_triangle(
        player,
        args.state.sprites.triangle.merge(w: player_state[:predicted_distance], a: 128),
        distance: 10 + player_state[:predicted_distance].idiv(2)
      )
    end
  end

  screen_render_target.sprites << player_facing_triangle

  if args.state.game_state == :won && player_state[:type] == :movement
    screen_render_target.labels << {
      x: 160, y: 90, text: 'You Win!', size_px: 39, font: 'fonts/notalot.ttf',
      alignment_enum: 1, vertical_alignment_enum: 1, **Colors::TEXT
    }
  end

  args.outputs.sprites << Screen.sprite(screen)
  args.outputs.labels << { x: 0, y: 720, text: args.gtk.current_framerate.to_i.to_s, **Colors::TEXT }
end

def player_sprite(player)
  {
    x: player[:x] - player[:w].idiv(2),
    y: player[:y] - player[:h].idiv(2),
    w: player[:w],
    h: player[:h],
    path: :pixel,
    **Colors::PLAYER
  }
end

def crescent_moon_sprite(crescent_moon)
  color = crescent_moon[:state][:type] == :dead ? Colors::BLOOD : Colors::CRESCENT_MOON
  {
    x: crescent_moon[:x] - crescent_moon[:w].idiv(2),
    y: crescent_moon[:y] - crescent_moon[:h].idiv(2),
    w: crescent_moon[:w],
    h: crescent_moon[:h],
    path: 'sprites/crescent.png',
    **color
  }
end

def facing_triangle(entity, triangle_sprite, distance: 10)
  triangle_sprite.to_sprite(
    x: entity[:x] + Math.cos(entity[:face_angle]) * distance - triangle_sprite[:w].idiv(2),
    y: entity[:y] + Math.sin(entity[:face_angle]) * distance - triangle_sprite[:h].idiv(2),
    angle: entity[:face_angle].to_degrees,
    angle_anchor_x: 0.5, angle_anchor_y: 0.5,
    **Colors::DIRECTION_TRIANGLE
  )
end

def player_charge_particle(player, circle_sprite)
  sprite = circle_sprite.to_sprite(
    angle_from_player: rand * 2 * Math::PI,
    distance: 30,
    w: 11, h: 11,
    r: 255, g: 128, b: 0, a: 128
  )
  sprite[:animation] = Animations.lerp(
    sprite,
    to: { distance: 0, a: 255, w: 1, h: 1 },
    duration: 20
  )
  sprite
end

$gtk.reset
