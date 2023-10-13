module Collision
  class << self
    def sphere_capsule_collision?(sphere_x, sphere_y, sphere_r, capsule_x1, capsule_y1, capsule_x2, capsule_y2, capsule_r)
      distance_squared = squared_distance_point_segment(sphere_x, sphere_y, capsule_x1, capsule_y1, capsule_x2, capsule_y2)
      radius_sum = sphere_r + capsule_r

      distance_squared <= (radius_sum * radius_sum)
    end

    def squared_distance_point_segment(point_x, point_y, segment_x1, segment_y1, segment_x2, segment_y2)
      s1s2_x = segment_x2 - segment_x1
      s1s2_y = segment_y2 - segment_y1
      ps1_x = segment_x1 - point_x
      ps1_y = segment_y1 - point_y

      e = (s1s2_x * ps1_x) + (s1s2_y * ps1_y)
      return (ps1_x * ps1_x) + (ps1_y * ps1_y) if e <= 0

      f = (s1s2_x * s1s2_x) + (s1s2_y * s1s2_y)
      if e >= f
        ps2_x = segment_x2 - point_x
        ps2_y = segment_y2 - point_y
        return (ps2_x * ps2_x) + (ps2_y * ps2_y)
      end

      (ps1_x * ps1_x) + (ps1_y * ps1_y) - ((e * e) / f)
    end
  end
end
