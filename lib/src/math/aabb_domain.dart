// Copyright (c) 2016, Herman Bergwerf. All rights reserved.
// Use of this source code is governed by an AGPL-3.0-style license
// that can be found in the LICENSE file.

part of bromium.math;

/// AABB domain
class AabbDomain extends Domain {
  /// AABB data (from vector_math)
  Aabb3 data;

  AabbDomain(this.data, [List<Domain> cavities])
      : super(DomainType.aabb, cavities);

  /// Construct from buffer.
  factory AabbDomain.fromBuffer(ByteBuffer buffer, int offset) {
    return new AabbDomain(new Aabb3.fromBuffer(buffer, offset));
  }

  /// Construct AABB domain that contains all the given domains.
  factory AabbDomain.enclose(List<Domain> domains) {
    if (domains.isEmpty) {
      throw new ArgumentError.value(domains, 'domains', 'cannot be empty');
    } else {
      var aabb = domains.first.computeBoundingBox();
      var min = aabb.min;
      var max = aabb.max;
      for (var i = 1; i < domains.length; i++) {
        aabb = domains[i].computeBoundingBox();
        Vector3.min(aabb.min, min, min);
        Vector3.max(aabb.max, max, max);
      }
      return new AabbDomain(new Aabb3.minMax(min, max));
    }
  }

  Aabb3 computeBoundingBox() => data;

  bool _contains(Vector3 point) => data.containsVector3(point);

  List<double> _computeRayIntersections(Ray ray) =>
      computeRayAabbIntersections(ray, data);

  List<Vector3> _generateWireframe() => generateAabbWireframe(data);

  List<Vector3> _generatePolygonMesh() => generateAabbPolygonMesh(data);
}
