import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'pen.dart';
import 'utils.dart';

/// pen to simulate a eraser:
/// the stroke is fixed to [PenState.strokeMinWidth]
class Eraser with Pen {
  // calculate average point distances
  double _averageDistance() {
    double ret = 0;
    int k = drawing.distances.length > averageStrokes
        ? averageStrokes
        : drawing.distances.length;
    for (int i = drawing.distances.length - k;
        i < drawing.distances.length;
        i++) {
      ret += drawing.distances[i];
    }
    ret /= k;
    return ret;
  }

  @override
  int averageStrokes = 10; // not used

  @override
  CustomPainter painter = _Painter();

  @override
  onPointerDown(PointerDownEvent event) {
    drawing.points.clear();
    drawing.path.reset();
    drawing.points.add(event.localPosition);
    drawing.path.moveTo(event.localPosition.dx, event.localPosition.dy);
    painter = _Painter();
  }

  @override
  onPointerMove(PointerMoveEvent event) {
    drawing.points.add(event.localPosition);

    double averageDistances = 0.0;
    double distance = 0;
    if (drawing.points.isNotEmpty) {
      if (drawing.points.length > 2) {
        distance = (drawing.points[drawing.points.length - 1] -
                drawing.points[drawing.points.length - 2])
            .distance;
      }
    }

    drawing.distances.add(distance);

    averageDistances = _averageDistance();

    //Curves.easeInQuad.transform((1.0 - averageDistances / 8).clamp(0.0, 1.0));

    double s = (averageDistances * penState.strokeMaxWidth)
        .clamp(penState.strokeMinWidth, penState.strokeMaxWidth);

    drawing.strokeWidths.add(s);

    painter = _Painter(
      andSaveImage: true,
      onImageSaved: onImageSaved != null
          ? (imgBytesList) => onImageSaved!(imgBytesList)
          : null,
    );
  }

  @override
  onPointerUp(PointerUpEvent event) {
    painter = _Painter(
      andSaveImage: true,
      onImageSaved: onImageSaved != null
          ? (imgBytesList) => onImageSaved!(imgBytesList)
          : null,
    );
    drawing.points.clear();
    drawing.path.reset();
  }
}

/// Painter class to draw current painted strokes.
/// When [andSaveImage] is true the canvas is
/// saved into [imgBytesList] and [image]
class _Painter extends CustomPainter {
  final bool andSaveImage;
  final Function(Uint8List? imgBytes)? onImageSaved;

  _Painter({
    this.andSaveImage = false,
    this.onImageSaved,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (drawing.points.isEmpty) return;
    final recorder = ui.PictureRecorder();
    Canvas? canvas2;
    if (andSaveImage) {
      canvas2 = Canvas(recorder,
          Rect.fromPoints(Offset.zero, Offset(size.width, size.height)));
    }

    var recorderPaint = Paint();
    var paint = Paint()
      ..blendMode = penState.blendMode
      ..color = penState.strokeColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    if (penState.blurSigma > 0) {
      paint.imageFilter = ui.ImageFilter.blur(
          sigmaX: penState.blurSigma, sigmaY: penState.blurSigma);
    }

    if (andSaveImage) {
      recorderPaint.color = penState.strokeColor;
      recorderPaint.style = PaintingStyle.stroke;
      recorderPaint.strokeCap = StrokeCap.round;
      if (penState.blurSigma > 0) {
        recorderPaint.imageFilter = ui.ImageFilter.blur(
            sigmaX: penState.blurSigma, sigmaY: penState.blurSigma);
      }

      for (int i = 1; i < drawing.points.length; i++) {
        paint.strokeWidth = recorderPaint.strokeWidth = drawing.strokeWidths[i];
        canvas2?.drawLine(
            drawing.points[i - 1], drawing.points[i], recorderPaint);
      }
    }

    if (andSaveImage) {
      ui.Picture picture = recorder.endRecording();
      blendPictures(size, penState.blendMode, picture, onImageSaved);
    }
  }

  @override
  bool shouldRepaint(covariant _Painter oldDelegate) {
    return true;
  }
}
