import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CheckEngineSvgIcon extends StatelessWidget {
  final double? size;
  final Color? color;

  const CheckEngineSvgIcon({super.key, this.size, this.color});

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final iconSize = size ?? iconTheme.size ?? 24.0;
    final iconColor = color ?? iconTheme.color ?? Colors.black;

    return SvgPicture.asset(
      'assets/icons/mil_check_engine.svg',
      width: iconSize,
      height: iconSize,
      fit: BoxFit.contain,
      colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
    );
  }
}
