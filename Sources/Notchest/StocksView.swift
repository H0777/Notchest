import SwiftUI

struct StocksView: View {
    @ObservedObject var app: AppModel
    @ObservedObject var stocks: StocksModel
    var body: some View {
        VStack(spacing: 11) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(app.text("متابعة الأسهم", "Stock watchlist")).font(.system(size: 17, weight: .semibold, design: .rounded))
                    Text(app.text("آخر سعر متاح من Alpha Vantage؛ قد يكون سعر إغلاق سابق.", "Latest available from Alpha Vantage; often a previous closing price."))
                        .font(.system(size: 9)).foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                if stocks.loading { ProgressView().controlSize(.mini) }
            }
            HStack(spacing: 8) {
                SecureField(app.text("مفتاح Alpha Vantage", "Alpha Vantage API key"), text: $stocks.keyInput).textFieldStyle(.plain).font(.system(size: 11))
                Button(app.text("حفظ المفتاح", "Save key")) { stocks.saveKey() }.buttonStyle(.plain).font(.system(size: 10)).foregroundStyle(notchestAccent)
                if stocks.hasKey { Button(app.text("حذف المفتاح", "Remove key")) { stocks.removeKey() }.buttonStyle(.plain).font(.system(size: 10)).foregroundStyle(.white.opacity(0.6)) }
            }.padding(11).notchestPanel(cornerRadius: 10)
            HStack(spacing: 8) {
                TextField(app.text("رمز السهم مثل IBM", "Ticker, e.g. IBM"), text: $stocks.newSymbol).textFieldStyle(.plain).font(.system(size: 11, design: .monospaced)).onSubmit { stocks.addSymbol() }
                Button(app.text("إضافة", "Add")) { stocks.addSymbol() }.buttonStyle(.plain).font(.system(size: 10)).foregroundStyle(notchestAccent)
                if !stocks.symbols.isEmpty {
                    Picker("Ticker", selection: $stocks.selected) { ForEach(stocks.symbols, id: \.self) { Text($0).tag($0) } }.labelsHidden().frame(width: 100)
                    Button(app.text("تحديث", "Refresh")) { stocks.refresh() }.buttonStyle(.plain).font(.system(size: 10)).foregroundStyle(notchestAccent)
                    Button { stocks.remove(stocks.selected) } label: { Image(systemName: "trash") }.buttonStyle(.plain).help(app.text("إزالة الرمز", "Remove ticker"))
                }
            }.padding(11).notchestPanel(cornerRadius: 10)
            if let quote = stocks.quotes[stocks.selected] {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(quote.symbol).font(.system(size: 12, weight: .semibold))
                        Text(String(format: "%.2f", quote.price)).font(.system(size: 28, weight: .light, design: .rounded))
                        Text("\(quote.changePercent) · \(quote.tradingDate)").font(.system(size: 10)).foregroundStyle(.white.opacity(0.5))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 5) {
                        Text(app.text("تاريخ آخر جلسة", "Last trading date")).font(.system(size: 9)).foregroundStyle(.white.opacity(0.6))
                        Text(quote.tradingDate).font(.system(size: 11, design: .monospaced))
                    }
                }.environment(\.layoutDirection, .leftToRight).padding(13).notchestPanel(cornerRadius: 12)
            }
            if !stocks.selected.isEmpty {
                HStack {
                    Text(app.text("تنبيه عند التحديث", "Alert on refresh")).font(.system(size: 10))
                    TextField(app.text("السعر", "Price"), text: $stocks.alertInput).textFieldStyle(.roundedBorder).frame(width: 85)
                    Picker("Direction", selection: $stocks.alertAbove) { Text(app.text("أعلى", "Above")).tag(true); Text(app.text("أقل", "Below")).tag(false) }.labelsHidden().frame(width: 90)
                    Button(app.text("حفظ", "Save")) { stocks.setAlert() }.buttonStyle(.plain).foregroundStyle(notchestAccent).font(.system(size: 10))
                    if stocks.alerts[stocks.selected] != nil { Button(app.text("إزالة", "Remove")) { stocks.removeAlert() }.buttonStyle(.plain).font(.system(size: 10)) }
                    Spacer()
                }
            }
            if let error = stocks.error { Text(error).font(.system(size: 10)).foregroundStyle(.orange).lineLimit(3) }
            Text(app.text("المفتاح في سلسلة المفاتيح؛ يرسل التحديث الرمز والمفتاح إلى Alpha Vantage. لا توجد تحديثات تلقائية.", "Key stored in Keychain; refresh sends ticker and key to Alpha Vantage. No automatic refresh."))
                .font(.system(size: 9)).foregroundStyle(.white.opacity(0.55)).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
