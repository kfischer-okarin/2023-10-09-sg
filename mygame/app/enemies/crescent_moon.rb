module Enemies
  module CrescentMoon
    class << self
      def build(x:, y:)
        {
          x: x, y: y, w: 11, h: 11,
          type: CrescentMoon,
          face_angle: 0, v_x: 0, v_y: 0,
          state: { type: :move_into_attack_position },
          collision_radius: 50
        }
      end

      def tick(args, crescent_moon)
        crescent_moon_state = crescent_moon[:state]

        send("handle_#{crescent_moon_state[:type]}", args, crescent_moon)
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

      private

      def handle_move_into_attack_position(args, crescent_moon)
        player = args.state.player
        state = crescent_moon[:state]
        # TODO: Better attack position calculation
        state[:attack_position] ||= { x: rand(3000) + 100, y: rand(1600) + 100 }
        speed = 12

        distance_to_attack_position = $geometry.distance(crescent_moon, state[:attack_position])
        if distance_to_attack_position < 50
          crescent_moon[:v_x] = 0
          crescent_moon[:v_y] = 0
          crescent_moon[:state] = { type: :attack }
          return
        end

        goal_attraction_force = goal_attraction_force(state[:attack_position], crescent_moon)
        player_repulsion_force = player_repulsion_force(player, crescent_moon)
        force_x = goal_attraction_force[:x] + player_repulsion_force[:x]
        force_y = goal_attraction_force[:y] + player_repulsion_force[:y]

        crescent_moon[:v_x] += force_x
        crescent_moon[:v_y] += force_y
        velocity = Math.sqrt((crescent_moon[:v_x] * crescent_moon[:v_x]) + (crescent_moon[:v_y] * crescent_moon[:v_y]))
        crescent_moon[:v_x] = crescent_moon[:v_x] * speed / velocity
        crescent_moon[:v_y] = crescent_moon[:v_y] * speed / velocity
      end

      def handle_attack(args, crescent_moon)
        state = crescent_moon[:state]
        state[:ticks] ||= 0

        state[:ticks] += 1

        if state[:ticks] == 120
          puts "Pew pew!"
        elsif state[:ticks] == 180
          crescent_moon[:state] = { type: :move_into_attack_position }
        end
      end

      GOAL_ATTRACTION_FORCE = 10
      GOAL_ATTRACTION_REACH = 500
      def goal_attraction_force(goal, position)
        distance = $geometry.distance(goal, position)
        return { x: 0, y: 0 } if distance.zero?

        strength = GOAL_ATTRACTION_FORCE / 4
        if distance < GOAL_ATTRACTION_REACH
          relative_distance = distance / GOAL_ATTRACTION_REACH
          strength = (GOAL_ATTRACTION_FORCE / 4) / relative_distance
          strength = GOAL_ATTRACTION_FORCE if strength > GOAL_ATTRACTION_FORCE
        end
        {
          x: strength * (goal[:x] - position[:x]) / distance,
          y: strength * (goal[:y] - position[:y]) / distance
        }
      end


      PLAYER_REPULSION_FORCE = 9
      PLAYER_REPULSION_REACH = 500
      def player_repulsion_force(player, position)
        distance = $geometry.distance(player, position)
        return { x: 0, y: 0 } if distance > PLAYER_REPULSION_REACH
        return { x: PLAYER_REPULSION_FORCE, y: 0 } if distance.zero?

        relative_distance = distance / PLAYER_REPULSION_REACH
        strength = (PLAYER_REPULSION_FORCE / 4) / relative_distance
        strength = PLAYER_REPULSION_FORCE if strength > PLAYER_REPULSION_FORCE
        {
          x: -strength * (player[:x] - position[:x]) / distance,
          y: -strength * (player[:y] - position[:y]) / distance
        }
      end
    end
  end
end
