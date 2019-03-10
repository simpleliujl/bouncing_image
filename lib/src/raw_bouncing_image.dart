import 'package:flutter/material.dart';
import 'dart:ui' as ui;

import 'zoom_position.dart';
import 'zoom_controller.dart';
import 'zoom_activity.dart' show ScaleZoomActivity;

class RawBouncingImage extends StatelessWidget {
  final ui.Image image;
  final double minScale;
  final double maxScale;
  final ZoomController controller;

  const RawBouncingImage({
    Key key,
    this.controller,
    this.image,
    this.minScale,
    this.maxScale,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraint) {
      return SizedRawBouncingImage(
        controller: controller,
        image: image,
        minScale: minScale,
        maxScale: maxScale,
        viewportSize: constraint.biggest,
      );
    });
  }
}

class SizedRawBouncingImage extends StatefulWidget {
  final ui.Image image;
  final Size viewportSize;
  final double minScale;
  final double maxScale;
  final ZoomController controller;

  const SizedRawBouncingImage({
    Key key,
    this.controller,
    this.image,
    this.viewportSize,
    this.minScale,
    this.maxScale,
  }) : super(key: key);

  @override
  _SizedRawBouncingImageState createState() => _SizedRawBouncingImageState();
}

class _SizedRawBouncingImageState extends State<SizedRawBouncingImage>
    with TickerProviderStateMixin {
  ZoomController controller;
  ZoomPosition zoomPosition;
  ScaleZoomActivity scaleActivity;

  @override
  void initState() {
    super.initState();
    zoomPosition = ZoomPosition(
      viewportSize: widget.viewportSize,
      contentSize:
          Size(widget.image.width.toDouble(), widget.image.height.toDouble()),
      vsync: this,
    );
    widget.controller?.attach(zoomPosition);

    zoomPosition.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    widget.controller?.detach(zoomPosition);

    zoomPosition.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(SizedRawBouncingImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image.width != widget.image.width ||
        oldWidget.image.height != widget.image.height) {
      zoomPosition.applyContentSize(
          Size(widget.image.width.toDouble(), widget.image.height.toDouble()));
    }

    if (oldWidget.viewportSize != widget.viewportSize) {
      zoomPosition.applyViewportSize(widget.viewportSize);
    }

    if (oldWidget.maxScale != widget.maxScale ||
        oldWidget.minScale != widget.minScale) {
      zoomPosition.applyScaleLimit(widget.minScale, widget.maxScale);
    }

    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.detach(zoomPosition);
      widget.controller?.attach(zoomPosition);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _gestWidget();
  }

  Widget _gestWidget() {
    return GestureDetector(
      onScaleStart: _handleScaleStart,
      onScaleUpdate: _handleScaleUpdate,
      onScaleEnd: _handleScaleEnd,
      child: _paintWidget(),
    );
  }

  Widget _paintWidget() {
    return CustomPaint(
      child: Container(
        color: Colors.black,
      ),
      foregroundPainter: RawImagePainter(
        image: widget.image,
        offset: zoomPosition.offset,
        scale: zoomPosition.scale,
      ),
    );
  }

  Offset _globalToLocal(Offset globalPos) {
    RenderObject box = context.findRenderObject();
    if (box is RenderBox) {
      return box.globalToLocal(globalPos);
    } else {
      return globalPos;
    }
  }

  void _handleScaleStart(ScaleStartDetails d) {
    scaleActivity =
        zoomPosition.beginScaleGest(_globalToLocal(d.focalPoint), d);
  }

  void _handleScaleUpdate(ScaleUpdateDetails d) {
    scaleActivity.scaleUpdate(d);
  }

  void _handleScaleEnd(ScaleEndDetails d) {
    scaleActivity.scaleEnd(d);
  }
}

class RawImagePainter extends CustomPainter {
  final ui.Image image;
  final Offset offset;
  final double scale;

  RawImagePainter({
    this.image,
    this.offset,
    this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final imageSize = Size(image.width.toDouble(), image.height.toDouble());
    final targetSize = imageSize * scale;
    paintImage(
      canvas: canvas,
      rect: offset & targetSize,
      image: image,
      fit: BoxFit.fill,
    );
  }

  @override
  bool shouldRepaint(RawImagePainter oldPainter) {
    return oldPainter.image != image ||
        oldPainter.offset != offset ||
        oldPainter.scale != scale;
  }
}
