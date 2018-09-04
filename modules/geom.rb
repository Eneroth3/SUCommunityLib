Sketchup.require "modules/geom/plane"
Sketchup.require "modules/geom/point3d"
Sketchup.require "modules/geom/transformation"
Sketchup.require "modules/geom/vector3d"

module SkippyLib

# Namespace for methods related to SketchUp's native Geom module.
module LGeom

  # Calculate angle from subtrahend to minuend vector, projected to given plane.
  # Returns angle in radians from 0.0 up to 2 pi. Angle is measured ccw as seen
  # from the direction normal points towards.
  #
  # @param minuend [Geom::Vector3d]
  # @param subtrahend [Geom::Vector3d]
  # @param normal [Geom::Vector3d]
  #
  # @return [Float]
  def self.angle_in_plane(minuend, subtrahend, normal = Z_AXIS)
    minuend = normal * minuend * normal
    subtrahend = normal * subtrahend * normal

    if (minuend * subtrahend) % normal > 0
      Math::PI * 2 - minuend.angle_between(subtrahend)
    else
      minuend.angle_between(subtrahend)
    end
  end

  # Compute area of an array of points representing a polygon.
  #
  # @param points [Array<Geom::Point3d>]
  #
  # @return [Float]
  def self.polygon_area(points)
    origin = points.first
    normal = polygon_normal(points)

    area = 0
    points.each_with_index do |pt0, i|
      pt1 = points[i + 1] || points.first
      triangle_area = ((pt1 - pt0) * (origin - pt0)).length / 2
      if (pt1 - pt0) * (origin - pt0) % normal > 0
        area += triangle_area
      else
        area -= triangle_area
      end
    end

    area
  end

  # Find normal vector from an array of points representing a polygon.
  #
  # @param points [Array<Geom::Point3d>]
  #
  # @example
  #   # Find Normal of a Face
  #   # Select a face and run:
  #   face = Sketchup.active_model.selection.first
  #   points = face.vertices.map(&:position)
  #   normal = SkippyLib::Geom.polygon_normal(points)
  #
  # @return [Geom::Vector3d]
  def self.polygon_normal(points)
    normal = Geom::Vector3d.new
    points.each_with_index do |pt0, i|
      pt1 = points[i + 1] || points.first
      normal.x += (pt0.y - pt1.y) * (pt0.z + pt1.z)
      normal.y += (pt0.z - pt1.z) * (pt0.x + pt1.x)
      normal.z += (pt0.x - pt1.x) * (pt0.y + pt1.y)
    end

    normal.normalize
  end

  # Remove duplicated points or vectors from array, using SketchUp's internal
  # precision.
  #
  # Ruby's own `Array#uniq` don't remove duplicated points as they are regarded
  # separate objects, based on #eql? and #hash.
  #
  # @param points [Array]
  #
  # @return [Array]
  def self.remove_duplicates(array)
    array.reduce([]) { |a, c1| a.any? { |c2| c2 == c1 } ? a : a << c1 }
  end

end
end
