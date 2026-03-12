import SwiftUI

struct WeekdayPickerView: View {
    @Binding var selectedWeekdays: Set<Weekday>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Repeat")
                .font(.headline)

            HStack(spacing: 6) {
                ForEach(Weekday.allCases, id: \.self) { day in
                    Button(action: {
                        if selectedWeekdays.contains(day) {
                            selectedWeekdays.remove(day)
                        } else {
                            selectedWeekdays.insert(day)
                        }
                    }) {
                        Text(day.displayName)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .background(selectedWeekdays.contains(day) ? Color.blue : Color(.systemGray4))
                            .foregroundColor(selectedWeekdays.contains(day) ? .white : .primary)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
