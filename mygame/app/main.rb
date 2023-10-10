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
    puts segment_w
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
    unless player[:v_x].zero? && player[:v_y].zero?
      player[:x] += player[:v_x]
      player[:y] += player[:v_y]
      player[:face_angle] = Math.atan2(player[:v_y], player[:v_x])
    end

    if player_inputs[:charge]
      player[:state] = { type: :charging, ticks: 0, power: 0 }
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
      execute_rush(simulation_player) until simulation_player[:state][:power].zero?
      player_state[:predicted_distance] = Math.sqrt(
        (player[:x] - simulation_player[:x])**2 +
        (player[:y] - simulation_player[:y])**2
      )
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
end

def execute_rush(player)
  rushing_state = player[:state]
  rushing_state[:power] = [rushing_state[:power] - 10, 0].max
  return if rushing_state[:power].zero?

  rush_speed = rushing_state[:power].idiv(2)
  player[:x] += Math.cos(player[:face_angle]) * rush_speed
  player[:y] += Math.sin(player[:face_angle]) * rush_speed
end

def render(args)
  screen = args.state.screen
  screen_render_target = Screen.build_render_target(args, screen)
  screen_render_target.sprites << {
    x: 0, y: 0, w: screen[:x_resolution], h: screen[:y_resolution],
    path: :pixel, **Colors::BACKGROUND
  }
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

module DawnBringer32
  BLACK = { r: 0x00, g: 0x00, b: 0x00 }.freeze
  ALMOST_BLACK = { r: 0x22, g: 0x20, b: 0x34 }.freeze
  DARK_BROWN = { r: 0x45, g: 0x28, b: 0x3c }.freeze
  BROWN = { r: 0x66, g: 0x39, b: 0x31 }.freeze
  LIGHT_BROWN = { r: 0x8f, g: 0x56, b: 0x3b }.freeze
  ORANGE = { r: 0xdf, g: 0x71, b: 0x26 }.freeze
  TAN = { r: 0xd9, g: 0xa0, b: 0x66 }.freeze
  SKIN = { r: 0xee, g: 0xc3, b: 0x9a }.freeze
  YELLOW = { r: 0xfb, g: 0xf2, b: 0x36 }.freeze
  KIWI = { r: 0x99, g: 0xe5, b: 0x50 }.freeze
  GREEN = { r: 0x6a, g: 0xbe, b: 0x30 }.freeze
  CYAN = { r: 0x37, g: 0x94, b: 0x6e }.freeze
  DARK_OLIVE_GREEN = { r: 0x4b, g: 0x69, b: 0x2f }.freeze
  ARMY_GREEN = { r: 0x52, g: 0x4b, b: 0x24 }.freeze
  ONYX = { r: 0x32, g: 0x3c, b: 0x39 }.freeze
  AMERICAN_BLUE = { r: 0x3f, g: 0x3f, b: 0x74 }.freeze
  METALLIC_BLUE = { r: 0x30, g: 0x60, b: 0x82 }.freeze
  ROYAL_BLUE = { r: 0x5b, g: 0x6e, b: 0xe1 }.freeze
  CORNFLOWER_BLUE = { r: 0x63, g: 0x9b, b: 0xff }.freeze
  SKY_BLUE = { r: 0x5f, g: 0xcd, b: 0xe4 }.freeze
  LAVENDER_BLUE = { r: 0xcb, g: 0xdb, b: 0xfc }.freeze
  WHITE = { r: 0xff, g: 0xff, b: 0xff }.freeze
  CADET_GREY = { r: 0x9b, g: 0xad, b: 0xb7 }.freeze
  OLD_SILVER = { r: 0x84, g: 0x7e, b: 0x87 }.freeze
  DIM_GRAY = { r: 0x69, g: 0x6a, b: 0x6a }.freeze
  GRAY = { r: 0x52, g: 0x55, b: 0x59 }.freeze
  VIOLET = { r: 0x76, g: 0x42, b: 0x8a }.freeze
  RED = { r: 0xac, g: 0x32, b: 0x32 }.freeze
  LIGHT_RED = { r: 0xd9, g: 0x57, b: 0x63 }.freeze
  PINK = { r: 0xd7, g: 0x7b, b: 0xba }.freeze
  MOSS_GREEN = { r: 0x8f, g: 0x97, b: 0x41 }.freeze
  ANOTHER_BROWN = { r: 0x8a, g: 0x6f, b: 0x30 }.freeze
end

module Colors
  BACKGROUND = DawnBringer32::GRAY
  TEXT = DawnBringer32::WHITE
  DIRECTION_TRIANGLE = DawnBringer32::WHITE
  PLAYER = DawnBringer32::LAVENDER_BLUE
end

$gtk.reset
