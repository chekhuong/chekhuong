import WidgetKit
import SwiftUI

@main
struct TodoLockWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayTasksWidget()
        AgendaWidget()
    }
}
