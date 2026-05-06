"""
Register existing saved .pkl models into the MODEL_METADATA database table.
Marks RandomForest as the active model (best F1 score).
Run once: python register_models.py
"""

import sys, os, json
import mysql.connector
from mysql.connector import Error

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from etl.config import DB_CONFIG

# ── Metrics loaded from existing JSON files ─────────────────────────────────
RF_METRICS = {
    "precision": 0.9058823529411765,
    "recall":    0.7857142857142857,
    "f1_score":  0.8415300546448088,
    "roc_auc":   0.9450909725173131,
    "confusion_matrix": [[56856, 8], [21, 77]],
}
RF_HYPERPARAMS = {
    "class_weight": "balanced",
    "max_depth": None,
    "min_samples_split": 2,
    "n_estimators": 100,
}
RF_TRAINING_SAMPLES = 455904   # approximate (SMOTE-balanced)

LR_METRICS = {
    "precision": 0.05935127674258109,
    "recall":    0.8775510204081632,
    "f1_score":  0.11118293471234647,
    "roc_auc":   0.9543457788292581,
    "confusion_matrix": [[55501, 1363], [12, 86]],
}
LR_HYPERPARAMS = {"solver": "liblinear", "class_weight": "balanced"}
LR_TRAINING_SAMPLES = 455904


def register(cursor, conn, model_name, version, metrics, hyperparams, samples):
    # Remove existing entry if any (idempotent)
    cursor.execute(
        "DELETE FROM MODEL_METADATA WHERE model_name=%s AND version=%s",
        (model_name, version)
    )

    cursor.execute("""
        INSERT INTO MODEL_METADATA
            (model_name, version, metrics, hyperparameters, training_samples, is_active)
        VALUES (%s, %s, %s, %s, %s, %s)
    """, (
        model_name,
        version,
        json.dumps(metrics),
        json.dumps(hyperparams),
        samples,
        False,                         # set active below
    ))
    model_id = cursor.lastrowid
    conn.commit()
    print(f"  ✓ Inserted {model_name} v{version}  (id={model_id})")
    return model_id


def main():
    print("Connecting to MySQL …")
    try:
        conn = mysql.connector.connect(**DB_CONFIG)
    except Error as e:
        print(f"  ✗ Connection failed: {e}")
        sys.exit(1)

    cursor = conn.cursor()

    print("\nRegistering models …")
    lr_id = register(cursor, conn, "LogisticRegression", "v1.0",
                     LR_METRICS, LR_HYPERPARAMS, LR_TRAINING_SAMPLES)
    rf_id = register(cursor, conn, "RandomForest", "v1.0",
                     RF_METRICS, RF_HYPERPARAMS, RF_TRAINING_SAMPLES)

    # Mark RandomForest as the active model
    cursor.execute("UPDATE MODEL_METADATA SET is_active = 0")          # reset all
    cursor.execute("UPDATE MODEL_METADATA SET is_active = 1 WHERE model_id = %s", (rf_id,))
    conn.commit()
    print(f"\n  ✓ RandomForest (id={rf_id}) marked as ACTIVE")

    # Verify
    cursor.execute("SELECT model_id, model_name, version, is_active FROM MODEL_METADATA")
    print("\n── MODEL_METADATA ──────────────────────────────")
    for row in cursor.fetchall():
        active = "← ACTIVE" if row[3] else ""
        print(f"  id={row[0]}  {row[1]}  {row[2]}  {active}")
    print("────────────────────────────────────────────────\n")

    cursor.close()
    conn.close()
    print("Done! Restart the Flask server to pick up the active model.")


if __name__ == "__main__":
    main()
