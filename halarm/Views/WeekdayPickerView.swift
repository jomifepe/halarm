import SwiftUI

struct WeekdayPickerView: View {
    @Binding var selectedWeekdays: Set<Weekday>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Days")
                .font(.headline)

            HStack(spacing: 8) {
                ForEach(Weekday.allCases, id: \.self) { day in
                    Button(action: {
                        if selectedWeekdays.contains(day) {
                            selectedWeekdays.remove(day)
                        } else {
                            selectedWeekdays.insert(day)
                        }
                    }) {
                        Text(day.displayName)
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                            .padding(8)
                            .background(selectedWeekdays.contains(day) ? Color.blue : Color(.systemGray5))
                            .foregroundColor(selectedWeekdays.contains(day) ? .white : .primary)
                            .cornerRadius(6)
                    }
                }
            }
        }
    }
}
