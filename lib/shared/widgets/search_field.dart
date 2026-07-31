import 'package:flutter/material.dart';

class SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final double? width;

  const SearchField({
    super.key,
    required this.controller,
    this.labelText = 'Search',
    this.hintText = 'Type to filter...',
    this.onChanged,
    this.onClear,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        border: const OutlineInputBorder(),
        isDense: true,
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (controller.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  controller.clear();
                  if (onClear != null) {
                    onClear!();
                  } else if (onChanged != null) {
                    onChanged!('');
                  }
                },
              ),
            const Icon(Icons.search, size: 20),
          ],
        ),
      ),
    );

    if (width != null) {
      return SizedBox(width: width, child: field);
    }

    return field;
  }
}
