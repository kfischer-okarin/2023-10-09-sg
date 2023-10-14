require 'app/colors.rb'
require 'app/collision.rb'
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
  args.state.screen = Screen::GBA_STYLE
  args.state.game_state = :playing
  args.state.player = Player.build(x: 1600, y: 900)
  args.state.crescent_moon = {
    x: 2000, y: 1000, w: 11, h: 11,
    face_angle: 0, v_x: 0, v_y: 0,
    state: { type: :movement },
    collision_radius: 50
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
  Player.tick(args, args.state.player)
  return if args.state.game_state == :won

  scale = WORLD_TO_SCREEN_SCALE
  args.state.moving_entities.each do |entity|
    if moving_diagonally?(entity) && (entity[:x] % scale) != (entity[:y] % scale)
      entity[:x] = (entity[:x] / scale).round * scale
      entity[:y] = (entity[:y] / scale).round * scale
    end
    entity[:x] += entity[:v_x]
    entity[:y] += entity[:v_y]
  end
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

  screen_render_target.sprites << crescent_moon_sprite(args.state.crescent_moon)

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

  if args.state.game_state == :won && player_state[:type] == :movement
    screen_render_target.labels << {
      x: 160, y: 90, text: 'You Win!', size_px: 39, font: 'fonts/notalot.ttf',
      alignment_enum: 1, vertical_alignment_enum: 1, **Colors::TEXT
    }
  end

  args.outputs.sprites << Screen.sprite(screen)
  args.outputs.labels << { x: 0, y: 720, text: args.gtk.current_framerate.to_i.to_s, **Colors::TEXT }
end

def crescent_moon_sprite(crescent_moon)
  color = crescent_moon[:state][:type] == :dead ? Colors::BLOOD : Colors::CRESCENT_MOON
  {
    x: scaled_to_screen(crescent_moon[:x]) - crescent_moon[:w].idiv(2),
    y: scaled_to_screen(crescent_moon[:y]) - crescent_moon[:h].idiv(2),
    w: crescent_moon[:w],
    h: crescent_moon[:h],
    path: 'sprites/crescent.png',
    **color
  }
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

def player_charge_particle(player, circle_sprite)
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
  sprite
end

WORLD_TO_SCREEN_SCALE = 10

def scaled_to_screen(value)
  (value / WORLD_TO_SCREEN_SCALE).round
end

$gtk.reset
