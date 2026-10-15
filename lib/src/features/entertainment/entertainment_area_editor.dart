import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/hue/hue_bridge_client.dart';
import '../../core/hue/hue_models.dart';
import '../common/app_text.dart';

/// The bridge accepts at most this many lights in one area.
const maxLightsPerArea = 10;

Map<String, String> _typeLabels(AppLocalizations l10n) => {
      'music': l10n.areaTypeMusic,
      'screen': l10n.areaTypeTv,
      'monitor': l10n.areaTypeMonitor,
      '3dspace': l10n.areaTypeRoom,
      'other': l10n.areaTypeOther,
    };

/// Creates a new entertainment area, or edits [area] when given.
class EntertainmentAreaEditor extends StatefulWidget {
  const EntertainmentAreaEditor({this.area, super.key});

  final HueEntertainmentArea? area;

  @override
  State<EntertainmentAreaEditor> createState() =>
      _EntertainmentAreaEditorState();
}

class _EntertainmentAreaEditorState extends State<EntertainmentAreaEditor> {
  late final TextEditingController _name;
  late String _type;

  /// Selected services and where they are, in selection order.
  final _placements = <String, HuePosition>{};
  bool _saving = false;
  bool _pruned = false;

  @override
  void initState() {
    super.initState();
    final area = widget.area;
    _name = TextEditingController(text: area?.name ?? 'LumiFX');
    // Unknown types (newer firmware) are kept as they are.
    _type = area?.configurationType ?? 'music';
    for (final location in area?.locations ?? const <HueServiceLocation>[]) {
      if (location.positions.isNotEmpty) {
        _placements[location.serviceId] = _centroid(location.positions);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_pruned) {
      _pruned = true;
      // Lights that have left the bridge since the area was made would be
      // counted and saved without being visible.
      final known = {for (final s in _services) s.id};
      _placements.removeWhere((id, _) => !known.contains(id));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  HueHome? get _home => AppScope.of(context).bridge.home;

  List<HueEntertainmentService> get _services => [
        for (final service in _home?.entertainmentServices ?? const [])
          if (service.isRenderer && service.lightIds.isNotEmpty) service,
      ];

  String _lightName(AppLocalizations l10n, HueEntertainmentService service) {
    final home = _home;
    return [
      for (final id in service.lightIds) home?.lights[id]?.name ?? l10n.light,
    ].join(' / ');
  }

  void _toggle(HueEntertainmentService service, bool selected) {
    setState(() {
      if (!selected) {
        _placements.remove(service.id);
        return;
      }
      if (_placements.length >= maxLightsPerArea) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.l10n.areaLightLimit(maxLightsPerArea)),
        ));
        return;
      }
      // New lights start around the edge of the room, evenly spaced.
      final angle =
          _placements.length * 2 * math.pi / maxLightsPerArea - math.pi / 2;
      _placements[service.id] =
          HuePosition(0.7 * math.cos(angle), -0.7 * math.sin(angle));
    });
  }

  Future<void> _save() async {
    final bridge = AppScope.of(context).bridge;
    final services = {for (final s in _services) s.id: s};
    final draft = HueEntertainmentAreaDraft(
      name: _name.text.trim(),
      configurationType: _type,
      locations: [
        for (final MapEntry(key: id, value: position) in _placements.entries)
          HueServiceLocation(
            serviceId: id,
            positions:
                _streamPositions(position, services[id]?.maxStreams ?? 1),
          ),
      ],
    );
    setState(() => _saving = true);
    try {
      await bridge.saveEntertainmentArea(draft, areaId: widget.area?.id);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on Object catch (error) {
      if (mounted) {
        final l10n = context.l10n;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.couldNotSaveArea(describeError(l10n, error))),
        ));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _delete() async {
    final area = widget.area!;
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteAreaQuestion(area.name)),
        content: Text(l10n.deleteAreaDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    final bridge = AppScope.of(context).bridge;
    try {
      await bridge.deleteEntertainmentArea(area.id);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.couldNotDeleteArea)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = _services;
    final byId = {for (final s in services) s.id: s};
    final canSave =
        !_saving && _placements.isNotEmpty && _name.text.trim().isNotEmpty;
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final types = _typeLabels(l10n);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.area == null ? l10n.newArea : l10n.editArea),
        actions: [
          if (widget.area != null)
            IconButton(
              tooltip: l10n.deleteArea,
              icon: const Icon(Icons.delete_outline),
              onPressed: _saving ? null : _delete,
            ),
          TextButton(
            onPressed: canSave ? _save : null,
            child: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.save),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _name,
            decoration: InputDecoration(
              labelText: l10n.name,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              for (final MapEntry(key: value, value: label) in types.entries)
                ButtonSegment(value: value, label: Text(label)),
              if (!types.containsKey(_type))
                ButtonSegment(value: _type, label: Text(_type)),
            ],
            selected: {_type},
            onSelectionChanged: (value) => setState(() => _type = value.single),
          ),
          const SizedBox(height: 24),
          Text(l10n.placement, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(l10n.placementHint, style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          _RoomMap(
            placements: {
              for (final entry in _placements.entries)
                if (byId[entry.key] case final service?)
                  entry.key: (
                    label: _lightName(l10n, service),
                    position: entry.value
                  ),
            },
            onMoved: (id, position) =>
                setState(() => _placements[id] = position),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.lightsCounter(_placements.length, maxLightsPerArea),
            style: theme.textTheme.titleMedium,
          ),
          if (services.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(l10n.noEntertainmentLights),
            ),
          for (final service in services)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _placements.containsKey(service.id),
              title: Text(_lightName(l10n, service)),
              subtitle: service.maxStreams > 1
                  ? Text(l10n.gradientSegments(service.maxStreams))
                  : null,
              secondary: _placements.containsKey(service.id)
                  ? _HeightPicker(
                      value: _placements[service.id]!.z,
                      onChanged: (z) => setState(() => _placements[service.id] =
                          _placements[service.id]!.copyWith(z: z)),
                    )
                  : null,
              onChanged: (selected) => _toggle(service, selected ?? false),
            ),
        ],
      ),
    );
  }

  static HuePosition _centroid(List<HuePosition> positions) {
    var x = 0.0, y = 0.0, z = 0.0;
    for (final p in positions) {
      x += p.x;
      y += p.y;
      z += p.z;
    }
    final n = positions.length;
    return HuePosition(x / n, y / n, z / n);
  }

  /// Gradient lights get one position per segment, in a short horizontal
  /// line centred on where the user placed them. Near a wall the whole line
  /// is shifted inwards, so segments never collapse onto the same point.
  static List<HuePosition> _streamPositions(HuePosition center, int streams) {
    if (streams <= 1) {
      return [center];
    }
    const spacing = 0.15;
    final halfSpan = (streams - 1) / 2 * spacing;
    final start = (center.x - halfSpan).clamp(-1.0, 1.0 - 2 * halfSpan);
    return [
      for (var i = 0; i < streams; i++) center.copyWith(x: start + i * spacing),
    ];
  }
}

