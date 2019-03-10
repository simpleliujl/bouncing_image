import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:flutter/physics.dart' show SpringDescription;
import 'package:flutter/widgets.dart';

import 'zoom_activity.dart';

class ZoomPosition extends ChangeNotifier {
  final TickerProvider vsync;
  ScrollPhysics scrollPhysics = BouncingScrollPhysics();
  ZoomActivity currentActivity;

  double scale = 1.0;
  Offset offset = Offset.zero;

  double minScale = 1.0;
  double maxScale;

  double _specifiedMinScale;
  double _specifiedMaxScale;

  Size viewportSize;
  Size contentSize;

  ZoomPosition({
    this.viewportSize,
    this.contentSize,
    double minScale,
    double maxScale,
    this.vsync,
  }) {
    _specifiedMinScale = minScale;
    _specifiedMaxScale = maxScale;
    _calculateScaleLimit();
    _sizeToFit();
  }

  void applyViewportSize(Size newViewportSize) {
    if (viewportSize != newViewportSize) {
      viewportSize = newViewportSize;
      _calculateScaleLimit();
      _sizeToFit();
      goIdle();
    }
  }

  void applyContentSize(Size newContentSize) {
    if (contentSize != newContentSize) {
      contentSize = newContentSize;
      _calculateScaleLimit();
      _sizeToFit();
      goIdle();
    }
  }

  void applyScaleLimit(double newMinScale, double newMaxScale) {
    if (_specifiedMaxScale != newMaxScale ||
        _specifiedMinScale != newMinScale) {
      _specifiedMinScale = newMinScale;
      _specifiedMaxScale = newMaxScale;
      _calculateScaleLimit();
      _sizeToFit();
    }
  }

  void applyUserOffset(Offset offsetDelta) {
    final ScrollMetrics hMetrics = FixedScrollMetrics(
      minScrollExtent: contentSize.width * scale > viewportSize.width
          ? viewportSize.width - contentSize.width * scale
          : (viewportSize.width - contentSize.width * scale) * 0.5,
      maxScrollExtent: contentSize.width * scale > viewportSize.width
          ? 0.0
          : (viewportSize.width - contentSize.width * scale) * 0.5,
      pixels: offset.dx,
      viewportDimension: viewportSize.width,
      axisDirection: AxisDirection.down,
    );

    final ScrollMetrics vMetrics = FixedScrollMetrics(
      minScrollExtent: contentSize.height * scale > viewportSize.height
          ? viewportSize.height - contentSize.height * scale
          : (viewportSize.height - contentSize.height * scale) * 0.5,
      maxScrollExtent: contentSize.height * scale > viewportSize.height
          ? 0.0
          : (viewportSize.height - contentSize.height * scale) * 0.5,
      pixels: offset.dy,
      viewportDimension: viewportSize.height,
      axisDirection: AxisDirection.down,
    );

    offsetDelta = Offset(
      offsetDelta.dx == 0.0
          ? 0.0
          : -scrollPhysics.applyPhysicsToUserOffset(hMetrics, -offsetDelta.dx),
      offsetDelta.dy == 0.0
          ? 0.0
          : -scrollPhysics.applyPhysicsToUserOffset(vMetrics, -offsetDelta.dy),
    );
    jumpTo(scale, offset + offsetDelta);
  }

  void applyUserRelativeScale(double relativeScale, Offset contentFocusPos) {
    if (relativeScale == 1.0) return;
    double scaleDelta = scale * (relativeScale - 1.0);
    scaleDelta = -scrollPhysics.applyPhysicsToUserOffset(
      FixedScrollMetrics(
        minScrollExtent: minScale,
        maxScrollExtent: maxScale,
        pixels: scale,
        viewportDimension: (maxScale * 1.5 - minScale * 0.5),
        axisDirection: AxisDirection.down,
      ),
      -scaleDelta,
    );

    zoomTo(newScale: scale + scaleDelta, contentFocusPos: contentFocusPos);
  }

  void beginActivity(ZoomActivity activity) {
    currentActivity?.dispose();
    currentActivity = activity;
  }

  ScaleZoomActivity beginScaleGest(
      Offset viewportFocusPos, ScaleStartDetails details) {
    final scaleActivity = ScaleZoomActivity(
      contentFocusPos: viewportPosToContentPos(viewportFocusPos),
      prevGestFocusPos: details.focalPoint,
      delegate: this,
    );
    beginActivity(scaleActivity);
    return scaleActivity;
  }

  Offset contentPosToViewportPos(Offset contentPos) {
    return contentPos * scale + offset;
  }

