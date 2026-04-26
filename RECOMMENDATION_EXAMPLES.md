# Recommendation System - Example Outputs

## Overview
This document shows example recommendations for different patient profiles to help you understand how the system works.

---

## 📋 Example Patient Profiles

### Example 1: High-Risk Black Woman, Age 28

**Patient Data:**
```dart
{
  'age': 28,
  'ethnicity': 'Black',
  'familyHistory': 1,
  'family_history_count': 2,
  'family_history_degree': 1,
  'bmi': 24,
  'exerciseRegular': 1,
  'alcoholDrinksPerWeek': 3,
  'smokingStatus': 0,
}
```

**Expected Recommendations:**
1. 🩺 **Early Risk Assessment Recommended** (HIGH)
   - ACR 2023 guidelines recommend breast cancer risk assessment by age 25 for Black women due to 40% higher mortality rates and earlier onset.

2. 🧬 **Genetic Counseling Advised** (HIGH)
   - Family history (2 first-degree relatives with breast cancer) is your #1 risk factor. BRCA1/BRCA2 genetic testing is strongly recommended.

3. 📅 **Routine Follow-Up** (LOW)
   - Low risk profile detected. Continue annual screening per USPSTF 2024 guidelines.

---

### Example 2: Average-Risk Woman, Age 45, Density D

**Patient Data:**
```dart
{
  'age': 45,
  'ethnicity': 'White',
  'familyHistory': 0,
  'bmi': 26,
  'exerciseRegular': 1,
  'alcoholDrinksPerWeek': 5,
  'smokingStatus': 0,
  'densityAnalysis': {
    'densityIndex': 3,
    'densityClass': 'Density D (Extremely Dense)',
  },
  'tabularResult': {
    'prediction': 0, // Low risk
    'riskPercentage': 15.0,
  },
}
```

**Expected Recommendations:**
1. 📷 **Biennial Mammogram Screening** (MEDIUM)
   - At age 45, biennial (every 2 years) mammogram screening is recommended. USPSTF 2024 guidelines recommend screening every 2 years for average-risk women.

2. 🧲 **Supplemental Screening Recommended** (MEDIUM)
   - Density D (Extremely Dense) detected. Extremely dense tissue significantly reduces mammography sensitivity. Supplemental whole-breast ultrasound or contrast-enhanced MRI is recommended.

3. 💬 **Inform Patient of Dense Tissue** (MEDIUM)
   - Patients with extremely dense breasts (Density D) should be informed that mammography alone may miss up to 40% of cancers. Supplemental screening is essential.

4. 🍷 **Moderate Alcohol Intake** (MEDIUM)
   - Current alcohol consumption (5 drinks/week) is moderate. Consider reducing further as even moderate intake increases breast cancer risk.

5. 🥗 **Healthy Weight Maintenance** (LOW)
   - BMI of 26.0 is slightly above normal. Maintaining a healthy weight reduces breast cancer risk by up to 20%.

---

### Example 3: High-Risk Current Smoker, Heavy Drinker

**Patient Data:**
```dart
{
  'age': 52,
  'ethnicity': 'Hispanic',
  'familyHistory': 1,
  'family_history_count': 1,
  'bmi': 32,
  'exerciseRegular': 0,
  'alcoholDrinksPerWeek': 14, // 2 drinks per day
  'smokingStatus': 2, // Current smoker
  'vitaminDLevel': 18,
  'tabularResult': {
    'prediction': 1, // High risk
    'riskPercentage': 78.5,
  },
}
```

**Expected Recommendations:**
1. 👩‍⚕️ **Oncology Specialist Referral** (HIGH)
   - Clinical risk model indicates 78.5% breast cancer risk. Referral to oncology specialist recommended within 7 days.

2. 🧲 **Contrast-Enhanced MRI** (HIGH)
   - High risk score warrants contrast-enhanced MRI for detailed staging and to assess extent of disease. MRI is the most sensitive imaging modality for high-risk patients.

3. 🚭 **Smoking Cessation Program** (HIGH)
   - Active smoking increases breast cancer risk by 10-20% and significantly worsens treatment outcomes. Immediate referral to smoking cessation program is strongly recommended.

