import 'package:flutter/material.dart';
import '../../conts/colors.dart';

class AppSliderField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final double min;
  final double max;
  final String unit;

  const AppSliderField(
      {super.key,
      required this.label,
      required this.controller,
      required this.min,
      required this.max,
      required this.unit});

  @override
  State<AppSliderField> createState() => _AppSliderFieldState();
}

class _AppSliderFieldState extends State<AppSliderField> {
  late double value;

  @override
  void initState() {
    super.initState();
    value = widget.controller.text.isEmpty
        ? widget.min
        : double.parse(widget.controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${widget.label}: ${value.toInt()} ${widget.unit}'),
        Slider(
          min: widget.min,
          max: widget.max,
          value: value,
          onChanged: (val) {
            setState(() => value = val);
            widget.controller.text = val.toInt().toString();
          },
          activeColor: AppColors.accent,
          inactiveColor: Colors.grey[300],
        ),
      ],
    );
  }
}
