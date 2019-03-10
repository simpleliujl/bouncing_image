import 'dart:async';

import 'zoom_position.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/gestures.dart';

abstract class ZoomActivity {
  ZoomPosition delegate;
  ZoomActivity({@required this.delegate});

  get disposed => delegate == null;

  @mustCallSuper
  void dispose() {
    delegate = null;
  }
}

class IdleZoomActivity extends ZoomActivity {}

class ScaleZoomActivity extends ZoomActivity {
  final Offset contentFocusPos;
  Offset prevGestFocusPos;
  double prevGestScale = 1.0;

  ScaleZoomActivity({
    this.contentFocusPos,
    this.prevGestFocusPos,
    @required ZoomPosition delegate,
  }) : super(delegate: delegate);

  void scaleUpdate(ScaleUpdateDetails detail) {
    if (disposed) return;
    final relativeScale = detail.scale / prevGestScale;
    final offsetDelta = detail.focalPoint - prevGestFocusPos;

    delegate.applyUserRelativeScale(relativeScale, contentFocusPos);
    delegate.applyUserOffset(offsetDelta);

    prevGestFocusPos = detail.focalPoint;
    prevGestScale = detail.scale;
  }

  void scaleEnd(ScaleEndDetails detail) {
    if (disposed) return;
    delegate.goBallistic(contentFocusPos, detail.velocity);
  }
}

class BallisticZoomActivity extends ZoomActivity {
  AnimationController hAnimationController;
  AnimationController vAnimationController;
  AnimationController sAnimationController;
  final Offset contentFocusPos;
  int countDown = 0;

  BallisticZoomActivity({
    Simulation vSimulation,
    Simulation hSimulation,
    Simulation sSimulation,
    @required ZoomPosition delegate,
    @required TickerProvider vsync,
    @required this.contentFocusPos,
  }) : super(delegate: delegate) {
    if (hSimulation != null) {
      ++countDown;
      hAnimationController = AnimationController.unbounded(vsync: vsync)
        ..addListener(_posTick)
        ..animateWith(hSimulation).whenComplete(_end);
    }

    if (vSimulation != null) {
      ++countDown;
      vAnimationController = AnimationController.unbounded(vsync: vsync)
        ..addListener(_posTick)
        ..animateWith(vSimulation).whenComplete(_end);
    }

    if (sSimulation != null) {
      ++countDown;
      sAnimationController = AnimationController.unbounded(vsync: vsync)
        ..addListener(_scaleTick)
        ..animateWith(sSimulation).whenComplete(_end);
    }
  }

  @override
  void dispose() {
    hAnimationController?.dispose();
    vAnimationController?.dispose();
    sAnimationController?.dispose();
    super.dispose();
  }

  void _posTick() {
    Offset viewportFocusPos = delegate.contentPosToViewportPos(contentFocusPos);
    if (hAnimationController != null) {
      viewportFocusPos =
          Offset(hAnimationController.value, viewportFocusPos.dy);
    }
    if (vAnimationController != null) {
      viewportFocusPos =
          Offset(viewportFocusPos.dx, vAnimationController.value);
    }
    delegate.panTo(
      contentPos: contentFocusPos,
      viewportPos: viewportFocusPos,
    );
  }

  void _scaleTick() {
    delegate.zoomTo(
      newScale: sAnimationController.value,
      contentFocusPos: contentFocusPos,
    );
  }

  void _end() {
    if (--countDown == 0) {
      delegate.goIdle();
    }
  }
}

class AnimationZoomActivity extends ZoomActivity {
  AnimationController animationController;
  Animation<Offset> offset;
  Animation<double> scale;

  Completer<void> _completer;
  get done => _completer.future;

  AnimationZoomActivity({
    @required double fromScale,
    @required Offset fromOffset,
    @required double toScale,
    @required Offset toOffset,
    Duration duration = const Duration(milliseconds: 250),
    Curve curve = Curves.easeInOut,
    @required TickerProvider vsync,
    @required ZoomPosition delegate,
  }) : super(delegate: delegate) {
    _completer = Completer<void>();
    animationController = AnimationController(
      duration: duration,
      vsync: vsync,
    )
      ..addListener(_tick)
      ..forward().whenComplete(_end);

    offset = Tween<Offset>(begin: fromOffset, end: toOffset)
        .chain(CurveTween(curve: curve))
        .animate(animationController);
    scale = Tween<double>(begin: fromScale, end: toScale)
        .chain(CurveTween(curve: curve))
        .animate(animationController);
  }

  void _tick() {
    delegate.jumpTo(scale.value, offset.value);
  }

  @override
  void dispose() {
    animationController.dispose();
    _completer.complete();
    super.dispose();
  }

  void _end() {
    delegate.goIdle();
  }
}
