import 'dart:ui';
import 'package:flutter/material.dart';

class TopSearchPill extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSubmit;
  final VoidCallback onClear;
  final VoidCallback onBack;

  const TopSearchPill({
    super.key,
    required this.controller,
    required this.onSubmit,
    required this.onClear,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final showClear = controller.text.isNotEmpty;

    return Row(
      children: [
        ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Material(
              color: Colors.white.withOpacity(0.08),
              child: IconButton(
                tooltip: 'Retour',
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: TextField(
                  controller: controller,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: Colors.white70,
                  decoration: InputDecoration(
                    hintText: 'Rechercher un produit…',
                    hintStyle: const TextStyle(color: Colors.white70),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Rechercher',
                          onPressed: onSubmit,
                          icon: const Icon(Icons.search, color: Colors.white),
                        ),
                        if (showClear)
                          IconButton(
                            tooltip: 'Effacer',
                            onPressed: onClear,
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white70,
                            ),
                          ),
                      ],
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => onSubmit(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
