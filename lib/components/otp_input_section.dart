import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OTPInputSection extends StatefulWidget {
  final String otpCode;
  final ValueChanged<String> onChanged;

  const OTPInputSection({
    super.key,
    required this.otpCode,
    required this.onChanged,
  });

  @override
  State<OTPInputSection> createState() => _OTPInputSectionState();
}

class _OTPInputSectionState extends State<OTPInputSection> {
  final FocusNode _focusNode = FocusNode();
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.text = widget.otpCode;
    _controller.addListener(() {
      final text = _controller.text;
      if (text != widget.otpCode) {
        widget.onChanged(text);
      }
    });
  }

  @override
  void didUpdateWidget(OTPInputSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.otpCode != _controller.text) {
      _controller.text = widget.otpCode;
      // Keep cursor at end
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        // Hidden TextField to capture input
        SizedBox(
          width: 0,
          height: 0,
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            // Ensure keyboard stays open
            autofocus: true,
            showCursor: false,
            enableInteractiveSelection: false,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              counterText: '',
            ),
          ),
        ),

        // Visible OTP Boxes
        GestureDetector(
          onTap: () {
            // Focus the hidden field when boxes are tapped
            FocusScope.of(context).requestFocus(_focusNode);
            // Ensure system keyboard shows up
            SystemChannels.textInput.invokeMethod('TextInput.show');
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              final digit = index < widget.otpCode.length
                  ? widget.otpCode[index]
                  : '';
              final isActive = index == widget.otpCode.length;

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isActive
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline.withOpacity(0.3),
                    width: isActive ? 2 : 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    digit,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}
