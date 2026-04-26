# New Patient Data Fields - Implementation Guide

## Overview
This guide helps you add the new patient data fields to your patient registration and profile forms.

---

## 🆕 New Fields to Add

### 1. Demographics Section

#### Ethnicity
```dart
// Field Type: Dropdown/Select
'ethnicity': String

// Options:
- 'Black' or 'African American'
- 'White' or 'Caucasian'
- 'Hispanic' or 'Latino'
- 'Asian'
- 'Native American'
- 'Pacific Islander'
- 'Other'
- 'Prefer not to say'

// UI Example:
DropdownButtonFormField<String>(
  decoration: InputDecoration(labelText: 'Ethnicity'),
  items: [
    DropdownMenuItem(value: 'Black', child: Text('Black/African American')),
    DropdownMenuItem(value: 'White', child: Text('White/Caucasian')),
    DropdownMenuItem(value: 'Hispanic', child: Text('Hispanic/Latino')),
    DropdownMenuItem(value: 'Asian', child: Text('Asian')),
    DropdownMenuItem(value: 'Other', child: Text('Other')),
  ],
  onChanged: (value) => setState(() => ethnicity = value),
)
```

---

### 2. Lifestyle Factors Section

#### Alcohol Consumption
```dart
// Field Type: Number Input
'alcoholDrinksPerWeek': double

// Label: "How many alcoholic drinks do you consume per week?"
// Help Text: "One drink = 12oz beer, 5oz wine, or 1.5oz spirits"
// Range: 0-50
// Default: 0

// UI Example:
TextFormField(
  decoration: InputDecoration(
    labelText: 'Alcoholic Drinks Per Week',
    helperText: 'One drink = 12oz beer, 5oz wine, or 1.5oz spirits',
  ),
  keyboardType: TextInputType.number,
  initialValue: '0',
  validator: (value) {
    final num = double.tryParse(value ?? '0');
    if (num == null || num < 0) return 'Please enter a valid number';
    return null;
  },
)
```

#### Smoking Status
```dart
// Field Type: Radio Buttons or Dropdown
'smokingStatus': int

// Options:
- 0 = Never smoked
- 1 = Former smoker (quit)
- 2 = Current smoker

// UI Example:
Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text('Smoking Status', style: TextStyle(fontWeight: FontWeight.bold)),
    RadioListTile<int>(
      title: Text('Never smoked'),
      value: 0,
      groupValue: smokingStatus,
      onChanged: (value) => setState(() => smokingStatus = value!),
    ),
    RadioListTile<int>(
      title: Text('Former smoker'),
      value: 1,
      groupValue: smokingStatus,
      onChanged: (value) => setState(() => smokingStatus = value!),
    ),
    RadioListTile<int>(
      title: Text('Current smoker'),
      value: 2,
      groupValue: smokingStatus,
      onChanged: (value) => setState(() => smokingStatus = value!),
    ),
  ],
)
```

#### Diet Type
```dart
// Field Type: Dropdown (Optional)
'dietType': String

// Options:
- 'Mediterranean'
- 'Western'
- 'Vegetarian'
- 'Vegan'
- 'Other'
- '' (empty = not specified)

// UI Example:
DropdownButtonFormField<String>(
  decoration: InputDecoration(
    labelText: 'Primary Diet Type (Optional)',
    helperText: 'Mediterranean diet may reduce breast cancer risk',
  ),
  items: [
    DropdownMenuItem(value: '', child: Text('Not specified')),
    DropdownMenuItem(value: 'Mediterranean', child: Text('Mediterranean')),
    DropdownMenuItem(value: 'Western', child: Text('Western')),
    DropdownMenuItem(value: 'Vegetarian', child: Text('Vegetarian')),
    DropdownMenuItem(value: 'Vegan', child: Text('Vegan')),
    DropdownMenuItem(value: 'Other', child: Text('Other')),
  ],
  onChanged: (value) => setState(() => dietType = value ?? ''),
)
```

---

### 3. Clinical Measurements Section

