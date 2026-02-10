// Fraud Detection System - Frontend JavaScript

// API Base URL
const API_BASE_URL = window.location.origin;

// Sample transaction data for testing
const SAMPLE_DATA = {
    time: 94813,
    amount: 149.62,
    V1: -1.359807,
    V2: -0.072781,
    V3: 2.536347,
    V4: 1.378155,
    V5: -0.338321,
    V6: 0.462388,
    V7: 0.239599,
    V8: 0.098698,
    V9: 0.363787,
    V10: 0.090794,
    V11: -0.551600,
    V12: -0.617801,
    V13: -0.991390,
    V14: -0.311169,
    V15: 1.468177,
    V16: -0.470401,
    V17: 0.207971,
    V18: 0.025791,
    V19: 0.403993,
    V20: 0.251412,
    V21: -0.018307,
    V22: 0.277838,
    V23: -0.110474,
    V24: 0.066928,
    V25: 0.128539,
    V26: -0.189115,
    V27: 0.133558,
    V28: -0.021053
};

// Initialize PCA feature inputs on page load
document.addEventListener('DOMContentLoaded', function() {
    initializePCAFeatures();
    
    // Attach event listeners
    const predictionForm = document.getElementById('predictionForm');
    if (predictionForm) {
        predictionForm.addEventListener('submit', handlePredictionSubmit);
    }
    
    const fillSampleBtn = document.getElementById('fillSampleBtn');
    if (fillSampleBtn) {
        fillSampleBtn.addEventListener('click', fillSampleData);
    }
});

// Initialize PCA feature input fields
function initializePCAFeatures() {
    const col1 = document.getElementById('pcaFeaturesCol1');
    const col2 = document.getElementById('pcaFeaturesCol2');
    
    if (!col1 || !col2) return;
    
    for (let i = 1; i <= 28; i++) {
        const formGroup = document.createElement('div');
        formGroup.className = 'mb-2';
        formGroup.innerHTML = `
            <label for="V${i}" class="form-label">V${i}</label>
            <input type="number" step="any" class="form-control form-control-sm" 
                   id="V${i}" name="V${i}" value="0" required>
        `;
        
        if (i <= 14) {
            col1.appendChild(formGroup);
        } else {
            col2.appendChild(formGroup);
        }
    }
}

// Fill form with sample data
function fillSampleData() {
    document.getElementById('time').value = SAMPLE_DATA.time;
    document.getElementById('amount').value = SAMPLE_DATA.amount;
    
    for (let i = 1; i <= 28; i++) {
        const input = document.getElementById(`V${i}`);
        if (input) {
            input.value = SAMPLE_DATA[`V${i}`];
        }
    }
    
    // Show PCA features section
    const pcaCollapse = new bootstrap.Collapse(document.getElementById('pcaFeatures'), {
        show: true
    });
}

// Handle prediction form submission
async function handlePredictionSubmit(event) {
    event.preventDefault();
    
    const submitBtn = event.target.querySelector('button[type="submit"]');
    const originalBtnText = submitBtn.innerHTML;
    
    // Show loading state
    submitBtn.disabled = true;
    submitBtn.innerHTML = '<span class="spinner-border spinner-border-sm me-2"></span>Predicting...';
    
    try {
        // Collect form data
        const formData = new FormData(event.target);
        const data = {};
        
        for (let [key, value] of formData.entries()) {
            data[key] = parseFloat(value);
        }
        
        // Make API request
        const response = await fetch(`${API_BASE_URL}/predict`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(data)
        });
        
        const result = await response.json();
        
        if (result.success) {
            displayPredictionResult(result.prediction);
        } else {
            showError(result.error || 'Prediction failed');
        }
        
    } catch (error) {
        console.error('Prediction error:', error);
        showError('Failed to connect to server');
    } finally {
        // Restore button state
        submitBtn.disabled = false;
        submitBtn.innerHTML = originalBtnText;
    }
}

