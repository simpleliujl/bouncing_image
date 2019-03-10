import 'dart:ui';

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

import 'zoom_position.dart';

class ZoomController extends ChangeNotifier {
  List<ZoomPosition> positions = [];

  ZoomPosition get position => positions[0];

  bool get attached => positions.isNotEmpty;

  double get scale => position.scale;

  Offset get offset => position.offset;

  Size get contentSize => position.contentSize;

  Size get viewportSize => position.viewportSize;

  double get minScale => position.minScale;
  double get maxScale => position.maxScale;

  Future<void> zoomTo(
    double scale, {
    Offset offset,
    Offset contentFocalPos,
    Offset viewportFocalPos,
    bool animated = true,
    Duration duration = const Duration(milliseconds: 250),
    Curve curve = Curves.easeInOut,
  }) {
    if (!attached) return Future<void>.value();

    // contentPos * scale + offset = viewportPos;
    if (offset == null) {
      if (contentFocalPos == null && viewportFocalPos != null) {
        contentFocalPos = position.viewportPosToContentPos(viewportFocalPos);
      } else if (contentFocalPos != null && viewportFocalPos == null) {
        viewportFocalPos = position.contentPosToViewportPos(contentFocalPos);
      } else if (contentFocalPos == null && viewportFocalPos == null) {
        viewportFocalPos = Offset.zero;
        contentFocalPos = Offset.zero;
      }
      offset = viewportFocalPos - contentFocalPos * scale;
    }

    if (animated) {
      return position.animateTo(
          newScale: scale, newOffset: offset, duration: duration, curve: curve);
    } else {
      position.jumpTo(scale, offset);
      return Future<void>.value();
    }
  }

  void attach(ZoomPosition newPosition) {
    newPosition.addListener(notifyListeners);
    positions.add(newPosition);
  }

  void detach(ZoomPosition currentPosition) {
    currentPosition.removeListener(notifyListeners);
    positions.remove(currentPosition);
  }
}
