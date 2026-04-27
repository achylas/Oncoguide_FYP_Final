# Streamlit Breast Cancer Risk Prediction App with Random Forest and SHAP Explainability
# -----------------------------------------------------------------------------
# Requirements:
# pip install streamlit scikit-learn joblib shap pandas numpy matplotlib
#
# How to run:
# streamlit run app.py
# -----------------------------------------------------------------------------

import streamlit as st
import pandas as pd
import numpy as np
import joblib
import shap
import matplotlib.pyplot as plt

# -------------------------
# CONFIGURATION
# -------------------------
MODEL_PATH = "rf_breast_cancer.pkl"  # change to your model path

FEATURE_ORDER = [
    'age', 'menarche', 'menopause', 'agefirst', 'children', 'breastfeeding',
    'imc', 'weight', 'menopause_status', 'pregnancy', 'family_history',
    'family_history_count', 'family_history_degree', 'exercise_regular'
]

# -------------------------
# LOAD MODEL
# -------------------------
@st.cache_resource

def load_model():
    model = joblib.load(MODEL_PATH)
    return model

model = load_model()

# -------------------------
# PAGE TITLE
# -------------------------
st.title("Breast Cancer Risk Prediction System")
st.write("Enter patient clinical information to predict breast cancer risk and view explainable AI results.")

# -------------------------
# PATIENT INFO
# -------------------------
st.header("Patient Information")

patient_name = st.text_input("Patient Name")

# Age input
age = st.number_input(
    "Age",
    min_value=0,
    max_value=130,
    value=30,
    step=1
)

# Menarche age
menarche = st.number_input(
    "Age at Menarche",
    min_value=0,
    max_value=30,
    value=13,
    step=1
)

# Menopause status
menopause_status = st.selectbox(
    "Has menopause occurred?",
    options=[0, 1],
    format_func=lambda x: "Yes" if x == 1 else "No"
)

# Menopause age
if menopause_status == 1:
    menopause = st.number_input(
        "Age at Menopause",
        min_value=0,
        max_value=130,
        value=50,
        step=1
    )
else:
    menopause = 0

# Pregnancy status
pregnancy = st.selectbox(
    "Ever been pregnant?",
    options=[0, 1],
    format_func=lambda x: "Yes" if x == 1 else "No"
)

# Conditional pregnancy fields
if pregnancy == 1:
    agefirst = st.number_input(
        "Age at First Pregnancy",
        min_value=0,
        max_value=130,
        value=25,
        step=1
    )

    children = st.number_input(
        "Number of Children",
        min_value=0,
        max_value=20,
        value=1,
        step=1
    )

    breastfeeding = st.selectbox(
        "Breastfeeding History",
        options=[0, 1],
        format_func=lambda x: "Yes" if x == 1 else "No"
    )
else:
    agefirst = 0
    children = 0
    breastfeeding = 0

# BMI
imc = st.number_input(
    "BMI (Body Mass Index)",
    min_value=0.0,
    max_value=100.0,
    value=25.0,
    step=0.1
)

# Weight in kg
weight = st.number_input(
    "Weight (kg)",
    min_value=0.0,
    max_value=300.0,
    value=60.0,
    step=0.1
)

# Family history
family_history = st.selectbox(
    "Family history of breast cancer?",
    options=[0, 1],
    format_func=lambda x: "Yes" if x == 1 else "No"
)

if family_history == 1:
    family_history_count = st.number_input(
        "Number of relatives with breast cancer",
        min_value=0,
        max_value=20,
        value=1,
        step=1
    )

    family_history_degree = st.selectbox(
        "Closest relationship degree",
        options=[1, 2, 3],
        format_func=lambda x: f"Degree {x}"
    )
else:
    family_history_count = 0
    family_history_degree = 0

# Exercise
exercise_regular = st.selectbox(
    "Do you exercise more than 3 days per week?",
    options=[0, 1],
    format_func=lambda x: "Yes" if x == 1 else "No"
)

# -------------------------
# PREDICTION BUTTON
# -------------------------
if st.button("Predict Risk"):

    # Create input dictionary
    input_dict = {
        'age': age,
        'menarche': menarche,
        'menopause': menopause,
        'agefirst': agefirst,
        'children': children,
        'breastfeeding': breastfeeding,
        'imc': imc,
        'weight': weight,
        'menopause_status': menopause_status,
        'pregnancy': pregnancy,
        'family_history': family_history,
        'family_history_count': family_history_count,
        'family_history_degree': family_history_degree,
        'exercise_regular': exercise_regular
    }

    # Convert to DataFrame
    input_df = pd.DataFrame([input_dict])

    # Ensure correct order
    input_df = input_df[FEATURE_ORDER]

    # Prediction
    prediction = model.predict(input_df)[0]
    probability = model.predict_proba(input_df)[0][1]

    # Display result
    st.subheader("Prediction Result")

    if prediction == 1:
        st.error(f"High Risk of Breast Cancer (Probability: {probability:.2f})")
    else:
        st.success(f"Low Risk of Breast Cancer (Probability: {probability:.2f})")

    # -------------------------
    # SHAP EXPLAINABILITY
    # -------------------------
    # st.subheader("Explainable AI (SHAP Explanation)")

    # # Create explainer
    # explainer = shap.TreeExplainer(model)

    # # Calculate SHAP values
    # shap_values = explainer.shap_values(input_df)

    # # For binary classification, select class 1 (cancer risk)
    # expected_value = explainer.expected_value[1]
    # shap_value_single = shap_values[1][0]

    # # Waterfall plot
    # st.subheader("Model Explanation")

    # fig, ax = plt.subplots()
    # shap.waterfall_plot(
    #     expected_value,
    #     shap_value_single,
    #     input_df.iloc[0],
    #     show=False
    # )

    # st.pyplot(fig)

    # # Feature importance bar plot
    # st.subheader("Feature Impact")

    # fig2, ax2 = plt.subplots()
    # shap.summary_plot(
    #     shap_values,
    #     input_df,
    #     plot_type="bar",
    #     show=False
    # )

    # st.pyplot(fig2)

    # ============================================
    # SHAP Explainability (FIXED VERSION)
    # ============================================

    st.subheader("Explainable AI (SHAP)")

    # Create explainer once
    if "explainer" not in st.session_state:
        st.session_state.explainer = shap.Explainer(model)

    explainer = st.session_state.explainer

    # Calculate shap values
    shap_values = explainer(input_df)

    # Select positive class (cancer = 1)
    shap_value_single = shap_values[:, :, 1]

    # =========================
    # Waterfall plot
    # =========================
    st.write("Feature Impact on Prediction")

    fig1, ax1 = plt.subplots(figsize=(8,6))
    shap.plots.waterfall(shap_value_single[0], show=False)
    st.pyplot(fig1)
    plt.close(fig1)

    # =========================
    # Feature importance plot
    # =========================
    st.write("Feature Importance")

    fig2, ax2 = plt.subplots(figsize=(8,6))
    shap.plots.bar(shap_value_single, show=False)
    st.pyplot(fig2)
    plt.close(fig2)

    # =========================
    # SHAP values table
    # =========================
    st.write("SHAP Values Table")

    shap_df = pd.DataFrame({
        "Feature": input_df.columns,
        "Value": input_df.iloc[0].values,
        "Impact": shap_value_single.values[0]
    })

    st.dataframe(shap_df)

# -------------------------
# FOOTER
# -------------------------
st.write("---")
st.write("This tool provides AI‑based risk estimation and explainability using Random Forest and SHAP.")
