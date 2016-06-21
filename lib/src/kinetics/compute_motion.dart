// Copyright (c) 2016, Herman Bergwerf. All rights reserved.
// Use of this source code is governed by an AGPL-3.0-style license
// that can be found in the LICENSE file.

part of bromium;

/// This function applies one cycle of random motion to the given [BromiumData].
void computeMotion(Sim sim) {
  var rng = new Random();
  OUTER: for (var i = 0; i < sim.data.nParticles; i++) {
    // If the particleType is -1 the particle is inactive.
    var type = sim.data.pType[i];
    if (type != -1) {
      // Compute random displacement.
      var odd = sim.info.particleInfo[type].rndWalkOdd;
      var sub = sim.info.particleInfo[type].rndWalkSub;
      var motionX = rng.nextInt(odd) - sub;
      var motionY = rng.nextInt(odd) - sub;
      var motionZ = rng.nextInt(odd) - sub;

      // Check motion block due to membrane permeability.
      for (var m = 0; m < sim.info.membranes.length; m++) {
        if (membraneBlockParticleMotion(
            sim,
            rng,
            m,
            type,
            sim.data.pCoords[i * 3 + 0],
            sim.data.pCoords[i * 3 + 1],
            sim.data.pCoords[i * 3 + 2],
            sim.data.pCoords[i * 3 + 0] + motionX,
            sim.data.pCoords[i * 3 + 1] + motionY,
            sim.data.pCoords[i * 3 + 2] + motionZ)) {
          // Continue to next particle.
          continue OUTER;
        }
      }

      // Apply motion.
      sim.data.pCoords[i * 3 + 0] += motionX;
      sim.data.pCoords[i * 3 + 1] += motionY;
      sim.data.pCoords[i * 3 + 2] += motionZ;
    }
  }
}
