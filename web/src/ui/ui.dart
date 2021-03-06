// Copyright (c) 2016, Herman Bergwerf. All rights reserved.
// Use of this source code is governed by an AGPL-3.0-style license
// that can be found in the LICENSE file.

library bromium.ui;

import 'dart:html';
import 'dart:math';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:tuple/tuple.dart';
import 'package:bromium/math.dart';
import 'package:bromium/engine.dart';
import 'package:bromium/structs.dart';
import 'package:bromium/renderer.dart';
import 'package:vector_math/vector_math.dart';

part 'fileutils.dart';
part 'convert.dart';
part 'data_elements.dart';
part 'data_entries.dart';
part 'data_items.dart';
part 'tabs.dart';
part 'graph.dart';

// ignore: non_constant_identifier_names
Element $(String selectors) => document.querySelector(selectors);

class BromiumUi {
  final Tabs tabs;
  final ButtonElement btnSave, btnLoad, btnUpdate, btnAdd, btnPauseRun;
  final DivElement viewPanel;
  final CanvasElement canvas;
  final BromiumEngine engine;
  BromiumWebGLRenderer renderer;

  /// Tabs
  final pTypeTab =
      new Tab<PTypeItem>('Particles', (data) => new PTypeItem(data));
  final membraneTab =
      new Tab<MembraneItem>('Membranes', (data) => new MembraneItem(data));
  final bindRxnTab =
      new Tab<BindRxnItem>('Bind reactions', (data) => new BindRxnItem(data));
  final unbindRxnTab = new Tab<UnbindRxnItem>(
      'Unbind reactions', (data) => new UnbindRxnItem(data));
  final domainTab =
      new Tab<DomainItem>('Domains', (data) => new DomainItem(data));
  final setupTab = new Tab<SetupItem>('Setup', (data) => new SetupItem(data));

  BromiumUi()
      : tabs = new Tabs($('#tabs-bar'), $('#tabs-panel'), $('#btn-add')),
        btnSave = $('#btn-save'),
        btnLoad = $('#btn-load'),
        btnUpdate = $('#btn-update'),
        btnAdd = $('#btn-add'),
        btnPauseRun = $('#btn-pause-run'),
        viewPanel = $('#view-panel'),
        canvas = $('#bromium-canvas') as CanvasElement,
        engine = new BromiumEngine(
            inIsolate: !window.navigator.userAgent.contains('Dart')) {
    renderer = new BromiumWebGLRenderer(engine, canvas);

    // Auto-fit canvas.
    window.onResize.listen((_) => resizeCanvas());
    resizeCanvas();

    // Create tab controller.
    tabs.add(pTypeTab);
    tabs.add(membraneTab);
    tabs.add(bindRxnTab);
    tabs.add(unbindRxnTab);
    tabs.add(domainTab);
    tabs.add(setupTab);
    tabs.select('Particles');

    // Bind engine particle count stream.
    engine.particleCountStream
        .listen((List<Tuple2<List<int>, List<int>>> data) {
      final membraneItems = membraneTab.items;
      var dataIdx = 0;
      for (var i = 0; i < membraneItems.length; i++) {
        if (membraneItems[i].simulationIndex == dataIdx) {
          membraneItems[i]
              .graph
              .addDataPoints(data[dataIdx].item1, data[dataIdx].item2);

          // Proceed to next membrane.
          dataIdx++;
          if (dataIdx == data.length) {
            break;
          }
        }
      }
    });

    // Bind events.
    btnSave.onClick.listen((_) {
      final data = new Blob([generateJsonConfig()], 'application/json');
      saveAs(data, 'bromium.json');
    });
    btnLoad.onClick.listen((_) async {
      loadJsonConfig(await openFile('application/json'));
    });
    btnUpdate.onClick.listen((_) => updateSimulation());
    btnPauseRun.onClick.listen((_) => pauseRunSimulation());

    // Local storage integration.
    // Save the current settings to the local storage on quit.
    window.onUnload.listen((_) {
      window.localStorage['BromiumData'] = generateJsonConfig();
    });

    // Load the settings that are in the local storage.
    if (window.localStorage.containsKey('BromiumData')) {
      loadJsonConfig(window.localStorage['BromiumData']);
    }
  }

