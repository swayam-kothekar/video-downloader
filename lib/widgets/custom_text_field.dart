import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        gradient: _isFocused
            ? LinearGradient(
                colors: [
                  AppConstants.primaryPurple.withOpacity(0.1),
                  AppConstants.primaryPink.withOpacity(0.1),
                ],
              )
            : null,
        boxShadow: _isFocused
            ? [
                BoxShadow(
                  color: AppConstants.primaryPurple.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Focus(
        onFocusChange: (focused) {
          setState(() {
            _isFocused = focused;
          });
        },
        child: TextField(
          controller: widget.controller,
          onChanged: widget.onChanged,
          style: Theme.of(context).textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: widget.hintText,
            errorText: widget.errorText,
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Valid/Invalid indicator
                if (widget.controller.text.isNotEmpty)
                  Icon(
                    widget.isValid ? Icons.check_circle : Icons.error,
                    color: widget.isValid
                        ? Colors.greenAccent
                        : Colors.redAccent,
                    size: 20,
                  ),
                const SizedBox(width: 8),

                // Paste button
                if (widget.onPaste != null)
                  IconButton(
                    onPressed: widget.onPaste,
                    icon: const Icon(Icons.content_paste),
                    tooltip: 'Paste',
                    color: AppConstants.primaryPurple,
                  ),

                // Clear button
                if (widget.controller.text.isNotEmpty && widget.onClear != null)
                  IconButton(
                    onPressed: widget.onClear,
                    icon: const Icon(Icons.clear),
                    tooltip: 'Clear',
                    color: Colors.white54,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
