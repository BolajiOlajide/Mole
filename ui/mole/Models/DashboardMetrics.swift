//
//  DashboardMetrics.swift
//  mole
//

import Foundation

struct DashboardMetrics: Sendable {
    let healthScore: Int
    let healthStatus: String
    let healthMessage: String

    let diskUsagePercent: Double
    let diskFreeGB: Int

    let memoryUsagePercent: Double
    let memoryUsedGB: Int
    let memoryTotalGB: Int

    let cacheSize: Double
    let cacheStatus: String
    let lastCleaned: String
}
