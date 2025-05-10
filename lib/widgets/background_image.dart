import 'package:flutter/material.dart';

class BackgroundImage extends StatelessWidget {
  final Widget child;
  final String? imagePath;
  final Color? overlayColor;

  const BackgroundImage({
    super.key,
    required this.child,
    this.imagePath,
    this.overlayColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF001D54),
        image: imagePath != null
            ? DecorationImage(
                image: AssetImage(imagePath!),
                fit: BoxFit.cover,
                colorFilter: overlayColor != null
                    ? ColorFilter.mode(
                        overlayColor!.withAlpha((255 * 0.3).round()),
                        BlendMode.dstATop,
                      )
                    : null,
              )
            : null,
      ),
      child: child,
    );
  }
}
