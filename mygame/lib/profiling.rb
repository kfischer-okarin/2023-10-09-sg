module Profiling
  class << self
    def activate(window_size: 60)
      top_level_tick = $top_level.method(:tick)
      times = []
      $top_level.define_singleton_method(:tick) do |args|
        start_time = Time.now.to_f
        top_level_tick.call(args)
        times << (Time.now.to_f - start_time) * 1000
        p times.last
        times.shift if times.size > window_size

        x = 10
        y = 650
        times.each_with_index do |duration, index|
          color = duration > 16 ? { r: 255, g: 0, b: 0 } : { r: 0, g: 255, b: 0 }
          args.outputs.sprites << {
            x: x + index, y: y + duration.ceil, w: 1, h: 1, path: :pixel,
            **color
          }
        end

        args.outputs.sprites << {
          x: x, y: y, w: window_size, h: 1, path: :pixel,
          r: 255, g: 255, b: 255
        }
        args.outputs.sprites << {
          x: x, y: y, w: 1, h: 30, path: :pixel,
          r: 255, g: 255, b: 255
        }
      end
    end
  end
end