class _HeightPicker extends StatelessWidget {
  const _HeightPicker({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final options = {
      -1.0: l10n.heightLow,
      0.0: l10n.heightMid,
      1.0: l10n.heightHigh
    };
    final current = options.keys.reduce(
      (a, b) => (a - value).abs() <= (b - value).abs() ? a : b,
    );
    return DropdownButton<double>(
      value: current,
      underline: const SizedBox.shrink(),
      items: [
        for (final MapEntry(key: z, value: label) in options.entries)
          DropdownMenuItem(value: z, child: Text(label)),
      ],
      onChanged: (z) => z == null ? null : onChanged(z),
    );
  }
}

/// Top view of the room: front (y = 1) at the top, left (x = -1) on the
/// left. Lights are draggable dots.
class _RoomMap extends StatelessWidget {
  const _RoomMap({required this.placements, required this.onMoved});

  final Map<String, ({String label, HuePosition position})> placements;
  final void Function(String id, HuePosition position) onMoved;

  static const _dot = 36.0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final labelStyle = Theme.of(context).textTheme.labelSmall;
    final l10n = context.l10n;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: AspectRatio(
          aspectRatio: 1,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.maxWidth;
              final inner = size - _dot;
              Offset toOffset(HuePosition p) =>
                  Offset((p.x + 1) / 2 * inner, (1 - (p.y + 1) / 2) * inner);
              // Follow the finger's absolute position, so the dot stays under
              // it however the gesture's movement is delivered.
              HuePosition fromGlobal(Offset global, HuePosition old) {
                final box = context.findRenderObject()! as RenderBox;
                final local =
                    box.globalToLocal(global) - const Offset(_dot, _dot) / 2;
                return old.copyWith(
                  x: local.dx / inner * 2 - 1,
                  y: 1 - local.dy / inner * 2,
                );
              }

              return Container(
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                // Drawn on top so the border does not inset the dots: the
                // positions are measured from this box's own origin.
                foregroundDecoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      top: 8,
                      left: 0,
                      right: 0,
                      child: Text(l10n.front,
                          textAlign: TextAlign.center, style: labelStyle),
                    ),
                    Positioned(
                      bottom: 8,
                      left: 0,
                      right: 0,
                      child: Text(l10n.back,
                          textAlign: TextAlign.center, style: labelStyle),
                    ),
                    Center(
                      child: Icon(Icons.weekend_outlined,
                          color: colors.outline, size: 32),
                    ),
                    for (final MapEntry(key: id, value: item)
                        in placements.entries)
                      Positioned(
                        left: toOffset(item.position).dx,
                        top: toOffset(item.position).dy,
                        // A multi-drag recognizer wins over the page's
                        // vertical scroll, so dots can be dragged in any
                        // direction (a pan recognizer would lose to it).
                        child: RawGestureDetector(
                          key: ValueKey('placement-$id'),
                          gestures: {
                            ImmediateMultiDragGestureRecognizer:
                                GestureRecognizerFactoryWithHandlers<
                                    ImmediateMultiDragGestureRecognizer>(
                              ImmediateMultiDragGestureRecognizer.new,
                              (recognizer) => recognizer.onStart = (start) {
                                void move(Offset global) => onMoved(
                                    id, fromGlobal(global, item.position));
                                move(start);
                                return _DotDrag(move);
                              },
                            ),
                          },
                          child: Semantics(
                            label: l10n.draggableLight(item.label),
                            child: Tooltip(
                              message: item.label,
                              child: Container(
                                width: _dot,
                                height: _dot,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: colors.primary,
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          colors.primary.withValues(alpha: 0.5),
                                      blurRadius: 12,
                                    ),
                                  ],
                                ),
                                child: Text(
                                  item.label.characters.first.toUpperCase(),
                                  style: TextStyle(
                                    color: colors.onPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Moves one dot while a finger is down on it.
class _DotDrag extends Drag {
  _DotDrag(this._move);

  final void Function(Offset global) _move;

  @override
  void update(DragUpdateDetails details) => _move(details.globalPosition);
}
