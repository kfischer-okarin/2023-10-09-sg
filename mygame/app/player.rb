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
        last_hit_tick: -1000,
        hp: 60
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

    def hp_bar_sprite(player)
      x = 240
      y = 10
      w = 60
      h = 3
      [
        {
          x: x - 1, y: y, w: w + 2, h: h + 2,
          path: :pixel,
          **Colors::HP_BAR_BACKGROUND
        },
        {
          x: x, y: y + 1, w: (w * player[:hp] / 60).round, h: h,
          path: :pixel,
          **Colors::HP_BAR
        }
      ]
    end

    def handle_hits(args, player)
      return unless player[:hits].any?

      if game_over?(args)
        player[:hits].clear
        return
      end

      time_since_last_hit = args.state.tick_count - player[:last_hit_tick]

      if time_since_last_hit > 60
        player[:last_hit_tick] = args.state.tick_count
        args.state.screen_flash.merge!(Colors::BLOOD)
        args.state.screen_flash[:a] = 255
        args.state.animations << Animations.lerp(args.state.screen_flash, to: { a: 0 }, duration: 0.5.seconds)
      end

      if time_since_last_hit > 20
        blood_stains = args.state.blood_stains
        player[:hits].each do |hit|
          blood_sprite = args.state.sprites.blood_splats.sample
          offset_x = Math.cos(hit[:angle]) * (5 + rand(10)) - blood_sprite[:w].idiv(2)
          offset_y = Math.sin(hit[:angle]) * (5 + rand(10)) - blood_sprite[:h].idiv(2)
          angle_rounded_to_90_degrees = (hit[:angle].to_degrees / 90).round * 90
          blood_stains << blood_sprite.merge(
            x: scaled_to_screen(player[:x]) + offset_x,
            y: scaled_to_screen(player[:y]) + offset_y,
            age: 0,
            angle: angle_rounded_to_90_degrees,
            **Colors::BLOOD
          )

          case hit[:type]
          when :shuriken
            player[:hp] -= 10
          when :red_arrow
            player[:hp] -= 20
          end
        end

        player[:hp] = 0 if player[:hp].negative?
        args.state.game_state = :lost if player[:hp].zero?
      end

      player[:hits].clear
    end

    private

    def handle_movement(args, player)
      if game_over?(args)
        player[:v_x] = 0
        player[:v_y] = 0
        return
      end

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
      args.audio[:charge] = {
        input: 'audio/charge1.mp3',
        gain: 0.2
      }
      args.audio[:charge2] = {
        input: 'audio/charge2.mp3',
        looping: true,
        gain: 0.0
      }
    end

    def handle_charging(args, player)
      player_inputs = args.state.player_inputs
      charging_state = player[:state]

      if player_inputs[:charge]
        charging_state[:ticks] += 1
        args.audio[:charge2][:gain] = charging_state[:ticks].remap(0, 60, 0.0, 0.2) if charging_state[:ticks] < 60
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
        args.audio.delete(:charge)
        args.audio.delete(:charge2)
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
        enemy[:v_x] = 0
        enemy[:v_y] = 0
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
