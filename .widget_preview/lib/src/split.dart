

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'utils/pointer_events/pointer_events.dart';

double degToRad(num deg) => deg * (math.pi / 180.0);

const defaultEpsilon = 1 / 1000;

final class SplitPane extends StatefulWidget {
  SplitPane({
    super.key,
    required this.axis,
    required this.children,
    required this.initialFractions,
    this.minSizes,
    this.splitters,
  }) : assert(children.length >= 2),
       assert(initialFractions.length >= 2),
       assert(children.length == initialFractions.length) {
    _verifyFractionsSumTo1(initialFractions);
    if (minSizes != null) {
      assert(minSizes!.length == children.length);
    }
    if (splitters != null) {
      assert(splitters!.length == children.length - 1);
    }
  }

  final Axis axis;

  final List<Widget> children;

  final List<double> initialFractions;

  final List<double>? minSizes;

  final List<PreferredSizeWidget>? splitters;

  @visibleForTesting
  Key dividerKey(int index) => Key('$this dividerKey $index');

  static Axis axisFor(BuildContext context, double horizontalAspectRatio) {
    final screenSize = MediaQuery.of(context).size;
    final aspectRatio = screenSize.width / screenSize.height;
    if (aspectRatio >= horizontalAspectRatio) return Axis.horizontal;
    return Axis.vertical;
  }

  @override
  State<StatefulWidget> createState() => _SplitPaneState();
}

final class _SplitPaneState extends State<SplitPane> {
  late final List<double> fractions;
  bool _isDragging = false;

  bool get isHorizontal => widget.axis == Axis.horizontal;

  @override
  void initState() {
    super.initState();
    fractions = List.of(widget.initialFractions);
  }

  @override
  void dispose() {
    if (_isDragging) {
      toggleIframePointerEvents(false);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: _buildLayout);
  }

