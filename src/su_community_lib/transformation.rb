module SUCommunityLib
module LGeom

# Namespace for methods related to SketchUp's native Geom::Transformation class.
module LTransformation

  # Create transformation from origin point and axes vectors.
  #
  # Unlike native +Geom::Transformation.axes+ this method does not make the axes
  # orthogonal or normalize them but uses them as they are, allowing for scaled
  # and skewed transformations.
  #
  # @param origin [Geom::Point3d]
  # @param xaxis [Geom::Vector3d]
  # @param yaxis [Geom::Vector3d]
  # @param zaxis [Geom::Vector3d]
  #
  # @example
  #   # Skew Selected Group/Component
  #   # Select a group or component and run:
  #   e = Sketchup.active_model.selection.first
  #   e.transformation = SUCommunityLib::LGeom::LTransformation.create_from_axes(
  #     ORIGIN,
  #     Geom::Vector3d.new(2, 0.3, 0.3),
  #     Geom::Vector3d.new(0.3, 2, 0.3),
  #     Geom::Vector3d.new(0.3, 0.3, 2)
  #   )
  #
  # @raise [ArgumentError] if any of the provided axes are parallel.
  # @raise [ArgumentError] if any of the vectors are zero length.
  #
  # @return [Geom::Transformation]
  def self.create_from_axes(origin = ORIGIN, xaxis = ZAXIS, yaxis = YAXIS, zaxis = XAXIS)
    unless [xaxis, yaxis, zaxis].all?(&:valid?)
      raise ArgumentError, "Axes must not be zero length."
    end
    if xaxis.parallel?(yaxis) || yaxis.parallel?(zaxis) || zaxis.parallel?(xaxis)
      raise ArgumentError, "Axes must not be parallel."
    end

    Geom::Transformation.new([
      xaxis.x,  xaxis.y,  xaxis.z,  0,
      yaxis.x,  yaxis.y,  yaxis.z,  0,
      zaxis.x,  zaxis.y,  zaxis.z,  0,
      origin.x, origin.y, origin.z, 1
    ])
  end

  # Create transformation from origin point and three angles.
  #
  # See +euler_angles+ for details on order of rotations.
  #
  # @param origin [Geom::Point3d]
  # @param x_angle [Float] Rotation in radians
  # @param y_angle [Float] Rotation in radians
  # @param z_angle [Float] Rotation in radians
  #
  # @example
  #   # Compose and Decompose Euler Angle Based Transformation
  #   tr = SUCommunityLib::LGeom::LTransformation.create_from_euler_angles(
  #     ORIGIN,
  #     45.degrees,
  #     45.degrees,
  #     45.degrees
  #   )
  #   SUCommunityLib::LGeom::LTransformation.euler_angles(tr).map(&:radians)
  #
  # @return [Geom::Transformation]
  def self.create_from_euler_angles(origin = ORIGIN, x_angle = 0, y_angle = 0, z_angle = 0)
    Geom::Transformation.new(origin) *
      Geom::Transformation.rotation(ORIGIN, Z_AXIS, z_angle) *
      Geom::Transformation.rotation(ORIGIN, Y_AXIS, y_angle) *
      Geom::Transformation.rotation(ORIGIN, X_AXIS, x_angle)
  end

  # Calculate extrinsic, chained XYZ rotation angles for transformation.
  #
  # Scaling, shearing and translation are all ignored.
  #
  # Note that rotations are not communicative, meaning the order they are
  # applied in matters.
  #
  # @param transformation [Geom::Transformation]
  #
  # @example
  #   # Compose and Decompose Euler Angle Based Transformation
  #   x_angle = -14.degrees
  #   y_angle = 7.degrees
  #   z_angle = 45.degrees
  #   transformation = Geom::Transformation.rotation(ORIGIN, Z_AXIS, z_angle) *
  #     Geom::Transformation.rotation(ORIGIN, Y_AXIS, y_angle) *
  #     Geom::Transformation.rotation(ORIGIN, X_AXIS, x_angle)
  #   angles = SUCommunityLib::LGeom::LTransformation.euler_angles(transformation)
  #   angles.map(&:radians)
  #
  #   # Determine Angles of Selected Group/Component
  #   # Select a group or component and run:
  #   e = Sketchup.active_model.selection.first
  #   SUCommunityLib::LGeom::LTransformation.euler_angles(e.transformation).map(&:radians)
  #
  # @return [Array(Float, Float, Float)] X rotation, Y rotation and Z Rotation
  #   in radians.
  def self.euler_angles(transformation)
    a = reset_scale(reset_skew(transformation, false)).to_a

    x = Math.atan2(a[6], a[10])
    c2 = Math.sqrt(a[0]**2 + a[1]**2)
    y = Math.atan2(-a[2], c2)
    s = Math.sin(x)
    c1 = Math.cos(x)
    z = Math.atan2(s * a[8] - c1 * a[4], c1 * a[5] - s * a[9])

    [x, y, z]
  end

  # Extract a transformation only resembling the shearing of another
  # transformation.
  #
  # The X axis is never considered to be sheared but represents rotation, and
  # will therefore always be an X unit vector in the new transformation.
  #
  # @param transformation [Geom::Transformation]
  #
  # @example
  #   # Determine how much transformation would displace a point along the X
  #   # axis relative its signed Y coordinate.
  #   sheared_tr = SUCommunityLib::LGeom::LTransformation.create_from_axes(
  #     ORIGIN,
  #     X_AXIS,
  #     Geom::Vector3d.new(0.3, 1, 0),
  #     Z_AXIS
  #   )
  #   shear_tr = SUCommunityLib::LGeom::LTransformation.extract_shearing(sheared_tr)
  #   SUCommunityLib::LGeom::LTransformation.yaxis(shear_tr).x
  #
  # @return [Geom::Transformation]
  def self.extract_shearing(transformation)
    reset_shearing(transformation, true).inverse * transformation
  end

  # Calculate determinant of 3X3 matrix.
  #
  # @param transformation [Geom::Transformation]
  #
  # @return [Float]
  def self.determinant(transformation)
    xaxis(transformation) % (yaxis(transformation) * zaxis(transformation))
  end

  # Test if transformation is flipped (mirrored).
  #
  # @param transformation [Geom::Transformation]
  #
  # @return [Boolean]
  def self.flipped?(transformation)
    determinant(transformation) < 0
  end

  # Test if a transformation is the identity transformation.
  #
  # Before SketchUp 2018 the native +Transformation#identity?+ method was broken.
  #
  # @param transformation [Geom::Transformation]
  #
  # @return [Boolean]
  def self.identity?(transformation)
    same?(transformation, IDENTITY)
  end

  # Return new transformation with scaling removed.
  #
  # @param transformation [Geom::Transformation]
  #
  # @example
  #   # Mimic Context Menu > Reset Scale
  #   # Note that native Reset Scale also resets skew, not just scale.
  #   # Select a skewed group or component and run:
  #   e = Sketchup.active_model.selection.first
  #   e.transformation = SUCommunityLib::LGeom::LTransformation.reset_scaling(
  #     SUCommunityLib::LGeom::LTransformation.reset_shearing(e.transformation, false)
  #   )
  #
  # @return [Geom::Transformation]
  def self.reset_scaling(transformation)
    x_axis = xaxis(transformation).normalize
    x_axis.reverse! if flipped?(transformation)
    create_from_axes(
      transformation.origin,
      x_axis,
      yaxis(transformation).normalize,
      zaxis(transformation).normalize
    )
  end

  # Return new transformation with shearing removed (made orthogonal).
  #
  # The X axis is considered to represent rotation and will remain the same as
  # in the original transformation. The Y axis of the new transformation will
  # however be made perpendicular to the X axis, and the Z axis will be made
  # perpendicular to both the other axes.
  #
  # Note that the SketchUp UI refers to shearing as skewing.
  #
  # @param transformation [Geom::Transformation]
  # @param preserve_determinant_value [Boolean]
  #   If +true+ the determinant value of the transformation, and thus the volume
  #   of an object transformed with it, is preserved. If +false+ lengths along
  #   axes are preserved (the behavior of SketchUp's native Context Menu >
  #   Reset Skew).
  #
  # @example
  #   # Mimic Context Menu > Reset Skew
  #   # Select a skewed group or component and run:
  #   e = Sketchup.active_model.selection.first
  #   e.transformation = SUCommunityLib::LGeom::LTransformation.reset_shearing(e.transformation, false)
  #
  #   # Reset Skewing While Retaining Volume
  #   # Select a skewed group or component and run:
  #   e = Sketchup.active_model.selection.first
  #   e.transformation = SUCommunityLib::LGeom::LTransformation.reset_shearing(e.transformation, true)
  #
  # @return [Geom::Transformation]
  def self.reset_shearing(transformation, preserve_determinant_value = false)
    xaxis = xaxis(transformation)
    yaxis = yaxis(transformation)
    zaxis = zaxis(transformation)

    new_yaxis = xaxis.normalize * yaxis * xaxis.normalize
    new_zaxis = new_yaxis.normalize * (xaxis.normalize * zaxis * xaxis.normalize) * new_yaxis.normalize

    unless preserve_determinant_value
      new_yaxis.length = yaxis.length
      new_zaxis.length = zaxis.length
    end

    create_from_axes(
      transformation.origin,
      xaxis,
      new_yaxis,
      new_zaxis
    )
  end

  # Get X rotation in radians.
  #
  # See +euler_angles+ for details on order of rotations.
  #
  # @param transformation [Geom::Transformation]
  #
  # @return [Float]
  def self.rotx(transformation)
    euler_angles(transformation)[0]
  end

  # Get Y rotation in radians.
  #
  # See +euler_angles+ for details on order of rotations.
  #
  # @param transformation [Geom::Transformation]
  #
  # @return [Float]
  def self.roty(transformation)
    euler_angles(transformation)[1]
  end

  # Get Z rotation in radians.
  #
  # See +euler_angles+ for details on order of rotations.
  #
  # @param transformation [Geom::Transformation]
  #
  # @return [Float]
  def self.rotz(transformation)
    euler_angles(transformation)[2]
  end

  # Test if two transformations are the same using SketchUp's internal
  # precision for Point3d and Vector3d comparison.
  #
  # @param transformation_a [Geom::Transformation]
  # @param transformation_b [Geom::Transformation]
  #
  # @return [Boolean]
  def self.same?(transformation_a, transformation_b)
    xaxis(transformation_a) == xaxis(transformation_b) &&
      yaxis(transformation_a) == yaxis(transformation_b) &&
      zaxis(transformation_a) == zaxis(transformation_b) &&
      transformation_a.origin == transformation_b.origin
  end

  # Compute the area scale factor of transformation at specific plane.
  #
  # @param transformation [Geom::Transformation]
  # @param plane [Array(Geom::Point3d, Geom::Vector3d), Array(Float, Float, Float, Float)]
  #
  # @example
  #   tr = Geom::Transformation.scaling(ORIGIN, 2, 1, 1)
  #   plane = [ORIGIN, Z_AXIS]
  #   SUCommunityLib::LGeom::LTransformation.scale_factor_in_plane(tr, plane)
  #
  #
  # @return [Float]
  def self.scale_factor_in_plane(transformation, plane)
    normal = LPlane.normal(plane)
    tangent = LVector3d.arbitrary_perpendicular_vector(normal)
    bi_tangent = tangent * normal

    tangent.transform!(transformation)
    bi_tangent.transform!(transformation)

    (tangent * bi_tangent).length.to_f
  end

  # Test if transformation is skewed (not orthogonal).
  #
  # @param transformation [Geom::Transformation]
  #
  # @return [Boolean]
  def self.skewed?(transformation)
    !xaxis(transformation).parallel?(yaxis(transformation) * zaxis(transformation))
  end

  # Get the X axis vector of a transformation.
  #
  #
  # Unlike native +Transformation#xaxis+ the length of this axis isn't normalized
  # but resamples the scaling along the axis.
  #
  # @param transformation [Geom::Transformation]
  #
  # @return [Geom::Vector3d]
  def self.xaxis(transformation)
    Geom::Vector3d.new(transformation.to_a.values_at(0..2))
  end

  # Get X scale factor fora  transformation.
  #
  # @param transformation [Geom::Transformation]
  #
  # @example
  #   # Select a group or component and run:
  #   e = Sketchup.active_model.selection.first
  #   SUCommunityLib::LGeom::LTransformation.xscale(e.transformation)
  #
  # @return [Float]
  def self.xscale(transformation)
    xaxis(transformation).length * transformation.to_a[15]
  end

  # Get the Y axis vector of a transformation.
  #
  #
  # Unlike native +Transformation#yaxis+ the length of this axis isn't normalized
  # but resamples the scaling along the axis.
  #
  # @param transformation [Geom::Transformation]
  #
  # @return [Geom::Vector3d]
  def self.yaxis(transformation)
    Geom::Vector3d.new(transformation.to_a.values_at(4..6))
  end

  # Get Y scale factor fora  transformation.
  #
  # @param transformation [Geom::Transformation]
  #
  # @example
  #   # Select a group or component and run:
  #   e = Sketchup.active_model.selection.first
  #   SUCommunityLib::LGeom::LTransformation.yscale(e.transformation)
  #
  # @return [Float]
  def self.yscale(transformation)
    yaxis(transformation).length * transformation.to_a[15]
  end

  # Get the Z axis vector of a transformation.
  #
  # Unlike native +Transformation#zaxis+ the length of this axis isn't normalized
  # but resamples the scaling along the axis.
  # @param transformation [Geom::Transformation]
  #
  # @return [Geom::Vector3d]
  def self.zaxis(transformation)
    Geom::Vector3d.new(transformation.to_a.values_at(8..10))
  end

  # Get Z scale factor for a transformation.
  #
  # @param transformation [Geom::Transformation]
  #
  # @example
  #   # Select a group or component and run:
  #   e = Sketchup.active_model.selection.first
  #   SUCommunityLib::LGeom::LTransformation.zscale(e.transformation)
  #
  # @return [Float]
  def self.zscale(transformation)
    zaxis(transformation).length * transformation.to_a[15]
  end

end
end
end
