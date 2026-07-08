//
//  MyscheduleAppWidgetBundle.swift
//  MyscheduleAppWidget
//
//  Created by Kato Mahiro on 2026/07/08.
//

import WidgetKit
import SwiftUI

@main
struct MyscheduleAppWidgetBundle: WidgetBundle {
    var body: some Widget {
        MyscheduleAppWidget()
        MyscheduleAppWidgetControl()
    }
}
