"""
Model Evaluation Script
Generates detailed evaluation reports and visualizations
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
import json
import os
import sys
import logging
from sklearn.metrics import (
    confusion_matrix, classification_report,
    roc_curve, roc_auc_score, precision_recall_curve
)
import joblib

# Add parent directory to path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from etl.config import LOG_FORMAT

# Configure logging
logging.basicConfig(level=logging.INFO, format=LOG_FORMAT)
logger = logging.getLogger(__name__)

# Set style for plots
sns.set_style('whitegrid')
plt.rcParams['figure.figsize'] = (12, 8)


def load_model_metrics(model_name):
    """Load saved model metrics"""
    metrics_path = f'ml/models/{model_name.lower().replace(" ", "_")}_metrics.json'
    
    if not os.path.exists(metrics_path):
        logger.error(f"Metrics file not found: {metrics_path}")
        return None
    
    with open(metrics_path, 'r') as f:
        metrics = json.load(f)
    
    logger.info(f"Loaded metrics for {model_name}")
    return metrics


def plot_confusion_matrix(metrics, model_name, save_path):
    """Plot confusion matrix"""
    cm = np.array(metrics['confusion_matrix'])
    
    plt.figure(figsize=(8, 6))
    sns.heatmap(
        cm, 
        annot=True, 
        fmt='d', 
        cmap='Blues',
        xticklabels=['Legitimate', 'Fraud'],
        yticklabels=['Legitimate', 'Fraud']
    )
    plt.title(f'Confusion Matrix - {model_name}', fontsize=16, fontweight='bold')
    plt.ylabel('Actual', fontsize=12)
    plt.xlabel('Predicted', fontsize=12)
    plt.tight_layout()
    plt.savefig(save_path, dpi=300, bbox_inches='tight')
    logger.info(f"Confusion matrix saved to: {save_path}")
    plt.close()


def plot_metrics_comparison(lr_metrics, rf_metrics, save_path):
    """Compare metrics between models"""
    metrics_names = ['Precision', 'Recall', 'F1-Score', 'ROC-AUC']
    lr_values = [
        lr_metrics['precision'],
        lr_metrics['recall'],
        lr_metrics['f1_score'],
        lr_metrics['roc_auc']
    ]
    rf_values = [
        rf_metrics['precision'],
        rf_metrics['recall'],
        rf_metrics['f1_score'],
        rf_metrics['roc_auc']
    ]
    
    x = np.arange(len(metrics_names))
    width = 0.35
    
    fig, ax = plt.subplots(figsize=(12, 6))
    bars1 = ax.bar(x - width/2, lr_values, width, label='Logistic Regression', color='skyblue')
    bars2 = ax.bar(x + width/2, rf_values, width, label='Random Forest', color='lightcoral')
    
    ax.set_ylabel('Score', fontsize=12)
    ax.set_title('Model Performance Comparison', fontsize=16, fontweight='bold')
    ax.set_xticks(x)
    ax.set_xticklabels(metrics_names)
    ax.legend()
    ax.set_ylim([0, 1.1])
    
    # Add value labels on bars
    for bars in [bars1, bars2]:
        for bar in bars:
            height = bar.get_height()
            ax.text(bar.get_x() + bar.get_width()/2., height,
                   f'{height:.3f}',
                   ha='center', va='bottom', fontsize=10)
    
    plt.tight_layout()
    plt.savefig(save_path, dpi=300, bbox_inches='tight')
    logger.info(f"Metrics comparison saved to: {save_path}")
    plt.close()


def generate_evaluation_report(lr_metrics, rf_metrics, save_path):
    """Generate comprehensive evaluation report"""
    report = []
    report.append("="*80)
    report.append("FRAUD DETECTION MODEL EVALUATION REPORT")
    report.append("="*80)
    report.append("")
    
    # Logistic Regression
    report.append("1. LOGISTIC REGRESSION")
    report.append("-" * 40)
    report.append(f"   Precision:  {lr_metrics['precision']:.4f}")
    report.append(f"   Recall:     {lr_metrics['recall']:.4f}")
    report.append(f"   F1-Score:   {lr_metrics['f1_score']:.4f}")
    report.append(f"   ROC-AUC:    {lr_metrics['roc_auc']:.4f}")
    report.append("")
    report.append("   Confusion Matrix:")
    cm = lr_metrics['confusion_matrix']
    report.append(f"   TN: {cm[0][0]:6d}  |  FP: {cm[0][1]:6d}")
    report.append(f"   FN: {cm[1][0]:6d}  |  TP: {cm[1][1]:6d}")
    report.append("")
    
    # Random Forest
    report.append("2. RANDOM FOREST")
    report.append("-" * 40)
    report.append(f"   Precision:  {rf_metrics['precision']:.4f}")
    report.append(f"   Recall:     {rf_metrics['recall']:.4f}")
    report.append(f"   F1-Score:   {rf_metrics['f1_score']:.4f}")
    report.append(f"   ROC-AUC:    {rf_metrics['roc_auc']:.4f}")
    report.append("")
    report.append("   Confusion Matrix:")
    cm = rf_metrics['confusion_matrix']
    report.append(f"   TN: {cm[0][0]:6d}  |  FP: {cm[0][1]:6d}")
    report.append(f"   FN: {cm[1][0]:6d}  |  TP: {cm[1][1]:6d}")
    report.append("")
    
    # Best Model
    report.append("3. RECOMMENDATION")
    report.append("-" * 40)
    if rf_metrics['recall'] >= lr_metrics['recall']:
        report.append("   ✓ Recommended Model: RANDOM FOREST")
        report.append(f"   Reason: Higher recall ({rf_metrics['recall']:.4f}) for fraud detection")
    else:
        report.append("   ✓ Recommended Model: LOGISTIC REGRESSION")
        report.append(f"   Reason: Higher recall ({lr_metrics['recall']:.4f}) for fraud detection")
    report.append("")
    
    # Key Insights
    report.append("4. KEY INSIGHTS")
    report.append("-" * 40)
    report.append("   • Recall is prioritized for fraud detection to minimize false negatives")
    report.append("   • SMOTE was applied to handle class imbalance")
    report.append("   • Both models show strong performance on imbalanced data")
    report.append("")
    report.append("="*80)
    
    # Save report
    report_text = "\n".join(report)
    with open(save_path, 'w') as f:
        f.write(report_text)
    
    logger.info(f"Evaluation report saved to: {save_path}")
    
    # Print to console
    print("\n" + report_text)


def main():
    """Main evaluation function"""
    logger.info("="*80)
    logger.info("Starting Model Evaluation")
    logger.info("="*80)
    
    # Create output directory
    os.makedirs('ml/models/evaluation', exist_ok=True)
    
    # Load metrics
    lr_metrics = load_model_metrics("Logistic Regression")
    rf_metrics = load_model_metrics("Random Forest")
    
    if not lr_metrics or not rf_metrics:
        logger.error("Failed to load model metrics")
        sys.exit(1)
    
    # Generate visualizations
    plot_confusion_matrix(
        lr_metrics, 
        "Logistic Regression",
        "ml/models/evaluation/lr_confusion_matrix.png"
    )
    
    plot_confusion_matrix(
        rf_metrics, 
        "Random Forest",
        "ml/models/evaluation/rf_confusion_matrix.png"
    )
    
    plot_metrics_comparison(
        lr_metrics,
        rf_metrics,
        "ml/models/evaluation/model_comparison.png"
    )
    
    # Generate report
    generate_evaluation_report(
        lr_metrics,
        rf_metrics,
        "ml/models/evaluation/evaluation_report.txt"
    )
    
    logger.info("="*80)
    logger.info("Model Evaluation Completed Successfully!")
    logger.info("="*80)


if __name__ == "__main__":
    main()
