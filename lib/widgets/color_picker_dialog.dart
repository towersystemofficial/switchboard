import 'package:flutter/material.dart';

const List<String> presetColors = [
  '#7C83FD', '#F76E96', '#FFB562', '#5FD068',
  '#4EA5D9', '#B983FF', '#FF6B6B', '#38B6A8',
  '#F7C548', '#7286D3', '#E27396', '#8DC63F',
];

Future<String?> showColorPickerDialog(BuildContext context, String currentHex) {
  final hexController =
      TextEditingController(text: currentHex.replaceFirst('#', '').toUpperCase());

  return showDialog<String>(
    context: context,
    builder: (context) {
      String? error;
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final cleaned = hexController.text.trim().replaceFirst('#', '');
          Color? previewColor;
          if (RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(cleaned)) {
            previewColor = Color(int.parse('FF$cleaned', radix: 16));
          }

          void submitHex() {
            final c = hexController.text.trim().replaceFirst('#', '');
            if (RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(c)) {
              Navigator.of(context).pop('#${c.toUpperCase()}');
            } else {
              setDialogState(() => error = 'Enter a 6-digit hex code, like 7C83FD');
            }
          }

          return AlertDialog(
            title: const Text('Choose a color'),
            content: SizedBox(
              width: 280,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GridView.count(
                    crossAxisCount: 4,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: presetColors.map((hex) {
                      final color = Color(int.parse('FF${hex.replaceFirst('#', '')}', radix: 16));
                      final selected = hex.toUpperCase() == currentHex.toUpperCase();
                      return GestureDetector(
                        onTap: () => Navigator.of(context).pop(hex),
                        child: Container(
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: selected ? Border.all(color: Colors.black87, width: 3) : null,
                          ),
                          child: selected ? const Icon(Icons.check, color: Colors.white) : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Or enter a custom hex code:'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (previewColor != null)
                        Container(
                          width: 32,
                          height: 32,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(color: previewColor, shape: BoxShape.circle),
                        ),
                      Expanded(
                        child: TextField(
                          controller: hexController,
                          textCapitalization: TextCapitalization.characters,
                          maxLength: 7,
                          decoration: InputDecoration(
                            prefixText: '#',
                            border: const OutlineInputBorder(),
                            isDense: true,
                            counterText: '',
                            errorText: error,
                          ),
                          onChanged: (_) => setDialogState(() => error = null),
                          onSubmitted: (_) => submitHex(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
              FilledButton(onPressed: submitHex, child: const Text('Use this color')),
            ],
          );
        },
      );
    },
  );
}