4. 🍷 **Reduce Alcohol Consumption** (HIGH)
   - Current alcohol intake (2.0 drinks/day) increases breast cancer risk by approximately 20%. WHO recommends limiting to <3 drinks per week.

5. 🥗 **Mediterranean Diet Consultation** (HIGH)
   - Mediterranean diet (high in vegetables, fruits, whole grains, olive oil, fish) has been shown to reduce breast cancer risk by 20-30%. Nutritionist consultation recommended.

6. 🧬 **Consider Genetic Screening** (MEDIUM)
   - Family history of breast cancer detected. Discuss BRCA genetic testing with your physician.

7. ⚖️ **Obesity Management** (MEDIUM)
   - BMI of 32.0 is in the obese range, which increases breast cancer risk. Consult a nutritionist for a structured weight loss plan.

8. 🏃‍♀️ **Start Regular Exercise** (MEDIUM)
   - No regular exercise reported. Physical activity of 150+ min/week is recommended to reduce cancer risk.

9. ☀️ **Vitamin D Supplementation** (MEDIUM)
   - Vitamin D level of 18.0 ng/mL is deficient. Studies suggest adequate vitamin D (>30 ng/mL) may reduce breast cancer risk. Discuss supplementation (1000-2000 IU daily) with your physician.

10. 👥 **Multidisciplinary Tumor Board** (MEDIUM)
    - Case should be discussed in a multidisciplinary tumor board for comprehensive treatment planning.

11. 📷 **Annual Mammogram Screening** (HIGH)
    - At age 52, annual mammogram screening is recommended. High-risk patients should undergo annual screening. Early detection significantly improves outcomes.

---

### Example 4: Post-Menopausal on HRT, High Risk

**Patient Data:**
```dart
{
  'age': 58,
  'ethnicity': 'White',
  'familyHistory': 0,
  'bmi': 28,
  'menopause_status': 1,
  'hrtUse': 1,
  'hrtType': 'combined',
  'oralContraceptiveUse': 1,
  'oralContraceptiveYears': 15,
  'exerciseRegular': 1,
  'alcoholDrinksPerWeek': 7,
  'smokingStatus': 0,
  'tabularResult': {
    'prediction': 1, // High risk
    'riskPercentage': 65.0,
  },
}
```

**Expected Recommendations:**
1. 👩‍⚕️ **Oncology Specialist Referral** (HIGH)
   - Clinical risk model indicates 65.0% breast cancer risk. Referral to oncology specialist recommended within 7 days.

2. 🧲 **Contrast-Enhanced MRI** (HIGH)
   - High risk score warrants contrast-enhanced MRI for detailed staging and to assess extent of disease. MRI is the most sensitive imaging modality for high-risk patients.

3. 💊 **Review Hormone Therapy** (HIGH)
   - Post-menopausal status with active HRT use and high risk score. Combined estrogen-progestin HRT significantly increases breast cancer risk. Discuss risks/benefits and alternatives with your physician.

4. 🍷 **Reduce Alcohol Consumption** (HIGH)
   - Current alcohol intake (1.0 drinks/day) increases breast cancer risk by approximately 10%. WHO recommends limiting to <3 drinks per week.

5. 🥗 **Mediterranean Diet Consultation** (HIGH)
   - Mediterranean diet (high in vegetables, fruits, whole grains, olive oil, fish) has been shown to reduce breast cancer risk by 20-30%. Nutritionist consultation recommended.

6. 💊 **Review Contraceptive Options** (MEDIUM)
   - Long-term oral contraceptive use (15 years) combined with high risk score. Combined oral contraceptives slightly increase breast cancer risk during use. Discuss alternative contraceptive methods with your gynecologist.

7. 👥 **Multidisciplinary Tumor Board** (MEDIUM)
   - Case should be discussed in a multidisciplinary tumor board for comprehensive treatment planning.

8. 📷 **Annual Mammogram Screening** (HIGH)
   - At age 58, annual mammogram screening is recommended. High-risk patients should undergo annual screening. Early detection significantly improves outcomes.

---

### Example 5: Malignant Ultrasound Finding

**Patient Data:**
```dart
{
  'age': 47,
  'ethnicity': 'Asian',
  'ultrasoundAnalysis': {
    'prediction': 'Malignant',
    'confidence': 92.5,
  },
  'tabularResult': {
    'prediction': 1,
    'riskPercentage': 85.0,
  },
}
```