  /// Export configuration as JSON string.
  String generateJsonConfig() {
    return JSON.encode({
      'Particles': toJsonExtra(pTypeTab.collectData()),
      'Membranes': toJsonExtra(membraneTab.collectData()),
      'BindReactions': toJsonExtra(bindRxnTab.collectData()),
      'UnbindReactions': toJsonExtra(unbindRxnTab.collectData()),
      'Domains': toJsonExtra(domainTab.collectData()),
      'Setup': toJsonExtra(setupTab.collectData())
    });
  }

  /// Load configuration from JSON string.
  void loadJsonConfig(String json) {
    // Clear old data.
    pTypeTab.clear();
    membraneTab.clear();
    bindRxnTab.clear();
    unbindRxnTab.clear();
    domainTab.clear();
    setupTab.clear();

    // Load new data.
    final data = fromJsonExtra(JSON.decode(json));
    pTypeTab.loadItems(data['Particles'] as List);
    membraneTab.loadItems(data['Membranes'] as List);
    bindRxnTab.loadItems(data['BindReactions'] as List);
    unbindRxnTab.loadItems(data['UnbindReactions'] as List);
    domainTab.loadItems(data['Domains'] as List);
    setupTab.loadItems(data['Setup'] as List);
  }

  /// Update the simulation.
  Future updateSimulation() async {
    btnUpdate.classes.add('disabled');
    btnUpdate.children.first
      ..classes.add('fa-spin')
      ..style.color = 'inherit';

    // Pause engine.
    await engine.pause();

    // TODO: do more validation and use a error messaging (with notifications in
    // the user interface).
    try {
      // Process particle types.
      final particleLabels = new List<String>();
      final particleColors = new List<Vector3>();
      final particleIndex = new Index<ParticleType>();
      for (final item in pTypeTab.items) {
        final particleType = item.data;
        final label = item.get('Label');
        particleLabels.add(label);
        particleColors.add(particleType.displayColor);
        particleIndex[label] = particleType;
      }

      // Get membranes.
      final membraneIndex = new Index<Membrane>();
      for (final item in membraneTab.items) {
        // Update membrane particle graph labels and colors.
        item.graph.labels = particleLabels;
        item.graph.colors = particleColors;

        // Store membrane in membrane index.
        final label = item.get('Label');
        membraneIndex[label] = item.createMembrane(particleIndex);
        item.simulationIndex = membraneIndex[label];
      }

      // Get bind reactions.
      final bindReactionList = new List<BindReaction>();
      for (final item in bindRxnTab.items) {
        bindReactionList.add(item.createBindReaction(particleIndex));
      }

      // Get unbind reactions.
      final unbindReactionList = new List<UnbindReaction>();
      for (final item in unbindRxnTab.items) {
        unbindReactionList.add(item.createUnbindReaction(particleIndex));
      }

      // Get domains.
      final domainIndex = new Index<Domain>();
      for (final item in domainTab.items) {
        domainIndex[item.get('Label')] = item.data;
      }

      // Setup simulation.
      final simulation = new Simulation(
          particleIndex.data, bindReactionList, unbindReactionList);
      for (final item in setupTab.items) {
        item.applyToSimulation(
            simulation, particleIndex, membraneIndex, domainIndex);
      }

      // Load membranes.
      // TODO: batch load membranes (more efficient to compute particle entered
      // list at once).
      for (final membrane in membraneIndex.data) {
        simulation.addMembrane(membrane);
      }

      // Load the simulation.
      var bbox = simulation.particlesBoundingBox();
      await engine.loadSimulation(simulation);
      renderer.trackball.resetRotation();
      renderer.focus(bbox);
      renderer.start();
    } catch (e) {
      // When there is an error, just terminate the updating and make the
      // refresh icon red.
      btnUpdate.children.first.style.color = '#a00';

      // Print error.
      print(e);
    }

    // Update buttons.
    btnPauseRun.text = 'Pause';
    btnUpdate.classes.remove('disabled');
    btnUpdate.children.first.classes.remove('fa-spin');
  }

  /// Pause/run the simulation.
  Future pauseRunSimulation() async {
    if (engine.isRunning) {
      if (engine.inIsolate) {
        btnPauseRun.text = 'Pausing...';
        btnPauseRun.classes.add('disabled');
      }

      await engine.pause();
      btnPauseRun.text = 'Run';
      btnPauseRun.classes.remove('disabled');
    } else {
      await engine.resume();
      btnPauseRun.text = 'Pause';
    }
  }

  /// Set the canvas size to the [viewPanel] size.
  void resizeCanvas() {
    canvas.width = viewPanel.clientWidth;
    canvas.height = viewPanel.clientHeight;
    renderer.updateViewport();
  }
}
