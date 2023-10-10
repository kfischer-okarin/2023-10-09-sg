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
    face_angle: 0, v_x: 0, v_y: 0
  }
  prepare_sprites(args)
end

def prepare_sprites(args)
  args.state.sprites.triangle = prepare_triangle_sprite(args)
end

def prepare_triangle_sprite(args)
  render_target = args.outputs[:triangle]
  render_target.width = 5
  render_target.height = 5
  render_target.sprites << [
    { x: 0, y: 0, w: 1, h: 5, path: :pixel },
    { x: 1, y: 1, w: 1, h: 3, path: :pixel },
    { x: 2, y: 2, w: 1, h: 1, path: :pixel }
  ]
  { w: 5, h: 5, path: :triangle }
end

def process_input(args)
  left_right = args.inputs.left_right
  up_down = args.inputs.up_down
  {
    left: left_right.negative?,
    right: left_right.positive?,
    up: up_down.positive?,
    down: up_down.negative?
  }
end

def update(args)
  player_inputs = args.state.player_inputs
  player = args.state.player
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
  return if player[:v_x].zero? && player[:v_y].zero?

  player[:x] += player[:v_x]
  player[:y] += player[:v_y]
  player[:face_angle] = Math.atan2(player[:v_y], player[:v_x])
end

def render(args)
  screen_render_target = Screen.build_render_target(args, args.state.screen)
  player = args.state.player
  screen_render_target.sprites << [
    player_sprite(player),
    facing_triangle(player, args.state.sprites.triangle)
  ]

  args.outputs.sprites << Screen.sprite(args.state.screen)
end

def player_sprite(player)
  {
    x: player[:x] - player[:w].idiv(2),
    y: player[:y] - player[:h].idiv(2),
    w: player[:w],
    h: player[:h],
    path: :pixel,
    r: 255, g: 0, b: 0
  }
end

def facing_triangle(entity, triangle_sprite, distance: 10)
  triangle_sprite.to_sprite(
    x: entity[:x] + Math.cos(entity[:face_angle]) * distance - triangle_sprite[:w].idiv(2),
    y: entity[:y] + Math.sin(entity[:face_angle]) * distance - triangle_sprite[:h].idiv(2),
    r: 0, g: 0, b: 0,
    angle: entity[:face_angle].to_degrees,
    angle_anchor_x: 0.5, angle_anchor_y: 0.5
  )
end

$gtk.reset
