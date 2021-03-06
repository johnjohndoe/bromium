// Copyright (c) 2016, Herman Bergwerf. All rights reserved.
// Use of this source code is governed by an AGPL-3.0-style license
// that can be found in the LICENSE file.

import 'package:bromium/math.dart';
import 'package:bromium/structs.dart';
import 'package:vector_math/vector_math.dart';

Simulation createEnzymeDemo() {
  // Setup particle dictionary.
  final p = new Index<ParticleType>();
  p['N-a'] = new ParticleType(Colors.red, 0.02, 0.02);
  p['N-b'] = new ParticleType(Colors.blue, 0.03, 0.01);
  p['enzyme'] = new ParticleType(Colors.green, 0.01, 0.05);
  p['enzyme-N'] = new ParticleType(Colors.yellow, 0.01, 0.05);
  p['enzyme-NN'] = new ParticleType(Colors.cyan, 0.01, 0.05);

  // Setup reactions.
  final bindRxn = new Index<BindReaction>();
  final unbindRxn = new Index<UnbindReaction>();
  bindRxn['step 1'] = new BindReaction(
      new ReactionParticle(p['N-a'], Membrane.inside),
      new ReactionParticle(p['enzyme'], Membrane.inside),
      new ReactionParticle(p['enzyme-N'], Membrane.inside),
      0.1);
  bindRxn['step 2'] = new BindReaction(
      new ReactionParticle(p['N-a'], Membrane.inside),
      new ReactionParticle(p['enzyme-N'], Membrane.inside),
      new ReactionParticle(p['enzyme-NN'], Membrane.inside),
      1.0);
  unbindRxn['step 3'] = new UnbindReaction(
      new ReactionParticle(p['enzyme-NN'], Membrane.inside),
      [
        new ReactionParticle(p['N-b'], Membrane.inside),
        new ReactionParticle(p['enzyme'], Membrane.inside)
      ],
      0.1);

  // Create cell membrane.
  final cellMembrane = new Membrane(
      new EllipsoidDomain(new Vector3(.0, .0, .0), new Vector3(2.0, 1.0, 1.0)),
      p.mappedFloat32List({
        'N-a': .0,
        'N-b': .0,
        'enzyme': .0,
        'enzyme-N': .0,
        'enzyme-NN': .0,
      }),
      p.mappedFloat32List({
        'N-a': .0,
        'N-b': 1.0,
        'enzyme': .0,
        'enzyme-N': .0,
        'enzyme-NN': .0,
      }),
      p.mappedFloat32List({
        'N-a': .0,
        'N-b': .0,
        'enzyme': .0,
        'enzyme-N': .0,
        'enzyme-NN': .0,
      }),
      p.mappedFloat32List({
        'N-a': .0,
        'N-b': .0,
        'enzyme': .0,
        'enzyme-N': .0,
        'enzyme-NN': .0,
      }),
      p.length);

  // Setup simulation.
  final simulation = new Simulation(p.data, bindRxn.data, unbindRxn.data);
  simulation.addRandomParticles(p['N-a'], cellMembrane.domain, 20000);
  simulation.addRandomParticles(p['enzyme'], cellMembrane.domain, 500);
  simulation.addMembrane(cellMembrane);
  return simulation;
}
