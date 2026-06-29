import 'package:flutter/material.dart';
import '../utils/constants.dart';

class CustomTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final String? errorText;
  final bool isValid;
  final VoidCallback? onPaste;
  final VoidCallback? onClear;
  final ValueChanged<String>? onChanged;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.errorText,
    this.isValid = false,
    this.onPaste,
    this.onClear,
    this.onChanged,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return TextField(
      controller: widget.controller,
      onChanged: widget.onChanged,
      style: theme.textTheme.bodyLarge,
      cursorColor: theme.colorScheme.primary,
      decoration: InputDecoration(
        hintText: widget.hintText,
        errorText: widget.errorText,
        prefixIcon: Icon(
          Icons.link_rounded,
          color: theme.hintColor,
          size: 18,
        ),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Valid/Invalid indicator
            if (widget.controller.text.isNotEmpty) ...[
              Icon(
                widget.isValid ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded,
                color: widget.isValid
                    ? AppConstants.success
                    : theme.hintColor,
                size: 18,
              ),
              const SizedBox(width: AppConstants.spaceSmall),
            ],

            // Paste button
            if (widget.controller.text.isEmpty && widget.onPaste != null)
              IconButton(
                onPressed: widget.onPaste,
                icon: const Icon(Icons.content_paste_rounded, size: 18),
                tooltip: 'Paste',
                color: theme.colorScheme.primary,
                visualDensity: VisualDensity.compact,
              ),

            // Clear button
            if (widget.controller.text.isNotEmpty && widget.onClear != null)
              IconButton(
                onPressed: widget.onClear,
                icon: const Icon(Icons.close_rounded, size: 18),
                tooltip: 'Clear',
                color: theme.textTheme.bodyMedium?.color,
                visualDensity: VisualDensity.compact,
              ),
            const SizedBox(width: AppConstants.spaceSmall),
          ],
        ),
      ),
    );
  }
}