#### Vitamin D Level
```dart
// Field Type: Number Input (Optional)
'vitaminDLevel': double

// Label: "Vitamin D Level (ng/mL)"
// Help Text: "From recent blood test (optional)"
// Range: 0-100
// Default: 0 (means not tested)

// UI Example:
TextFormField(
  decoration: InputDecoration(
    labelText: 'Vitamin D Level (ng/mL)',
    helperText: 'From recent blood test (optional)',
    suffixText: 'ng/mL',
  ),
  keyboardType: TextInputType.numberWithOptions(decimal: true),
  initialValue: '',
  validator: (value) {
    if (value == null || value.isEmpty) return null; // Optional
    final num = double.tryParse(value);
    if (num == null || num < 0 || num > 100) {
      return 'Please enter a valid level (0-100)';
    }
    return null;
  },
)
```

---

### 4. Contraceptive & Hormone History Section

#### Oral Contraceptive Use
```dart
// Field Type: Yes/No Toggle + Duration
'oralContraceptiveUse': int      // 0=no, 1=yes
'oralContraceptiveYears': double // Duration in years

// UI Example:
SwitchListTile(
  title: Text('Have you used oral contraceptives?'),
  value: oralContraceptiveUse == 1,
  onChanged: (value) => setState(() {
    oralContraceptiveUse = value ? 1 : 0;
    if (!value) oralContraceptiveYears = 0;
  }),
),
if (oralContraceptiveUse == 1)
  Padding(
    padding: EdgeInsets.only(left: 16),
    child: TextFormField(
      decoration: InputDecoration(
        labelText: 'Duration of use (years)',
      ),
      keyboardType: TextInputType.number,
      initialValue: oralContraceptiveYears.toString(),
      onChanged: (value) {
        oralContraceptiveYears = double.tryParse(value) ?? 0;
      },
    ),
  ),
```

#### Hormone Replacement Therapy (HRT)
```dart
// Field Type: Yes/No Toggle + Type
'hrtUse': int    // 0=no, 1=yes
'hrtType': String // 'estrogen-only', 'combined', 'none'

// UI Example:
SwitchListTile(
  title: Text('Currently using Hormone Replacement Therapy (HRT)?'),
  subtitle: Text('For post-menopausal women'),
  value: hrtUse == 1,
  onChanged: (value) => setState(() {
    hrtUse = value ? 1 : 0;
    if (!value) hrtType = 'none';
  }),
),
if (hrtUse == 1)
  Padding(
    padding: EdgeInsets.only(left: 16),
    child: DropdownButtonFormField<String>(
      decoration: InputDecoration(labelText: 'HRT Type'),
      value: hrtType,
      items: [
        DropdownMenuItem(value: 'estrogen-only', child: Text('Estrogen Only')),
        DropdownMenuItem(value: 'combined', child: Text('Combined (Estrogen + Progestin)')),
        DropdownMenuItem(value: 'other', child: Text('Other')),
      ],
      onChanged: (value) => setState(() => hrtType = value ?? 'none'),
    ),
  ),
```

---

## 📋 Complete Form Structure Suggestion

### Recommended Form Sections:

1. **Basic Information**
   - Name, Date of Birth, Contact Info (existing)

2. **Demographics** ⭐ NEW
   - Ethnicity

3. **Physical Measurements**
   - Height, Weight, BMI (existing)

4. **Lifestyle Factors** ⭐ ENHANCED
   - Exercise (existing)
   - Alcohol consumption (NEW)
   - Smoking status (NEW)
   - Diet type (NEW - optional)

5. **Reproductive History**
   - Menarche, Menopause, Pregnancies, Breastfeeding (existing)
   - Oral contraceptive use & duration (NEW)

6. **Hormone Therapy** ⭐ NEW
   - HRT use & type

7. **Family History**
   - Family history, degree, count (existing)

8. **Clinical Measurements** ⭐ NEW
   - Vitamin D level (optional)

---

## 🔄 Updating Existing Patients

### Migration Strategy:

```dart
// When loading existing patient data, provide defaults for new fields:
Map<String, dynamic> loadPatientData(Map<String, dynamic> firestoreData) {
  return {
    // Existing fields
    ...firestoreData,
    
    // New fields with defaults
    'ethnicity': firestoreData['ethnicity'] ?? '',
    'alcoholDrinksPerWeek': firestoreData['alcoholDrinksPerWeek'] ?? 0.0,
    'smokingStatus': firestoreData['smokingStatus'] ?? 0,
    'dietType': firestoreData['dietType'] ?? '',
    'vitaminDLevel': firestoreData['vitaminDLevel'] ?? 0.0,
    'oralContraceptiveUse': firestoreData['oralContraceptiveUse'] ?? 0,
    'oralContraceptiveYears': firestoreData['oralContraceptiveYears'] ?? 0.0,
    'hrtUse': firestoreData['hrtUse'] ?? 0,
    'hrtType': firestoreData['hrtType'] ?? 'none',
  };
}
```

### Firestore Update:
- No migration needed! The recommendation engine handles missing fields gracefully
- New fields will be added when patients update their profiles
- Existing patients will get basic recommendations until they update

---

## 🎨 UI/UX Best Practices

### 1. **Progressive Disclosure**
Don't overwhelm users with all fields at once:
```dart
// Use expandable sections
ExpansionTile(
  title: Text('Lifestyle Factors'),
  children: [
    // Alcohol, smoking, diet fields here
  ],
)
```

### 2. **Help Text & Tooltips**
Explain why you're asking:
```dart
InputDecoration(
  labelText: 'Alcohol Consumption',
  helperText: 'Helps assess breast cancer risk',
  suffixIcon: IconButton(
    icon: Icon(Icons.info_outline),
    onPressed: () => showDialog(...), // Show detailed explanation
  ),
)
```

### 3. **Optional vs Required**
- **Required**: Age, ethnicity (for risk assessment)
- **Optional**: Vitamin D, diet type
- Mark optional fields clearly

### 4. **Validation**
```dart
// Reasonable ranges
- alcoholDrinksPerWeek: 0-50
- vitaminDLevel: 0-100
- oralContraceptiveYears: 0-50
```

### 5. **Privacy Notice**
Add a notice about data usage:
```dart
Card(
  child: Padding(
    padding: EdgeInsets.all(12),
    child: Row(
      children: [
        Icon(Icons.lock, color: Colors.green),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Your data is encrypted and HIPAA compliant. '
            'This information helps provide personalized recommendations.',
            style: TextStyle(fontSize: 12),
          ),
        ),
      ],
    ),
  ),
)
```

---

## 📱 Where to Add These Fields

### Files to Update:

1. **Patient Registration Form**
   - `lib/core/pages/patients/add_patient_screen.dart` (or similar)
   - Add new fields to the form

2. **Patient Profile Edit**
   - `lib/core/pages/patients/edit_patient_screen.dart` (or similar)
   - Allow updating these fields

3. **Firestore Save Function**
   - Update the save function to include new fields
   ```dart
   await FirebaseFirestore.instance
     .collection('patients')
     .doc(patientId)
     .set({
       // Existing fields...
       'ethnicity': ethnicity,
       'alcoholDrinksPerWeek': alcoholDrinksPerWeek,
       'smokingStatus': smokingStatus,
       'dietType': dietType,
       'vitaminDLevel': vitaminDLevel,
       'oralContraceptiveUse': oralContraceptiveUse,
       'oralContraceptiveYears': oralContraceptiveYears,
       'hrtUse': hrtUse,
       'hrtType': hrtType,
     }, SetOptions(merge: true));
   ```

---

## ✅ Testing Checklist

- [ ] All new fields appear in the form
- [ ] Validation works correctly
- [ ] Data saves to Firestore
- [ ] Data loads from Firestore
- [ ] Existing patients can update their profiles
- [ ] Recommendations reflect new data
- [ ] Optional fields can be left empty
- [ ] Help text is clear and helpful

---

## 📞 Need Help?

If you need assistance implementing these fields:
1. Check the existing patient form structure
2. Follow the UI examples above
3. Test with various input combinations
4. Verify recommendations are generated correctly

---

**Last Updated**: April 26, 2026
**Version**: 1.0
