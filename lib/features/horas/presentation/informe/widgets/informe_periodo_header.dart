import 'package:flutter/material.dart';

import '../../../../../core/utils/date_fmt.dart';

class InformePeriodoHeader extends StatelessWidget {
  final DateTime periodo;
  final VoidCallback onTap;

  const InformePeriodoHeader({
    super.key,
    required this.periodo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 6,
            horizontal: 10,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                DateFmt.mes(periodo),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                DateFmt.anio(periodo),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.expand_more),
            ],
          ),
        ),
      ),
    );
  }
}
