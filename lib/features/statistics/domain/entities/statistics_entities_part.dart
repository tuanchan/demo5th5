part of flutterflashcard_main;

class StatisticsData {
  final int totalCourses;
  final int totalCards;
  final int masteredCards;
  final int needReviewCards;
  final int favoriteCards;
  final int totalSessions;
  final int totalCorrect;
  final int totalWrong;
  final int totalAnswered;
  final int reviewedTodayCards;
  final int hardCards;
  final List<SrsDistributionItem> srsItems;
  final List<DueScheduleItem> dueScheduleItems;
  final List<LanguageDistributionItem> languageItems;
  final List<HardCourseItem> hardCourseItems;
  final List<CourseStatisticsItem> courseItems;
  final List<ReviewDueItem> dueItems;

  StatisticsData({
    required this.totalCourses,
    required this.totalCards,
    required this.masteredCards,
    required this.needReviewCards,
    required this.favoriteCards,
    required this.totalSessions,
    required this.totalCorrect,
    required this.totalWrong,
    required this.totalAnswered,
    required this.reviewedTodayCards,
    required this.hardCards,
    required this.srsItems,
    required this.dueScheduleItems,
    required this.languageItems,
    required this.hardCourseItems,
    required this.courseItems,
    required this.dueItems,
  });

  int get completionPercent {
    if (totalCards <= 0) return 0;
    return ((masteredCards / totalCards) * 100).round().clamp(0, 100).toInt();
  }

  int get accuracyPercent {
    final sum = totalCorrect + totalWrong;
    if (sum <= 0) return 0;
    return ((totalCorrect / sum) * 100).round().clamp(0, 100).toInt();
  }

  int get unmasteredCards => math.max(0, totalCards - masteredCards);

  int get languageCount => languageItems.length;

  int get learningCards {
    return srsItems
        .where((item) => item.label.startsWith('Cấp 1'))
        .fold(0, (sum, item) => sum + item.count);
  }

  int get reviewingCards {
    return srsItems
        .where((item) => item.label.startsWith('Cấp 4'))
        .fold(0, (sum, item) => sum + item.count);
  }
}


class CourseStatisticsItem {
  final int id;
  final String title;
  final String languageCode;
  final int totalCards;
  final int masteredCards;
  final int needReviewCards;
  final int reviewedTodayCards;
  final int masteredTodayCards;
  final int correctCount;
  final int wrongCount;
  final int sessionCount;

  CourseStatisticsItem({
    required this.id,
    required this.title,
    required this.languageCode,
    required this.totalCards,
    required this.masteredCards,
    required this.needReviewCards,
    required this.reviewedTodayCards,
    required this.masteredTodayCards,
    required this.correctCount,
    required this.wrongCount,
    required this.sessionCount,
  });

  int get progressPercent {
    if (totalCards <= 0) return 0;
    return ((masteredCards / totalCards) * 100).round().clamp(0, 100).toInt();
  }
}


class ReviewDueItem {
  final String term;
  final String definition;
  final String courseTitle;
  final int level;
  final int repetitionCount;
  final int intervalDays;

  ReviewDueItem({
    required this.term,
    required this.definition,
    required this.courseTitle,
    required this.level,
    required this.repetitionCount,
    required this.intervalDays,
  });
}


class SrsDistributionItem {
  final String label;
  final String subtitle;
  final int count;
  final Color color;

  SrsDistributionItem({
    required this.label,
    required this.subtitle,
    required this.count,
    required this.color,
  });
}


class DueScheduleItem {
  final String label;
  final int count;

  DueScheduleItem({required this.label, required this.count});
}


class LanguageDistributionItem {
  final String label;
  final int count;
  final Color color;

  LanguageDistributionItem({
    required this.label,
    required this.count,
    required this.color,
  });
}


class HardCourseItem {
  final String title;
  final int hardCards;
  final int totalCards;

  HardCourseItem({
    required this.title,
    required this.hardCards,
    required this.totalCards,
  });
}


class StatisticsPage extends StatefulWidget {
  StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}


