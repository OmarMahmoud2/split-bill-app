import SwiftUI
import WidgetKit

@main
struct SplitBillHomeWidgetBundle: WidgetBundle {
  var body: some Widget {
    BalanceWidget()
    ScanWidget()
    SettleWidget()
    BalanceAccessoryWidget()
  }
}