// Display prediction result
function displayPredictionResult(prediction) {
    const resultCard = document.getElementById('resultCard');
    const infoCard = document.getElementById('infoCard');
    const resultHeader = document.getElementById('resultHeader');
    const resultIcon = document.getElementById('resultIcon');
    const resultText = document.getElementById('resultText');
    const fraudProbability = document.getElementById('fraudProbability');
    const riskLevel = document.getElementById('riskLevel');
    const probabilityBar = document.getElementById('probabilityBar');
    
    // Hide info card, show result card
    if (infoCard) infoCard.style.display = 'none';
    resultCard.style.display = 'block';
    resultCard.classList.add('fade-in');
    
    // Set result based on fraud status
    if (prediction.is_fraud) {
        resultCard.className = 'card shadow-lg fraud';
        resultHeader.className = 'card-header text-white fraud';
        resultIcon.innerHTML = '<i class="bi bi-exclamation-triangle-fill text-danger"></i>';
        resultText.innerHTML = '<span class="text-danger">⚠️ FRAUD DETECTED</span>';
    } else {
        resultCard.className = 'card shadow-lg legitimate';
        resultHeader.className = 'card-header text-white legitimate';
        resultIcon.innerHTML = '<i class="bi bi-check-circle-fill text-success"></i>';
        resultText.innerHTML = '<span class="text-success">✓ LEGITIMATE</span>';
    }
    
    // Set probability
    const probability = (prediction.fraud_probability * 100).toFixed(2);
    fraudProbability.textContent = `${probability}%`;
    
    // Set risk level with color
    const riskLevelText = prediction.risk_level.toUpperCase();
    riskLevel.innerHTML = `<span class="risk-${prediction.risk_level}">${riskLevelText}</span>`;
    
    // Update progress bar
    probabilityBar.style.width = `${probability}%`;
    probabilityBar.textContent = `${probability}%`;
    probabilityBar.setAttribute('aria-valuenow', probability);
    
    // Set progress bar color based on risk
    probabilityBar.className = 'progress-bar';
    if (prediction.risk_level === 'low') {
        probabilityBar.classList.add('bg-success');
    } else if (prediction.risk_level === 'medium') {
        probabilityBar.classList.add('bg-warning');
    } else {
        probabilityBar.classList.add('bg-danger');
    }
    
    // Scroll to result
    resultCard.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
}

// Show error message
function showError(message) {
    alert(`Error: ${message}`);
}

// Dashboard Functions
async function loadDashboardData() {
    try {
        const response = await fetch(`${API_BASE_URL}/dashboard`);
        const result = await response.json();
        
        if (result.success) {
            updateDashboardUI(result.data);
        } else {
            console.error('Failed to load dashboard data:', result.error);
        }
    } catch (error) {
        console.error('Dashboard error:', error);
    }
}

// Update dashboard UI with data
function updateDashboardUI(data) {
    // Update overview cards
    document.getElementById('totalTransactions').textContent = 
        data.overview.total_transactions.toLocaleString();
    document.getElementById('totalFraud').textContent = 
        data.overview.total_fraud.toLocaleString();
    document.getElementById('fraudRate').textContent = 
        data.overview.fraud_percentage.toFixed(4) + '%';
    document.getElementById('totalPredictions').textContent = 
        data.overview.total_predictions.toLocaleString();
    
    // Update active model info
    if (data.overview.active_model) {
        const modelInfo = data.overview.active_model;
        document.getElementById('activeModelInfo').innerHTML = `
            <div class="row">
                <div class="col-md-4">
                    <strong>Model Name:</strong> ${modelInfo.model_name}
                </div>
                <div class="col-md-4">
                    <strong>Version:</strong> ${modelInfo.version}
                </div>
                <div class="col-md-4">
                    <strong>Trained At:</strong> ${new Date(modelInfo.trained_at).toLocaleString()}
                </div>
            </div>
        `;
    }
    
    // Update model performance table
    updateModelPerformanceTable(data.model_performance);
    
    // Update recent predictions table
    updateRecentPredictionsTable(data.recent_predictions);
    
    // Create charts
    createFraudDistributionChart(data.overview);
    createFraudByAmountChart(data.fraud_by_amount);
}

