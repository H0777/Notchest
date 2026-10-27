import SwiftUI

struct WeatherView: View {
    @ObservedObject var app: AppModel
    @ObservedObject var weather: WeatherModel
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(app.text("طقس مدينتك", "Weather, where you are"))
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                    Text(app.text("اختر مدينة؛ تُرسل إلى Open-Meteo لجلب الطقس.", "Choose a city; it is sent to Open-Meteo for forecasts."))
                        .font(.system(size: 9)).foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                if weather.loading { ProgressView().controlSize(.mini) }
                if weather.selected != nil {
                    Button { weather.refresh() } label: { Image(systemName: "arrow.clockwise") }.buttonStyle(.plain).help(app.text("تحديث الطقس", "Refresh weather"))
                }
            }
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(notchestAccent)
                TextField(app.text("اسم المدينة…", "City name…"), text: $weather.query).textFieldStyle(.plain)
                    .font(.system(size: 12)).onSubmit { weather.search() }
                Button(app.text("بحث", "Search")) { weather.search() }.buttonStyle(.plain).foregroundStyle(notchestAccent).font(.system(size: 11))
            }.padding(12).notchestPanel(cornerRadius: 11)
            if !weather.candidates.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(weather.candidates) { city in
                            Button { weather.choose(city) } label: {
                                HStack { Image(systemName: "mappin").foregroundStyle(notchestAccent); Text(city.label).font(.system(size: 11)); Spacer() }
                                    .padding(10).notchestPanel(cornerRadius: 9)
                            }.buttonStyle(.plain)
                        }
                    }
                }
            } else if let reading = weather.reading, let city = weather.selected {
                HStack(spacing: 18) {
                    Image(systemName: WeatherModel.symbol(code: reading.weather_code, isDay: reading.is_day == 1))
                        .font(.system(size: 40)).foregroundStyle(notchestAccent)
                    VStack(alignment: .leading, spacing: 7) {
                        Text(city.label).font(.system(size: 13, weight: .medium)).lineLimit(1)
                        Text("\(Int(reading.temperature_2m.rounded()))°C").font(.system(size: 34, weight: .light, design: .rounded)).environment(\.layoutDirection, .leftToRight)
                        Text(app.text("المحسوسة \(Int(reading.apparent_temperature.rounded()))° • الرياح \(Int(reading.wind_speed_10m.rounded())) كم/س", "Feels \(Int(reading.apparent_temperature.rounded()))° • wind \(Int(reading.wind_speed_10m.rounded())) km/h"))
                            .font(.system(size: 10)).foregroundStyle(.white.opacity(0.65))
                        Text("Open-Meteo · \(reading.time.replacingOccurrences(of: "T", with: " "))")
                            .font(.system(size: 9)).foregroundStyle(.white.opacity(0.3)).environment(\.layoutDirection, .leftToRight)
                    }
                    Spacer()
                    Button { weather.clearCity() } label: { Image(systemName: "xmark") }.buttonStyle(.plain).help(app.text("إزالة المدينة", "Remove city"))
                }.padding(18).frame(maxWidth: .infinity, alignment: .leading).notchestPanel(cornerRadius: 16)
                Text(app.text("يُحدّث الطقس كل 30 دقيقة بعد اختيار المدينة.", "Weather refreshes every 30 minutes after choosing a city."))
                    .font(.system(size: 9)).foregroundStyle(.white.opacity(0.55))
            } else if !weather.loading {
                Text(app.text("ابحث عن مدينة للبدء.", "Search for a city to begin."))
                    .font(.system(size: 12)).foregroundStyle(.white.opacity(0.6)).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            if let error = weather.error { Text(error).font(.system(size: 10)).foregroundStyle(.orange).lineLimit(3) }
        }
    }
}