**Expected Recommendations:**
1. 🔬 **Urgent Biopsy Required** (URGENT)
   - Ultrasound shows malignant characteristics with 93% confidence. Tissue biopsy must be performed within 48–72 hours to confirm diagnosis.

2. 🏥 **Immediate Oncology Referral** (URGENT)
   - Malignant ultrasound finding requires urgent referral to a breast oncology specialist. Do not delay beyond 48 hours.

3. 👩‍⚕️ **Oncology Specialist Referral** (HIGH)
   - Clinical risk model indicates 85.0% breast cancer risk. Referral to oncology specialist recommended within 7 days.

4. 🧲 **Contrast-Enhanced MRI** (HIGH)
   - High risk score warrants contrast-enhanced MRI for detailed staging and to assess extent of disease. MRI is the most sensitive imaging modality for high-risk patients.

5. 👥 **Multidisciplinary Tumor Board** (MEDIUM)
   - Case should be discussed in a multidisciplinary tumor board for comprehensive treatment planning.

---

### Example 6: Low-Risk, Healthy Lifestyle

**Patient Data:**
```dart
{
  'age': 42,
  'ethnicity': 'White',
  'familyHistory': 0,
  'bmi': 22,
  'exerciseRegular': 1,
  'alcoholDrinksPerWeek': 2,
  'smokingStatus': 0,
  'dietType': 'Mediterranean',
  'vitaminDLevel': 35,
  'breastfeeding': 1,
  'children': 2,
  'densityAnalysis': {
    'densityIndex': 1,
    'densityClass': 'Density B (Scattered Fibroglandular)',
  },
  'tabularResult': {
    'prediction': 0,
    'riskPercentage': 8.5,
  },
  'ultrasoundAnalysis': {
    'prediction': 'Normal',
    'confidence': 98.0,
  },
}
```

**Expected Recommendations:**
1. 📷 **Biennial Mammogram Screening** (MEDIUM)
   - At age 42, biennial (every 2 years) mammogram screening is recommended. USPSTF 2024 guidelines recommend screening every 2 years for average-risk women. Early detection significantly improves outcomes.

2. ✅ **Protective Factors Noted** (LOW)
   - Breastfeeding history is a protective factor against breast cancer. Continue routine preventive care and annual check-ups.

3. ✅ **Favorable Tissue Density** (LOW)
   - Density B (Scattered Fibroglandular) — mammography has high sensitivity for this tissue type. Standard screening schedule (biennial for average risk, annual for high risk) is appropriate.

4. 📅 **Routine Follow-Up** (LOW)
   - Low risk profile detected. Continue biennial (every 2 years) screening per USPSTF 2024 guidelines. Contact physician immediately if new symptoms arise (lump, skin changes, nipple discharge, pain).

---

## 🎯 Key Patterns to Notice

### Priority Escalation:
- **Malignant findings** → URGENT (48-72 hours)
- **High risk + modifiable factors** → HIGH (7 days)
- **Moderate risk or preventive** → MEDIUM (1-3 months)
- **Low risk or routine** → LOW (routine care)

### Personalization:
- Recommendations reference specific patient values (BMI, age, alcohol intake)
- SHAP values identify top risk factors
- Multiple modifiable factors trigger multiple recommendations

### Clinical Accuracy:
- All recommendations cite guidelines (USPSTF 2024, ACR 2024, WHO)
- Specific timeframes for follow-up
- Evidence-based risk percentages

### Actionability:
- Each recommendation has a clear action (referral, test, lifestyle change)
- Specific targets (e.g., "reduce to <3 drinks/week", "target vitamin D >30 ng/mL")
- Provider-focused language for clinical recommendations

---

## 🧪 Testing Your Implementation

Use these test cases to verify your recommendation system:

1. **Create test patients** with the profiles above
2. **Generate reports** for each patient
3. **Verify recommendations** match the expected outputs
4. **Check priority sorting** (urgent → high → medium → low)
5. **Test edge cases** (missing fields, extreme values)

---

**Last Updated**: April 26, 2026
**Version**: 1.0
