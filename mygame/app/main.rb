require 'lib/screen.rb'

def tick(args)
  setup(args) if args.state.tick_count.zero?

  args.state.player_inputs = process_input(args)

  update(args)

  render(args)
end

def setup(args)
  args.state.screen = Screen::GBA_STYLE
  args.state.player = { x: 160, y: 90 }
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

  player[:x] += player[:v_x]
  player[:y] += player[:v_y]
end

def render(args)
  screen_render_target = Screen.build_render_target(args, args.state.screen)
  player = args.state.player
  screen_render_target.sprites << {
    x: player[:x] - 5, y: player[:y] - 5, w: 10, h: 10, path: :pixel,
    r: 255, g: 0, b: 0
  }
  args.outputs.sprites << Screen.sprite(args.state.screen)
end

$gtk.reset
