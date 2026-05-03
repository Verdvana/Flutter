//
//  FetalMovementWidgetBundle.swift
//  FetalMovementWidget
//
//  Created by VERDVANA on 2026/5/1.
//

import WidgetKit
import SwiftUI

@main
struct FetalMovementWidgetBundle: WidgetBundle {
    var body: some Widget {
        FetalMovementWidget()
        // FetalMovementWidgetControl() // 暂时注释掉，避免某些系统版本由于 ControlWidget 报错导致整个复杂表盘扩展失效
    }
}
