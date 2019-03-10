import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';

import 'raw_bouncing_image.dart';
import 'zoom_controller.dart';

typedef Widget Builder(BuildContext context);

class BouncingImage extends StatefulWidget {
  final ImageProvider imageProvider;
  final Builder loadingBuilder;
  final double minScale;
  final double maxScale;
  final ZoomController controller;

  const BouncingImage({
    Key key,
    @required this.imageProvider,
    this.controller,
    this.loadingBuilder,
    this.minScale,
    this.maxScale,
  }) : super(key: key);

  @override
  _BouncingImageState createState() {
    return _BouncingImageState();
  }
}

class _BouncingImageState extends State<BouncingImage> {
  ImageStream _imageStream;
  ui.Image _rawImage;

  @override
  void dispose() {
    _imageStream?.removeListener(_handleImageLoaded);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveImage();
  }

  @override
  void didUpdateWidget(BouncingImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageProvider != widget.imageProvider) _resolveImage();
  }

  @override
  Widget build(BuildContext context) {
    return _rawImage != null
        ? RawBouncingImage(
            controller: widget.controller,
            image: _rawImage,
            minScale: widget.minScale,
            maxScale: widget.maxScale)
        : widget.loadingBuilder != null
            ? widget.loadingBuilder(context)
            : Center(child: CircularProgressIndicator());
  }

  void _resolveImage() {
    final imgStream =
        widget.imageProvider.resolve(createLocalImageConfiguration(context));
    if (imgStream.key == _imageStream?.key) {
      return;
    }
    _rawImage = null;
    _imageStream?.removeListener(_handleImageLoaded);
    imgStream.addListener(_handleImageLoaded);
    _imageStream = imgStream;
  }

  void _handleImageLoaded(ImageInfo info, bool isSync) {
    if (_rawImage != info.image) setState(() => _rawImage = info.image);
  }
}