// Update model performance table
function updateModelPerformanceTable(models) {
    const tbody = document.querySelector('#modelPerformanceTable tbody');
    tbody.innerHTML = '';
    
    models.forEach(model => {
        const row = document.createElement('tr');
        row.innerHTML = `
            <td><strong>${model.model_name}</strong> <small class="text-muted">v${model.version}</small></td>
            <td>${model.precision_pct}%</td>
            <td><span class="badge bg-success">${model.recall_pct}%</span></td>
            <td>${model.accuracy_pct}%</td>
        `;
        tbody.appendChild(row);
    });
}

// Update recent predictions table
function updateRecentPredictionsTable(predictions) {
    const tbody = document.querySelector('#recentPredictionsTable tbody');
    tbody.innerHTML = '';
    
    predictions.slice(0, 10).forEach(pred => {
        const row = document.createElement('tr');
        const resultBadge = pred.prediction_result === 'Correct' 
            ? '<span class="badge bg-success">✓</span>' 
            : '<span class="badge bg-danger">✗</span>';
        
        const predictedBadge = pred.predicted_class 
            ? '<span class="badge bg-danger">Fraud</span>' 
            : '<span class="badge bg-success">Legit</span>';
        
        row.innerHTML = `
            <td>${pred.transaction_id}</td>
            <td>$${pred.amount.toFixed(2)}</td>
            <td>${predictedBadge}</td>
            <td>${pred.fraud_probability_pct}%</td>
            <td>${resultBadge}</td>
        `;
        tbody.appendChild(row);
    });
}

// Create fraud distribution pie chart
function createFraudDistributionChart(overview) {
    const ctx = document.getElementById('fraudDistributionChart');
    if (!ctx) return;
    
    new Chart(ctx, {
        type: 'pie',
        data: {
            labels: ['Legitimate', 'Fraud'],
            datasets: [{
                data: [
                    overview.total_transactions - overview.total_fraud,
                    overview.total_fraud
                ],
                backgroundColor: ['#198754', '#dc3545'],
                borderWidth: 2,
                borderColor: '#fff'
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: true,
            plugins: {
                legend: {
                    position: 'bottom'
                },
                title: {
                    display: false
                }
            }
        }
    });
}

// Create fraud by amount bar chart
function createFraudByAmountChart(fraudByAmount) {
    const ctx = document.getElementById('fraudByAmountChart');
    if (!ctx) return;
    
    const labels = fraudByAmount.map(item => item.amount_range);
    const fraudCounts = fraudByAmount.map(item => item.fraud_count);
    const totalCounts = fraudByAmount.map(item => item.transaction_count);
    
    new Chart(ctx, {
        type: 'bar',
        data: {
            labels: labels,
            datasets: [
                {
                    label: 'Fraud',
                    data: fraudCounts,
                    backgroundColor: '#dc3545',
                    borderWidth: 1
                },
                {
                    label: 'Legitimate',
                    data: totalCounts.map((total, i) => total - fraudCounts[i]),
                    backgroundColor: '#198754',
                    borderWidth: 1
                }
            ]
        },
        options: {
            responsive: true,
            maintainAspectRatio: true,
            scales: {
                x: {
                    stacked: true,
                    title: {
                        display: true,
                        text: 'Amount Range ($)'
                    }
                },
                y: {
                    stacked: true,
                    title: {
                        display: true,
                        text: 'Transaction Count'
                    }
                }
            },
            plugins: {
                legend: {
                    position: 'bottom'
                }
            }
        }
    });
}
