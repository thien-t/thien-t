import SwiftUI

struct RestPicker: View {
    var title: String = "Rest Timer"
    @Binding var seconds: Int

    var body: some View {
        Picker(title, selection: $seconds) {
            ForEach(RestOptions.values(including: seconds), id: \.self) { value in
                Text(Format.rest(value)).tag(value)
            }
        }
    }
}
