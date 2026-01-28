//
//  MockData.swift
//  mole
//

import Foundation

extension DashboardMetrics {
    static let mock = DashboardMetrics(
        healthScore: 92,
        healthStatus: "Excellent",
        healthMessage: "System healthy",
        diskUsagePercent: 0.67,
        diskFreeGB: 156,
        memoryUsagePercent: 0.58,
        memoryUsedGB: 14,
        memoryTotalGB: 24,
        cacheSize: 8.4,
        cacheStatus: "Ready to clean",
        lastCleaned: "3d ago"
    )
}
