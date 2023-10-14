module Enemies
  module CrescentMoon
    class << self
      def build(x:, y:)
        {
          x: x, y: y, w: 11, h: 11,
          type: CrescentMoon,
          face_angle: 0, v_x: 0, v_y: 0,
          state: { type: :move_into_attack_position },
          collision_radius: 50,
          color: Colors::CRESCENT_MOON
        }
      end

      def tick(args, crescent_moon)
        crescent_moon_state = crescent_moon[:state]

        send("handle_#{crescent_moon_state[:type]}", args, crescent_moon)
      end

      def sprite(crescent_moon)
        color = crescent_moon[:state][:type] == :dead ? Colors::BLOOD : crescent_moon[:color]
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
        state[:attack_position] ||= a_position_behind_the_player(player, crescent_moon)
        speed = 12

        distance_to_attack_position = $geometry.distance(crescent_moon, state[:attack_position])
        if distance_to_attack_position < 50
          crescent_moon[:v_x] = 0
          crescent_moon[:v_y] = 0
          crescent_moon[:state] = { type: :telegraph_attack }
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

      def a_position_behind_the_player(player, crescent_moon)
        positions_around_player = positions_around(player, distance: 600).select { |position|
          on_screen?(position)
        }
        from_furthest_to_closest = positions_around_player.sort_by { |position|
          -$geometry.distance(position, crescent_moon)
        }
        from_furthest_to_closest[rand(3)]
      end

      def handle_telegraph_attack(args, crescent_moon)
        state = crescent_moon[:state]
        unless state[:flash_animation]
          crescent_moon[:color] = Colors::CRESCENT_MOON.dup
          state[:flash_animation] = Animations.lerp(
            crescent_moon[:color],
            to: Colors::FLASH,
            duration: 30
          )
          args.state.animations << state[:flash_animation]
        end

        if Animations.finished? state[:flash_animation]
          crescent_moon[:state] = { type: :attack }
          crescent_moon[:color] = Colors::CRESCENT_MOON
        end
      end

      module Shuriken
        class << self
          def tick(args, projectile)
            projectile[:alive] = on_screen?(projectile)
            projectile[:angle] = args.state.tick_count.mod_zero?(4) ? 0 : 90

            player = args.state.player
            player_was_hit = Collision.sphere_capsule_collision?(
              player[:x], player[:y], player[:collision_radius],
              projectile[:x], projectile[:y], projectile[:x] + projectile[:v_x], projectile[:y] + projectile[:v_y], projectile[:collision_radius]
            )
            if player_was_hit
              projectile[:alive] = false
              player[:hits] << :shuriken
            end
          end
        end
      end

      def handle_attack(args, crescent_moon)
        state = crescent_moon[:state]
        state[:ticks] ||= 0
        if state[:ticks].zero?
          args.audio[:shuriken] = { input: 'audio/shuriken.mp3' }
          projectile_speed = 20
          projectile_angle = crescent_moon.angle_to(args.state.player).to_radians
          projectile_start_x = crescent_moon[:x] + Math.cos(projectile_angle) * 50
          projectile_start_y = crescent_moon[:y] + Math.sin(projectile_angle) * 50
          [-20, 0, 20].each do |angle_offset|
            angle = projectile_angle + angle_offset.to_radians
            args.state.projectiles << {
              x: projectile_start_x,
              y: projectile_start_y,
              v_x: Math.cos(angle) * projectile_speed,
              v_y: Math.sin(angle) * projectile_speed,
              w: 5, h: 5,
              type: Shuriken,
              collision_radius: 3,
              path: 'sprites/shuriken.png',
              alive: true,
              angle: 0,
              **Colors::CRESCENT_MOON_SHURIKEN
            }
          end
        end

        state[:ticks] += 1

        crescent_moon[:state] = { type: :move_into_attack_position } if state[:ticks] >= 120
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

      PLAYER_REPULSION_FORCE = 5
      PLAYER_REPULSION_REACH = 1000
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
