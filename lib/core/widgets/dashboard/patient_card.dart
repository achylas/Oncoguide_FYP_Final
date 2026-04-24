import 'package:flutter/material.dart';


import '../../conts/colors.dart';
class PatientCard extends StatelessWidget {
  final String name;
  final int age;
  final String visitDate;
  final String? avatarUrl;

  const PatientCard({
    super.key,
    required this.name,
    required this.age,
    required this.visitDate,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.primary.withOpacity(0.2),
            backgroundImage:
                avatarUrl != null ? NetworkImage(avatarUrl!) : null,
            child: avatarUrl == null
                ? const Icon(Icons.person, size: 36, color: AppColors.accent)
                : null,
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 4),
              Text("Age: $age",
                  style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Text("Visit: $visitDate",
                  style: const TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}
