require 'app/colors.rb'
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
  args.state.player = {
    x: 160, y: 90, w: 9, h: 9,
    face_angle: 0, v_x: 0, v_y: 0,
    state: { type: :normal }
  }
  args.state.crescent_moon = {
    x: 200, y: 100, w: 11, h: 11,
    face_angle: 0, v_x: 0, v_y: 0,
    state: { type: :normal }
  }
  args.state.moving_entities = [
    args.state.player,
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
    charge: keyboard_key_down.space || keyboard_key_held.space,
  }
end

def update(args)
  player_inputs = args.state.player_inputs
  player = args.state.player
  player_state = player[:state]
  case player_state[:type]
  when :normal
    player[:v_x] = 0
    player[:v_y] = 0

    if player_inputs[:left]
      player[:v_x] = - 1
    elsif player_inputs[:right]
      player[:v_x] = 1
    end

    if player_inputs[:up]
      player[:v_y] = 1
    elsif player_inputs[:down]
      player[:v_y] = -1
    end

    player[:face_angle] = Math.atan2(player[:v_y], player[:v_x]) unless player[:v_x].zero? && player[:v_y].zero?

    if player_inputs[:charge]
      player[:state] = { type: :charging, ticks: 0, power: 0 }
      player[:v_x] = 0
      player[:v_y] = 0
      args.state.charge_particles = []
    end
  when :charging
    player_state[:ticks] += 1
    player_state[:power] = [player_state[:ticks], 120].min
    player_state[:ready] = player_state[:power] >= 40

    args.state.charge_particles << player_charge_particle(player, args.state.sprites.circle)

    args.state.charge_particles.each do |particle|
      Animations.perform_tick(particle[:animation])
      particle[:x] = player[:x] + Math.cos(particle[:angle_from_player]) * particle[:distance]
      particle[:y] = player[:y] + Math.sin(particle[:angle_from_player]) * particle[:distance]
    end
    args.state.charge_particles.reject! { |particle| Animations.finished?(particle[:animation]) }

    if player_state[:ready]
      simulation_player = player.dup
      simulation_player[:state] = { type: :rushing, power: player_state[:power] }
      distance_x = 0
      distance_y = 0
      until simulation_player[:state][:power].zero?
        execute_rush(simulation_player)
        distance_x += simulation_player[:v_x]
        distance_y += simulation_player[:v_y]
      end
      player_state[:predicted_distance] = Math.sqrt(distance_x**2 + distance_y**2)
    end

    unless player_inputs[:charge]
      if player_state[:ready]
        player[:state] = { type: :rushing, power: player_state[:power] }
      else
        player[:state] = { type: :normal }
      end
    end
  when :rushing
    execute_rush(player)
    player[:state] = { type: :normal } if player_state[:power].zero?
  end

  args.state.moving_entities.each do |entity|
    entity[:x] += entity[:v_x]
    entity[:y] += entity[:v_y]
  end
end

def execute_rush(player)
  rushing_state = player[:state]
  rushing_state[:power] = [rushing_state[:power] - 10, 0].max
  return if rushing_state[:power].zero?

  rush_speed = rushing_state[:power].idiv(2)
  player[:v_x] = Math.cos(player[:face_angle]) * rush_speed
  player[:v_y] = Math.sin(player[:face_angle]) * rush_speed
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
  {
    x: crescent_moon[:x] - crescent_moon[:w].idiv(2),
    y: crescent_moon[:y] - crescent_moon[:h].idiv(2),
    w: crescent_moon[:w],
    h: crescent_moon[:h],
    path: 'sprites/crescent.png',
    **Colors::CRESCENT_MOON
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
