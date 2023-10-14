module Enemies
  module CrescentMoon
    class << self
      def build(x:, y:)
        {
          x: x, y: y, w: 11, h: 11,
          type: CrescentMoon,
          face_angle: 0, v_x: 0, v_y: 0,
          state: { type: :movement },
          collision_radius: 50
        }
      end

      def tick(args, crescent_moon)
      end

      def sprite(crescent_moon)
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
    end
  end
end