class StatisticsDonutPainter extends CustomPainter {
  final double percent;
  final Color backgroundColor;
  final Color progressColor;
  final double strokeWidth;

  StatisticsDonutPainter({
    required this.percent,
    required this.backgroundColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - strokeWidth / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * percent.clamp(0.0, 1.0).toDouble(),
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant StatisticsDonutPainter oldDelegate) {
    return oldDelegate.percent != percent ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}


class DueSchedulePainter extends CustomPainter {
  final List<DueScheduleItem> items;
  final Color lineColor;
  final Color textColor;
  final Color gridColor;

  DueSchedulePainter({
    required this.items,
    required this.lineColor,
    required this.textColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final chart = Rect.fromLTWH(28, 8, size.width - 36, size.height - 34);
    var maxValue = 1;
    for (final item in items) {
      maxValue = math.max(maxValue, item.count);
    }
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    for (var i = 0; i <= 4; i++) {
      final y = chart.top + chart.height * i / 4;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
    }

    if (items.isEmpty) return;

    final points = <Offset>[];
    for (var i = 0; i < items.length; i++) {
      final x = items.length == 1
          ? chart.center.dx
          : chart.left + chart.width * i / (items.length - 1);
      final y = chart.bottom - chart.height * (items[i].count / maxValue);
      points.add(Offset(x, y));
    }

    final fillPath = Path()
      ..moveTo(points.first.dx, chart.bottom)
      ..lineTo(points.first.dx, points.first.dy);
    final linePath = Path()..moveTo(points.first.dx, points.first.dy);

    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final current = points[i];
      final controlX = (previous.dx + current.dx) / 2;
      linePath.cubicTo(
        controlX,
        previous.dy,
        controlX,
        current.dy,
        current.dx,
        current.dy,
      );
      fillPath.cubicTo(
        controlX,
        previous.dy,
        controlX,
        current.dy,
        current.dx,
        current.dy,
      );
    }

    fillPath
      ..lineTo(points.last.dx, chart.bottom)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [lineColor.withOpacity(0.22), lineColor.withOpacity(0.02)],
        ).createShader(chart),
    );

    canvas.drawPath(
      linePath,
      Paint()
        ..color = lineColor
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      canvas.drawCircle(point, 4.4, Paint()..color = Colors.white);
      canvas.drawCircle(point, 3, Paint()..color = lineColor);
      _drawChartText(
        canvas,
        items[i].count.toString(),
        Offset(point.dx, math.max(0, point.dy - 18)),
        Colors.white,
        10,
        FontWeight.w900,
        TextAlign.center,
      );
      _drawChartText(
        canvas,
        items[i].label,
        Offset(point.dx, chart.bottom + 14),
        textColor,
        9,
        FontWeight.w800,
        TextAlign.center,
      );
    }
  }

  void _drawChartText(
    Canvas canvas,
    String text,
    Offset center,
    Color color,
    double fontSize,
    FontWeight weight,
    TextAlign align,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: fontSize, fontWeight: weight),
      ),
      textAlign: align,
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: 68);
    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant DueSchedulePainter oldDelegate) {
    return oldDelegate.items != items ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.textColor != textColor ||
        oldDelegate.gridColor != gridColor;
  }
}


class LanguageDonutPainter extends CustomPainter {
  final List<LanguageDistributionItem> items;
  final int total;
  final Color trackColor;

  LanguageDonutPainter({
    required this.items,
    required this.total,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 11;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, paint..color = trackColor);

    if (total <= 0) return;

    var start = -math.pi / 2;
    for (final item in items) {
      final sweep = math.pi * 2 * item.count / total;
      final drawSweep = sweep > 0.1 ? sweep - 0.08 : sweep;
      canvas.drawArc(rect, start, drawSweep, false, paint..color = item.color);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant LanguageDonutPainter oldDelegate) {
    return oldDelegate.items != items ||
        oldDelegate.total != total ||
        oldDelegate.trackColor != trackColor;
  }
}


class CreateCoursePage extends StatefulWidget {
  CreateCoursePage({super.key});

  @override
  State<CreateCoursePage> createState() => _CreateCoursePageState();
}

