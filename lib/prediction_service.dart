class PredictionService {
  // Simple rule-based prediction (replace with ML model integration)
  Map<String, dynamic> predictLoanEligibility(String userId,
      double totalCredit, double totalDebit, double netBalance,
      int transactionCount) {

    double creditDebitRatio = totalCredit > 0 ? totalCredit / (totalDebit + 1) : 0;
    double avgTransactionAmount = (totalCredit + totalDebit) / (transactionCount + 1);

    int score = 0;
    List<String> reasons = [];

    // Scoring logic
    if (netBalance > 10000) {
      score += 30;
      reasons.add("Positive net balance");
    } else if (netBalance < -5000) {
      score -= 20;
      reasons.add("Negative net balance");
    }

    if (creditDebitRatio > 1.2) {
      score += 25;
      reasons.add("Good credit/debit ratio");
    } else if (creditDebitRatio < 0.8) {
      score -= 15;
      reasons.add("Poor credit/debit ratio");
    }

    if (transactionCount > 50) {
      score += 20;
      reasons.add("Sufficient transaction history");
    } else if (transactionCount < 10) {
      score -= 25;
      reasons.add("Limited transaction history");
    }

    if (avgTransactionAmount > 5000) {
      score += 15;
      reasons.add("Higher average transaction amount");
    }

    String prediction = score >= 50 ? "GOOD FOR LOAN" : "BAD FOR LOAN";
    String confidence = score >= 70 ? "HIGH" : score >= 30 ? "MEDIUM" : "LOW";

    return {
      'prediction': prediction,
      'score': score,
      'confidence': confidence,
      'reasons': reasons,
      'totalCredit': totalCredit,
      'totalDebit': totalDebit,
      'netBalance': netBalance,
      'transactionCount': transactionCount,
    };
  }
}