  Widget _buildLayout(BuildContext _, BoxConstraints constraints) {
    final width = constraints.maxWidth;
    final height = constraints.maxHeight;
    final axisSize = isHorizontal ? width : height;

    final availableSize = axisSize - _totalSplitterSize();

    double minSizeForIndex(int index) {
      if (widget.minSizes == null) return 0.0;

      double totalMinSize = 0;
      for (final minSize in widget.minSizes!) {
        totalMinSize += minSize;
      }

      return totalMinSize > availableSize
          ? widget.minSizes![index] * availableSize / totalMinSize
          : widget.minSizes![index];
    }

    double minFractionForIndex(int index) =>
        minSizeForIndex(index) / availableSize;

    void clampFraction(int index) {
      fractions[index] = fractions[index].clamp(
        minFractionForIndex(index),
        1.0,
      );
    }

    double sizeForIndex(int index) => availableSize * fractions[index];

    double fractionDeltaRequired = 0.0;
    double fractionDeltaAvailable = 0.0;

    double deltaFromMinimumSize(int index) =>
        fractions[index] - minFractionForIndex(index);

    for (int i = 0; i < fractions.length; ++i) {
      final delta = deltaFromMinimumSize(i);
      if (delta < 0) {
        fractionDeltaRequired -= delta;
      } else {
        fractionDeltaAvailable += delta;
      }
    }
    if (fractionDeltaRequired > 0) {
      double scaleFactor = fractionDeltaRequired / fractionDeltaAvailable;
      assert(scaleFactor <= 1 + defaultEpsilon);
      scaleFactor = math.min(scaleFactor, 1.0);
      for (int i = 0; i < fractions.length; ++i) {
        final delta = deltaFromMinimumSize(i);
        if (delta < 0) {
          fractions[i] = minFractionForIndex(i);
        } else {
          fractions[i] -= delta * scaleFactor;
        }
      }
    }

    final sizes = List.generate(fractions.length, (i) => sizeForIndex(i));

    void updateSpacing(DragUpdateDetails dragDetails, int splitterIndex) {
      final dragDelta = isHorizontal
          ? dragDetails.delta.dx
          : dragDetails.delta.dy;
      final fractionalDelta = dragDelta / axisSize;

      double updateSpacingBeforeSplitterIndex(double delta) {
        final startingDelta = delta;
        var index = splitterIndex;
        while (index >= 0) {
          fractions[index] += delta;
          final minFraction = minFractionForIndex(index);
          if (fractions[index] >= minFraction) {
            clampFraction(index);
            return startingDelta;
          }
          delta = fractions[index] - minFraction;
          clampFraction(index);
          index--;
        }
        return startingDelta - delta;
      }

      double updateSpacingAfterSplitterIndex(double delta) {
        final startingDelta = delta;
        var index = splitterIndex + 1;
        while (index < fractions.length) {
          fractions[index] += delta;
          final minFraction = minFractionForIndex(index);
          if (fractions[index] >= minFraction) {
            clampFraction(index);
            return startingDelta;
          }
          delta = fractions[index] - minFraction;
          clampFraction(index);
          index++;
        }
        return startingDelta - delta;
      }

      setState(() {
        if (fractionalDelta <= 0.0) {
          final appliedDelta = updateSpacingBeforeSplitterIndex(
            fractionalDelta,
          );
          updateSpacingAfterSplitterIndex(-appliedDelta);
        } else {
          final appliedDelta = updateSpacingAfterSplitterIndex(
            -fractionalDelta,
          );
          updateSpacingBeforeSplitterIndex(-appliedDelta);
        }
      });
      _verifyFractionsSumTo1(fractions);
    }

    final children = <Widget>[];
    for (int i = 0; i < widget.children.length; i++) {
      children.addAll([
        SizedBox(
          width: isHorizontal ? sizes[i] : width,
          height: isHorizontal ? height : sizes[i],
          child: widget.children[i],
        ),
        if (i < widget.children.length - 1)
          MouseRegion(
            cursor: isHorizontal
                ? SystemMouseCursors.resizeColumn
                : SystemMouseCursors.resizeRow,
            child: GestureDetector(
              key: widget.dividerKey(i),
              behavior: HitTestBehavior.translucent,
              onPanStart: (details) {
                _isDragging = true;
                toggleIframePointerEvents(true);
              },
              onPanUpdate: (details) => updateSpacing(details, i),
              onPanEnd: (details) {
                _isDragging = false;
                toggleIframePointerEvents(false);
              },
              onPanCancel: () {
                _isDragging = false;
                toggleIframePointerEvents(false);
              },
              dragStartBehavior: DragStartBehavior.down,
              child: widget.splitters != null
                  ? widget.splitters![i]
                  : DefaultSplitter(isHorizontal: isHorizontal),
            ),
          ),
      ]);
    }
    return Flex(
      direction: widget.axis,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  double _totalSplitterSize() {
    final numSplitters = widget.children.length - 1;
    if (widget.splitters == null) {
      return numSplitters * DefaultSplitter.splitterWidth;
    } else {
      var totalSize = 0.0;
      for (final splitter in widget.splitters!) {
        totalSize += isHorizontal
            ? splitter.preferredSize.width
            : splitter.preferredSize.height;
      }
      return totalSize;
    }
  }
}

final class DefaultSplitter extends StatelessWidget {
  const DefaultSplitter({super.key, required this.isHorizontal});

  static const iconSize = 24.0;
  static const splitterWidth = 12.0;

  final bool isHorizontal;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: isHorizontal ? degToRad(90.0) : degToRad(0.0),
      child: Align(
        widthFactor: 0.5,
        heightFactor: 0.5,
        child: Icon(
          Icons.drag_handle,
          size: iconSize,
          color: Theme.of(context).focusColor,
        ),
      ),
    );
  }
}

void _verifyFractionsSumTo1(List<double> fractions) {
  var sumFractions = 0.0;
  for (final fraction in fractions) {
    sumFractions += fraction;
  }
  assert(
    (1.0 - sumFractions).abs() < defaultEpsilon,
    'Fractions should sum to 1.0, but instead sum to $sumFractions:\n$fractions',
  );
}
