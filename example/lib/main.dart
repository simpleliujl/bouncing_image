import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:bouncing_image/bouncing_image.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bouncing Image Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Scaffold(
        appBar: AppBar(title: Text("Bouncing Image")),
        body: GestureImage(
          image: AssetImage("images/lake.jpg"),
        ),
      ),
    );
  }
}

class GestureImage extends StatelessWidget {
  final controller = ZoomController();
  final ImageProvider image;

  GestureImage({
    Key key,
    @required this.image,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: _handleDoubleTap,
      child: BouncingImage(
        imageProvider: AssetImage("images/lake.jpg"),
        controller: controller,
      ),
    );
  }

  void _handleDoubleTap() {
    if (controller.attached) {
      final contentSize = controller.contentSize;
      final viewportSize = controller.viewportSize;
      final scale = controller.minScale;

      final offset = Offset(
        math.max((viewportSize.width - contentSize.width * scale) * 0.5, 0.0),
        math.max((viewportSize.height - contentSize.height * scale) * 0.5, 0.0),
      );

      controller.zoomTo(
        scale,
        offset: offset,
      );
    }
  }
}