  void goBallistic(Offset contentFocusPos, Velocity velocity) {
    final targetScale = scale.clamp(minScale, maxScale);

    final targetOffsetMinX =
        contentSize.width * targetScale > viewportSize.width
            ? viewportSize.width - contentSize.width * targetScale
            : (viewportSize.width - contentSize.width * targetScale) * 0.5;
    final targetOffsetMaxX =
        contentSize.width * targetScale > viewportSize.width
            ? 0.0
            : (viewportSize.width - contentSize.width * targetScale) * 0.5;
    final targetOffsetMinY =
        contentSize.height * targetScale > viewportSize.height
            ? viewportSize.height - contentSize.height * targetScale
            : (viewportSize.height - contentSize.height * targetScale) * 0.5;
    final targetOffsetMaxY =
        contentSize.height * targetScale > viewportSize.height
            ? 0.0
            : (viewportSize.height - contentSize.height * targetScale) * 0.5;

    final targetMinViewportFocus = contentFocusPos * targetScale +
        Offset(targetOffsetMinX, targetOffsetMinY);
    final targetMaxViewportFocus = contentFocusPos * targetScale +
        Offset(targetOffsetMaxX, targetOffsetMaxY);

    final viewportFocus = contentPosToViewportPos(contentFocusPos);

    final hSimulation = scrollPhysics.createBallisticSimulation(
      FixedScrollMetrics(
        minScrollExtent: targetMinViewportFocus.dx,
        maxScrollExtent: targetMaxViewportFocus.dx,
        pixels: viewportFocus.dx,
        viewportDimension: viewportSize.width,
        axisDirection: AxisDirection.down,
      ),
      velocity.pixelsPerSecond.dx,
    );

    final vSimulation = scrollPhysics.createBallisticSimulation(
      FixedScrollMetrics(
        minScrollExtent: targetMinViewportFocus.dy,
        maxScrollExtent: targetMaxViewportFocus.dy,
        pixels: viewportFocus.dy,
        viewportDimension: viewportSize.height,
        axisDirection: AxisDirection.down,
      ),
      velocity.pixelsPerSecond.dy,
    );

    final sSimulation = BouncingScrollSimulation(
      position: scale,
      velocity: 0.0,
      leadingExtent: minScale,
      trailingExtent: maxScale,
      spring: SpringDescription.withDampingRatio(
        mass: 0.5,
        stiffness: 100.0,
        ratio: 1.1,
      ),
    );

    beginActivity(BallisticZoomActivity(
      vSimulation: vSimulation,
      hSimulation: hSimulation,
      sSimulation: sSimulation,
      contentFocusPos: contentFocusPos,
      vsync: vsync,
      delegate: this,
    ));
  }

  void goIdle() {
    beginActivity(IdleZoomActivity());
  }

  Future<void> animateTo({
    double newScale,
    Offset newOffset,
    Duration duration,
    Curve curve,
  }) {
    AnimationZoomActivity activity = AnimationZoomActivity(
      fromScale: scale,
      fromOffset: offset,
      toScale: newScale,
      toOffset: newOffset,
      delegate: this,
      vsync: vsync,
      duration: duration,
      curve: curve,
    );
    beginActivity(activity);
    return activity.done;
  }

  void jumpTo(double newScale, Offset newOffset) {
    scale = newScale;
    offset = newOffset;
    notifyListeners();
  }

  void panTo({Offset contentPos, Offset viewportPos}) {
    jumpTo(scale, viewportPos - contentPos * scale);
  }

  Offset viewportPosToContentPos(Offset viewportPos) {
    return (viewportPos - offset) / scale;
  }

  void zoomTo({double newScale, Offset contentFocusPos}) {
    /// contentFocusPos * scale + offset = viewportFocusPos
    /// contentFocusPos * newScale + newOffset = viewportFocusPos
    final newOffset = contentFocusPos * (scale - newScale) + offset;

    jumpTo(newScale, newOffset);
  }

  void _calculateScaleLimit() {
    if (viewportSize != null && contentSize != null) {
      minScale = _specifiedMinScale ??
          math.min(viewportSize.width / contentSize.width,
              viewportSize.height / contentSize.height);
      maxScale = _specifiedMaxScale ?? math.max(1.0, minScale);
    } else {
      minScale = 1.0;
      maxScale = 1.0;
    }
  }

  void _sizeToFit() {
    jumpTo(minScale, viewportSize * 0.5 - contentSize * 0.5 * minScale);
  }

  @override
  void dispose() {
    goIdle();
    super.dispose();
  }
}
