module Player
  class << self
    def build(x:, y:)
      {
        type: Player,
        x: x, y: y, w: 9, h: 9,
        face_angle: 0, v_x: 0, v_y: 0,
        state: { type: :movement },
        collision_radius: 50,
        hits: [],
        last_hurt_tick: -1000
      }
    end

    def tick(args, player)
      player_state = player[:state]

      send("handle_#{player_state[:type]}", args, player)
    end

    def sprite(player)
      {
        x: scaled_to_screen(player[:x]) - player[:w].idiv(2),
        y: scaled_to_screen(player[:y]) - player[:h].idiv(2),
        w: player[:w],
        h: player[:h],
        path: :pixel,
        **Colors::PLAYER
      }
    end

    def handle_hits(args, player)
      return unless player[:hits].any?

      if args.state.tick_count - player[:last_hurt_tick] > 60
        player[:last_hurt_tick] = args.state.tick_count
        args.state.screen_flash.merge!(Colors::BLOOD)
        args.state.screen_flash[:a] = 255
        args.state.animations << Animations.lerp(args.state.screen_flash, to: { a: 0 }, duration: 0.5.seconds)
      end

      player[:hits].clear
    end

    private

    def handle_movement(args, player)
      return if args.state.game_state == :won

      player_inputs = args.state.player_inputs

      update_velocity(player, player_inputs)
      update_face_angle(player, player[:v_x], player[:v_y]) if moving?(player)
      return unless player_inputs[:charge]

      start_charging(args, player)
    end

    PLAYER_SPEED = 15
    PLAYER_DIAGONAL_SPEED = (PLAYER_SPEED / Math.sqrt(2)).round

    def update_velocity(player, player_inputs)
      player[:v_x] = 0
      player[:v_y] = 0

      if player_inputs[:left]
        player[:v_x] = -1
      elsif player_inputs[:right]
        player[:v_x] = 1
      end

      if player_inputs[:up]
        player[:v_y] = 1
      elsif player_inputs[:down]
        player[:v_y] = -1
      end
      speed = moving_diagonally?(player) ? PLAYER_DIAGONAL_SPEED : PLAYER_SPEED
      player[:v_x] *= speed
      player[:v_y] *= speed
    end

    def start_charging(args, player)
      player[:state] = { type: :charging, ticks: 0, power: 0 }
      player[:v_x] = 0
      player[:v_y] = 0

      args.state.charge_particles = []
    end

    def handle_charging(args, player)
      player_inputs = args.state.player_inputs
      charging_state = player[:state]

      if player_inputs[:charge]
        charging_state[:ticks] += 1
        charging_state[:power] = [charging_state[:ticks], 120].min
        charging_state[:ready] = charging_state[:power] >= 40

        particles = args.state.charge_particles
        particles << player_charge_particle(args, args.state.sprites.circle)

        particles.each do |particle|
          particle[:x] = scaled_to_screen(player[:x] + Math.cos(particle[:angle_from_player]) * particle[:distance])
          particle[:y] = scaled_to_screen(player[:y] + Math.sin(particle[:angle_from_player]) * particle[:distance])
        end
        particles.reject! { |particle| Animations.finished?(particle[:animation]) }

        charging_state[:predicted_distance] = predict_rush_distance(player) if charging_state[:ready]
      else
        if charging_state[:ready]
          player[:state] = { type: :rushing, power: charging_state[:power] }
        else
          player[:state] = { type: :movement }
        end
      end
    end

    def predict_rush_distance(player)
      simulated_player = player.dup
      simulated_player[:state] = { type: :rushing, power: player[:state][:power] }
      distance_x = 0
      distance_y = 0
      until simulated_player[:state][:power].zero?
        execute_rush(simulated_player)
        distance_x += simulated_player[:v_x]
        distance_y += simulated_player[:v_y]
      end
      Math.sqrt((distance_x**2) + (distance_y**2))
    end

    def handle_rushing(args, player)
      rushing_state = player[:state]
      execute_rush(player)

      enemies = args.state.enemies
      hit_enemies = moving_entity_collisions(player, enemies)
      hit_enemies.each do |enemy|
        enemy[:state] = { type: :dead, ticks: 0 }
      end
      args.state.game_state = :won if enemies.all? { |enemy| enemy[:state][:type] == :dead }

      player[:state] = { type: :movement } if rushing_state[:power].zero?
    end

    def execute_rush(player)
      rushing_state = player[:state]
      rushing_state[:power] = [rushing_state[:power] - 10, 0].max
      return if rushing_state[:power].zero?

      rush_speed = rushing_state[:power].idiv(2) * 10
      player[:v_x] = Math.cos(player[:face_angle]) * rush_speed
      player[:v_y] = Math.sin(player[:face_angle]) * rush_speed
    end
  end
end
