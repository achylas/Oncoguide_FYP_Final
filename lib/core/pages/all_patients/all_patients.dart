import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../conts/colors.dart';
import '../../widgets/resuable_top_bar.dart';
import '../history/report_detail_screen.dart';
import '../new_analysis/screens/existing_patient.dart';

class AllPatientsScreen extends StatefulWidget {
  const AllPatientsScreen({Key? key}) : super(key: key);

  @override
  State<AllPatientsScreen> createState() => _AllPatientsScreenState();
}

class _AllPatientsScreenState extends State<AllPatientsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  final List<Map<String, dynamic>> nonCancerousCategories = [
    {'name': 'Normal', 'icon': Icons.check_circle_outline, 'color': Color(0xFF4CAF50)},
    {'name': 'Benign', 'icon': Icons.healing_rounded, 'color': Color(0xFF8BC34A)},
    {'name': 'High-risk', 'icon': Icons.warning_outlined, 'color': Color(0xFFFF9800)},
    {'name': 'Under surveillance', 'icon': Icons.visibility_outlined, 'color': Color(0xFF03A9F4)},
  ];

  final List<Map<String, dynamic>> preInvasiveCategories = [
    {'name': 'DCIS (Stage 0)', 'icon': Icons.science_outlined, 'color': Color(0xFFFFA726)},
    {'name': 'LCIS', 'icon': Icons.biotech_outlined, 'color': Color(0xFFFFB74D)},
    {'name': 'Atypical hyperplasia', 'icon': Icons.emergency_outlined, 'color': Color(0xFFFF9800)},
  ];

  final List<Map<String, dynamic>> cancerStages = [
    {'name': 'Stage I', 'icon': Icons.looks_one_outlined, 'color': Color(0xFFE57373)},
    {'name': 'Stage II', 'icon': Icons.looks_two_outlined, 'color': Color(0xFFEF5350)},
    {'name': 'Stage III', 'icon': Icons.looks_3_outlined, 'color': Color(0xFFE53935)},
    {'name': 'Stage IV', 'icon': Icons.looks_4_outlined, 'color': Color(0xFFC62828)},
  ];

  final List<Map<String, dynamic>> treatmentCategories = [
    {'name': 'Under treatment', 'icon': Icons.medical_information_outlined, 'color': Color(0xFF2196F3)},
    {'name': 'Post-treatment', 'icon': Icons.check_circle_outline, 'color': Color(0xFF4CAF50)},
    {'name': 'In remission', 'icon': Icons.celebration_outlined, 'color': Color(0xFF8BC34A)},
    {'name': 'Recurrent', 'icon': Icons.replay_outlined, 'color': Color(0xFFFF9800)},
    {'name': 'Palliative', 'icon': Icons.self_improvement_outlined, 'color': Color(0xFF9C27B0)},
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: ReusableTopBar(
        title: 'Patients Management',
        subtitle: const Text('View and manage patients'),
        showBackButton: false,
        additionalActions: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.person_add_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatsSummary(),
          const SizedBox(height: 12),
          _buildMainTabs(),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPage1AllPatientsView(),
                _buildPage2CancerView(),
                _buildPage3TreatmentView(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSummary() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('patients').snapshots(),
      builder: (context, patientsSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('cancer_patients')
              .where('flaggedBy', isEqualTo: uid)
              .snapshots(),
          builder: (context, cancerSnap) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('risk_patients')
                  .where('flaggedBy', isEqualTo: uid)
                  .snapshots(),
              builder: (context, riskSnap) {
                final total   = patientsSnap.data?.docs.length ?? 0;
                final cancer  = cancerSnap.data?.docs.length ?? 0;
                final highRisk = riskSnap.data?.docs.length ?? 0;
                final active  = total - cancer;

                return Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: AppColors.getPrimaryGradient(context),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: isDark
                        ? null
                        : [
                            BoxShadow(
                              color: AppColors.accent.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                  ),
                  child: Row(
                    children: [
                      _buildStatItem('$total', 'Total', Icons.groups_rounded),
                      _buildStatDivider(),
                      _buildStatItem('$active', 'Active', Icons.local_hospital_rounded),
                      _buildStatDivider(),
                      _buildStatItem('$highRisk', 'High Risk', Icons.warning_rounded),
                      _buildStatDivider(),
                      _buildStatItem('$cancer', 'Cancer', Icons.coronavirus_rounded),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      height: 40,
      width: 1,
      color: Colors.white.withOpacity(0.3),
    );
  }

  Widget _buildMainTabs() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 50,
      decoration: BoxDecoration(
        color: AppColors.getCardBackground(context),
        borderRadius: BorderRadius.circular(12),
        border: isDark ? Border.all(color: AppColors.borderDark) : null,
        boxShadow: isDark
            ? null
            : [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.getTextSecondary(context),
        indicator: BoxDecoration(
          gradient: AppColors.getPrimaryGradient(context),
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        tabs: const [
          Tab(text: 'All Patients'),
          Tab(text: 'Cancer'),
          Tab(text: 'Treatment'),
        ],
      ),
    );
  }

  Widget _buildPage1AllPatientsView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAllPatientsCard(),
          const SizedBox(height: 24),
          _buildSectionHeader(
            'Non-Cancerous',
            Icons.favorite_outline,
            AppColors.success,
          ),
          const SizedBox(height: 12),
          _buildCategoryGrid(nonCancerousCategories, 'non-cancer'),
          const SizedBox(height: 24),
          _buildSectionHeader(
            'Pre-Invasive',
            Icons.warning_amber_rounded,
            AppColors.warning,
          ),
          const SizedBox(height: 12),
          _buildCategoryGrid(preInvasiveCategories, 'pre-invasive'),
        ],
      ),
    );
  }

  Widget _buildAllPatientsCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('patients').snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SelectPatientScreen()),
            ),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.getPrimaryGradient(context),
                borderRadius: BorderRadius.circular(16),
                boxShadow: isDark
                    ? null
                    : [
                        BoxShadow(
                          color: AppColors.accent.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.groups_rounded, color: Colors.white, size: 36),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'All Patients',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'View complete patient database',
                          style: TextStyle(fontSize: 13, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPage2CancerView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Cancer Stages',
            Icons.medical_services_rounded,
            AppColors.danger,
          ),
          const SizedBox(height: 12),
          _buildCategoryGrid(cancerStages, 'cancer'),
        ],
      ),
    );
  }

  Widget _buildPage3TreatmentView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Treatment & Outcome Status',
            Icons.medication_outlined,
            AppColors.info,
          ),
          const SizedBox(height: 12),
          _buildCategoryGrid(treatmentCategories, 'treatment'),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.getTextPrimary(context),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryGrid(List<Map<String, dynamic>> categories, String type) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    // Map category name → Firestore query
    Stream<int> _countStream(String categoryName) {
      if (type == 'cancer') {
        // cancer_patients collection — count by stage if stored, else just total
        return FirebaseFirestore.instance
            .collection('cancer_patients')
            .where('flaggedBy', isEqualTo: uid)
            .snapshots()
            .map((s) => s.docs.length);
      } else if (type == 'non-cancer') {
        if (categoryName == 'High-risk') {
          return FirebaseFirestore.instance
              .collection('risk_patients')
              .where('flaggedBy', isEqualTo: uid)
              .snapshots()
              .map((s) => s.docs.length);
        }
        // Normal/Benign/Under surveillance — count from ultrasound_reports
        return FirebaseFirestore.instance
            .collection('ultrasound_reports')
            .where('doctorId', isEqualTo: uid)
            .where('prediction', isEqualTo: categoryName)
            .snapshots()
            .map((s) => s.docs.length);
      }
      // Default: patients collection
      return FirebaseFirestore.instance
          .collection('patients')
          .snapshots()
          .map((s) => s.docs.length);
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.1,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        return StreamBuilder<int>(
          stream: _countStream(category['name'] as String),
          builder: (context, snap) {
            final count = snap.data ?? 0;
            return _buildCategoryCard(
              category['name'] as String,
              category['icon'] as IconData,
              category['color'] as Color,
              '$count',
            );
          },
        );
      },
    );
  }

  Widget _buildCategoryCard(
      String name,
      IconData icon,
      Color color,
      String count,
      ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          _showPatientList(name);
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.getCardBackground(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? color.withOpacity(0.4)
                  : color.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: isDark
                ? null
                : [
              BoxShadow(
                color: color.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(isDark ? 0.25 : 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.getTextPrimary(context),
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(isDark ? 0.3 : 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  count,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPatientList(String category) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SelectPatientScreen()),
    );
  }
}