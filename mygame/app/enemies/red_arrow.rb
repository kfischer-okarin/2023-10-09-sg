module Enemies
  module RedArrow
    class << self
      def build(x:, y:)
        {
          x: x, y: y, w: 11, h: 11,
          type: RedArrow,
          face_angle: 0, v_x: 0, v_y: 0,
          state: { type: :standing },
          collision_radius: 50,
          color: Colors::RED_ARROW
        }
      end

      def tick(args, red_arrow)
        red_arrow_state = red_arrow[:state]

        send("handle_#{red_arrow_state[:type]}", args, red_arrow)
      end

      def sprite(red_arrow)
        state = red_arrow[:state]
        case state[:type]
        when :standing
          color = state[:type] == :dead ? Colors::BLOOD : red_arrow[:color]
          {
            x: scaled_to_screen(red_arrow[:x]) - red_arrow[:w].idiv(2),
            y: scaled_to_screen(red_arrow[:y]) - red_arrow[:h].idiv(2),
            w: red_arrow[:w],
            h: red_arrow[:h],
            path: 'sprites/arrow.png',
            angle: red_arrow[:face_angle],
            angle_anchor_x: 0.5,
            angle_anchor_y: 0.5,
            **color
          }
        when :running
          last_positions = state[:last_positions] || [red_arrow.slice(:x, :y, :face_angle)]
          last_position_count = last_positions.size
          last_positions.map_with_index do |position, index|
            color = red_arrow[:color].merge(a: index * 255 / last_position_count)
            {
              x: scaled_to_screen(position[:x]) - red_arrow[:w].idiv(2),
              y: scaled_to_screen(position[:y]) - red_arrow[:h].idiv(2),
              w: red_arrow[:w],
              h: red_arrow[:h],
              path: 'sprites/arrow_moving.png',
              angle: position[:face_angle],
              angle_anchor_x: 0.5,
              angle_anchor_y: 0.5,
              **color
            }
          end
        end
      end

      private

      def handle_standing(args, red_arrow)
        state = red_arrow[:state]
        state[:ticks] ||= 0

        state[:ticks] += 1

        if state[:ticks] > 60
          red_arrow[:state] = { type: :running }
        end
      end

      def handle_running(args, red_arrow)
        speed = 30
        state = red_arrow[:state]
        state[:ticks] ||= 0
        state[:current_run_remaining_ticks] ||= (20 + rand(20))
        state[:last_positions] ||= []

        state[:ticks] += 1
        state[:current_run_remaining_ticks] -= 1

        red_arrow[:v_x] = Math.cos(red_arrow[:face_angle].to_radians) * speed
        red_arrow[:v_y] = Math.sin(red_arrow[:face_angle].to_radians) * speed

        didnt_move = red_arrow[:x] == state[:last_positions].last&.dig(:x) &&
                     red_arrow[:y] == state[:last_positions].last&.dig(:y)

        if state[:current_run_remaining_ticks] <= 0 || didnt_move
          red_arrow[:face_angle] = (red_arrow[:face_angle] + [90, -90].sample) % 360
          state[:current_run_remaining_ticks] = (20 + rand(20))
        end

        state[:last_positions] << red_arrow.slice(:x, :y, :face_angle)
        state[:last_positions].shift if state[:last_positions].size > 10
      end
    end
  end
end
