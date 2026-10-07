import SwiftUI

struct PlanItem: Identifiable, Codable {
    var id = UUID()
    let task: String
    let date: Date
    let startTime: Int
    let endTime: Int
    let priority: Int
}

// test data, shown when the server can't be reached
let samplePlans = [
    PlanItem(
        task: "운영체제 과제",
        date: Date(),
        startTime: 20 * 60,
        endTime: 22 * 60 + 10,
        priority: 3
    ),
    PlanItem(
        task: "소프트웨어공학 과제",
        date: Date(),
        startTime: 21 * 60,
        endTime: 22 * 60 + 30,
        priority: 2
    ),
    PlanItem(
        task: "컴퓨터네트워크 복습",
        date: Date(),
        startTime: 19 * 60,
        endTime: 21 * 60 + 55,
        priority: 1
    ),
    PlanItem(
        task: "알고리즘 분석",
        date: Date(),
        startTime: 22 * 60,
        endTime: 23 * 60,
        priority: 3
    ),
    PlanItem(
        task: "머신러닝 공부",
        date: Date(),
        startTime: 23 * 60,
        endTime: 23 * 60 + 50,
        priority: 2
    ),
    PlanItem(
        task: "운동",
        date: Date(),
        startTime: 16 * 60,
        endTime: 19 * 60,
        priority: 1
    )
]

// Server address. In the Simulator, 127.0.0.1 (localhost) is your Mac.
// On a real iPhone, use your Mac's IP address instead (e.g. http://192.168.0.12:8000).
let serverURL = URL(string: "http://127.0.0.1:8000")!

// JSON from the server uses snake_case keys and "yyyy-MM-dd" dates
let planDecoder: JSONDecoder = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    decoder.dateDecodingStrategy = .formatted(formatter)
    return decoder
}()

func fetchPlans(for date: Date) async throws -> [PlanItem] {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.locale = Locale(identifier: "en_US_POSIX")

    var components = URLComponents(
        url: serverURL.appendingPathComponent("plans"),
        resolvingAgainstBaseURL: false
    )!

    components.queryItems = [
        URLQueryItem(
            name: "date",
            value: formatter.string(from: date)
        )
    ]

    let (data, _) = try await URLSession.shared.data(
        from: components.url!
    )

    return try planDecoder.decode(
        [PlanItem].self,
        from: data
    )
}


// 새 일정 추가
func createPlan(_ plan: PlanItem) async throws -> PlanItem {
    let url = serverURL.appendingPathComponent("plans")

    var request = URLRequest(url: url)
    request.httpMethod = "POST"

    request.setValue(
        "application/json",
        forHTTPHeaderField: "Content-Type"
    )

    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase

    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.locale = Locale(identifier: "en_US_POSIX")

    encoder.dateEncodingStrategy = .formatted(formatter)

    request.httpBody = try encoder.encode(plan)

    let (data, response) = try await URLSession.shared.data(
        for: request
    )

    guard let httpResponse = response as? HTTPURLResponse,
          (200...299).contains(httpResponse.statusCode)
    else {
        throw URLError(.badServerResponse)
    }

    return try planDecoder.decode(
        PlanItem.self,
        from: data
    )
}


// 기존 일정 수정
func updatePlan(_ plan: PlanItem) async throws -> PlanItem {
    let url = serverURL
        .appendingPathComponent("plans")
        .appendingPathComponent(plan.id.uuidString)

    var request = URLRequest(url: url)
    request.httpMethod = "PUT"

    request.setValue(
        "application/json",
        forHTTPHeaderField: "Content-Type"
    )

    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase

    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.locale = Locale(identifier: "en_US_POSIX")

    encoder.dateEncodingStrategy = .formatted(formatter)

    request.httpBody = try encoder.encode(plan)

    let (data, response) = try await URLSession.shared.data(
        for: request
    )

    guard let httpResponse = response as? HTTPURLResponse,
          (200...299).contains(httpResponse.statusCode)
    else {
        throw URLError(.badServerResponse)
    }

    return try planDecoder.decode(
        PlanItem.self,
        from: data
    )
}


// 일정 삭제
func deletePlan(_ plan: PlanItem) async throws {
    let url = serverURL
        .appendingPathComponent("plans")
        .appendingPathComponent(plan.id.uuidString)

    var request = URLRequest(url: url)
    request.httpMethod = "DELETE"

    let (_, response) = try await URLSession.shared.data(
        for: request
    )

    guard let httpResponse = response as? HTTPURLResponse,
          (200...299).contains(httpResponse.statusCode)
    else {
        throw URLError(.badServerResponse)
    }
}

func fetchAllPlans() async throws -> [PlanItem] {
    let url = serverURL.appendingPathComponent("plans")

    let (data, _) = try await URLSession.shared.data(
        from: url
    )

    return try planDecoder.decode(
        [PlanItem].self,
        from: data
    )
}
//automatically sorted

struct ContentView: View {
    @State private var page = 0
    // 0 = main
    // 1 = planning

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                MainView()
                    .tag(0)

                PlanningView()
                    .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            BottomPageBar(page: $page)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }
}

struct MainView: View {
    @State private var scrollPosition = ScrollPosition()
    @State private var plans: [PlanItem] = samplePlans
    @State private var serverStatus = "Connecting to server..."
    
    var day: String {
        let month = Calendar.current.component(.month, from: Date())
        let day = Calendar.current.component(.day, from: Date())
        let week = Calendar.current.component(.weekday, from: Date())
        
        let weekdays = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
        
        return "\(month). \(day) \(weekdays[week-1])"
    }
    
    var weekend: Color {
        let week = Calendar.current.component(.weekday, from: Date())
        if week == 1 {
            return Color.red
        }
        else if week == 7 {
            return Color.blue
        }
        return Color.black
    }

    var body: some View {
        VStack(spacing: 12) {

            Text(day)
                .font(.system(size: 42, weight: .bold))
                .foregroundStyle(weekend)

            Text("today's plan")
                .foregroundColor(.secondary)

            // shows whether plans came from the server or the sample data
            Text(serverStatus)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            TimelineView(.periodic(from: .now, by: 60)) { context in
                
                let currentTime =
                    Calendar.current.component(.hour, from: context.date) * 60 +
                    Calendar.current.component(.minute, from: context.date)
                
                let currentList = plans
                    .filter {
                        Calendar.current.isDateInToday($0.date)
                    }
                    .filter {
                        $0.endTime > currentTime
                    }
                    .filter {
                        $0.startTime <= currentTime
                    }

                ScrollView(.vertical, showsIndicators: false) {

                    LazyVStack(spacing: 12) {

                        ForEach(
                            plans
                                .filter {
                                    Calendar.current.isDateInToday($0.date)
                                }
                                .filter {
                                    $0.endTime > currentTime
                                }
                                .sorted {

                                    let remaining1 = $0.endTime - currentTime
                                    let remaining2 = $1.endTime - currentTime

                                    let isUpcoming1 = currentTime < $0.startTime
                                    let isUpcoming2 = currentTime < $1.startTime

                                    // 진행 중인 일정 먼저
                                    if isUpcoming1 != isUpcoming2 {
                                        return !isUpcoming1
                                    }

                                    // 둘 다 예정이면 시작 시간 순
                                    if isUpcoming1 && isUpcoming2 {
                                        return $0.startTime < $1.startTime
                                    }

                                    // 둘 다 진행 중이면 남은 시간 순
                                    if remaining1 != remaining2 {
                                        return remaining1 < remaining2
                                    }

                                    // 남은 시간이 같으면 priority 순
                                    if $0.priority != $1.priority {
                                        return $0.priority > $1.priority
                                    }

                                    return $0.startTime < $1.startTime
                                }
                        ) { plan in

                            TaskCard(
                                Item: plan,
                                currentTime: currentTime
                            )
                            .scrollTransition(.interactive, axis: .vertical) {
                                content, phase in

                                content
                                    .opacity(
                                        phase.isIdentity ? 1.0 : 0.25
                                    )
                                    .scaleEffect(
                                        phase.isIdentity ? 1.0 : 0.82
                                    )
                            }
                            .id(plan.id)
                        }

                        .padding(.horizontal, 24)
                    }
                }
                .frame(height: 258)
                .scrollPosition($scrollPosition)
                // 시계
                AnalogClock(
                    date: context.date,
                    currentList: currentList
                )
            }
            

            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .task {
            // reload every 1 seconds so new plans show up without restarting
            while !Task.isCancelled {
                await loadPlans(for: Date())
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func loadPlans(for date: Date) async {
        do {
            plans = try await fetchPlans(for: date)
            serverStatus = "Server: \(plans.count) plan(s) loaded"
        } catch {
            serverStatus = "Server error: \(error)"
        }
    }
}

struct ClockSector: Shape {
    let startAngle: Double
    let endAngle: Double

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(
            x: rect.midX,
            y: rect.midY
        )

        let radius = min(rect.width, rect.height) / 2

        var path = Path()

        path.move(to: center)

        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(startAngle - 90),
            endAngle: .degrees(endAngle - 90),
            clockwise: false
        )

        path.closeSubpath()

        return path
    }
}

struct AnalogClock: View {

    let date: Date
    let currentList: [PlanItem]

    var body: some View {

        let calendar = Calendar.current

        let hour =
            Double(calendar.component(.hour, from: date) % 12)

        let minute =
            Double(calendar.component(.minute, from: date))

        let hourAngle =
            (hour + minute / 60) * 30

        let minuteAngle =
            minute * 6

        let currentTime =
            calendar.component(.hour, from: date) * 60 +
            calendar.component(.minute, from: date)




        ZStack {

            // 시계판
            Circle()
                .fill(Color(white: 0.98))
            
            ForEach(currentList) { plan in
                let remaining = plan.endTime - currentTime

                if remaining >= 60 {
                    Circle()
                        .fill(Color.black.opacity(0.15))
                } else if remaining > 0 {
                    ClockSector(
                        startAngle: minuteAngle,
                        endAngle: minuteAngle + Double(remaining) * 6
                    )
                    .fill(Color.black.opacity(0.05))
                }
            }

            // 시침
            Rectangle()
                .fill(Color.black)
                .frame(width: 5, height: 80)
                .offset(y: -40)
                .rotationEffect(.degrees(hourAngle))

            // 분침
            Rectangle()
                .fill(Color.black)
                .frame(width: 3, height: 150)
                .offset(y: -75)
                .rotationEffect(.degrees(minuteAngle))


        }
        .frame(width: 300, height: 300)
    }
}


struct PlanningView: View {
    @State private var selectedPage = 0

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selectedPage) {
                CalendarPage()
                    .tag(0)

                AllPlansPage()
                    .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack {
                Button("CALENDAR") {
                    selectedPage = 0
                }
                .frame(maxWidth: .infinity)

                Button("ALL PLANS") {
                    selectedPage = 1
                }
                .frame(maxWidth: .infinity)
            }
            .frame(height: 56)
        }
    }
}


struct CalendarPage: View {
    @State private var plans: [PlanItem] = []
    @State private var currentMonth = Date()
    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @State private var showingCreateSheet = false
    @State private var selectedPlan: PlanItem?

    private let calendar = Calendar.current
    private let columns = Array(
        repeating: GridItem(.flexible()),
        count: 7
    )

    var body: some View {
        VStack(spacing: 20) {
            Text("CALENDAR")
                .font(.largeTitle.bold())

            HStack {
                Button {
                    changeMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                }

                Spacer()

                Text(currentMonth.formatted(
                    .dateTime.year().month()
                ))
                .font(.title2.bold())

                Spacer()

                Button {
                    changeMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
            }

            LazyVGrid(columns: columns, spacing: 12) {

                ForEach(Array(daysInMonth().enumerated()), id: \.offset) { _, date in
                    if let date {
                        let isSelected = calendar.isDate(
                            date,
                            inSameDayAs: selectedDate
                        )

                        Button {
                            selectedDate = date

                            Task {
                                await loadPlans(for: date)
                            }
                        } label: {
                            Text("\(calendar.component(.day, from: date))")
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                                .background(
                                    isSelected ? Color.blue : Color.clear
                                )
                                .foregroundStyle(
                                    isSelected ? Color.white : Color.primary
                                )
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    } else {
                        Color.clear
                            .frame(height: 40)
                    }
                }
            }
            Text("Date: \(selectedDate.formatted(.dateTime.year().month().day()))")
                .font(.headline)

            Button {
                showingCreateSheet = true
            } label: {
                Text("+ ADD PLAN")
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.black)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(plans) { plan in
                        Button {
                            selectedPlan = plan
                        } label: {
                            HStack {
                                Text(plan.task)
                                    .font(.system(size: 18))
                                    .foregroundStyle(.primary)

                                Spacer()

                                Text(
                                    String(
                                        format: "%02d:%02d - %02d:%02d",
                                        plan.startTime / 60,
                                        plan.startTime % 60,
                                        plan.endTime / 60,
                                        plan.endTime % 60
                                    )
                                )
                                .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 60)
                            .background(Color(white: 0.95))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            

            
        }
        .padding()
        .sheet(isPresented: $showingCreateSheet) {
            CreatePlanView(
                date: selectedDate,
                onCreated: {
                    Task {
                        await loadPlans(for: selectedDate)
                    }
                }
            )
        }
        .sheet(item: $selectedPlan) { plan in
            EditPlanView(
                plan: plan,
                onUpdated: {
                    Task {
                        await loadPlans(for: selectedDate)
                    }
                },
                onDeleted: {
                    Task {
                        await loadPlans(for: selectedDate)
                    }
                }
            )
        }
    }
    private func loadPlans(for date: Date) async {
        do {
            plans = try await fetchPlans(for: date)
        } catch {
        }
    }

    private func changeMonth(by amount: Int) {
        if let newMonth = calendar.date(
            byAdding: .month,
            value: amount,
            to: currentMonth
        ) {
            currentMonth = newMonth
        }
    }

    private func daysInMonth() -> [Date?] {
        guard
            let interval = calendar.dateInterval(
                of: .month,
                for: currentMonth
            ),
            let numberOfDays = calendar.range(
                of: .day,
                in: .month,
                for: currentMonth
            )
        else {
            return []
        }

        let firstWeekday = calendar.component(
            .weekday,
            from: interval.start
        )

        let leadingEmptyDays = firstWeekday - 1

        let emptySlots = Array<Date?>(
            repeating: nil,
            count: leadingEmptyDays
        )

        let dates = numberOfDays.compactMap { day -> Date? in
            calendar.date(
                byAdding: .day,
                value: day - 1,
                to: interval.start
            )
        }

        return emptySlots + dates.map { Optional($0) }
    }
}

struct AllPlansPage: View {

    @State private var plans: [PlanItem] = []
    @State private var selectedPlan: PlanItem?
    @State private var serverStatus = "Loading..."

    var body: some View {
        VStack(spacing: 16) {

            Text("ALL PLANS")
                .font(.largeTitle.bold())

            Text(serverStatus)
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView {
                LazyVStack(spacing: 12) {

                    ForEach(
                        plans.sorted {
                            if $0.date != $1.date {
                                return $0.date < $1.date
                            }

                            if $0.startTime != $1.startTime {
                                return $0.startTime < $1.startTime
                            }

                            return $0.priority > $1.priority
                        }
                    ) { plan in

                        Button {
                            selectedPlan = plan
                        } label: {

                            VStack(alignment: .leading, spacing: 6) {

                                HStack {
                                    Text(plan.task)
                                        .font(.system(size: 18))

                                    Spacer()

                                    Text("P\(plan.priority)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                HStack {
                                    Text(
                                        plan.date.formatted(
                                            .dateTime
                                                .year()
                                                .month()
                                                .day()
                                        )
                                    )

                                    Spacer()

                                    Text(
                                        String(
                                            format: "%02d:%02d - %02d:%02d",
                                            plan.startTime / 60,
                                            plan.startTime % 60,
                                            plan.endTime / 60,
                                            plan.endTime % 60
                                        )
                                    )
                                    .foregroundStyle(.secondary)
                                }
                                .font(.system(size: 14))
                            }
                            .padding(.horizontal, 16)
                            .frame(maxWidth: .infinity)
                            .frame(height: 72)
                            .background(Color(white: 0.95))
                            .clipShape(
                                RoundedRectangle(cornerRadius: 12)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
            }
        }
        .padding(.top)
        .task {
            await loadPlans()
        }
        .sheet(item: $selectedPlan) { plan in
            EditPlanView(
                plan: plan,
                onUpdated: {
                    Task {
                        await loadPlans()
                    }
                },
                onDeleted: {
                    Task {
                        await loadPlans()
                    }
                }
            )
        }
    }

    private func loadPlans() async {
        do {
            plans = try await fetchAllPlans()
            serverStatus = "Server: \(plans.count) plan(s) loaded"
        } catch {
            serverStatus = "Server error: \(error)"
        }
    }
}
struct BottomPageBar: View {
    @Binding var page: Int

    var body: some View {
        HStack(spacing: 0) {
            Button {
                withAnimation {
                    page = 0
                }
            } label: {
                VStack(spacing: 8) {
                    
                    Rectangle()
                        .fill(page == 0 ? Color.black : Color.clear)
                        .frame(height: 3)
                    
                    Text("MAIN")
                        .font(.system(size: 16,
                                      weight: page == 0 ? .semibold : .regular))
                        .foregroundColor(page == 0 ? .black : .gray)


                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                withAnimation {
                    page = 1
                }
            } label: {
                VStack(spacing: 8) {
                    Rectangle()
                        .fill(page == 1 ? Color.black : Color.clear)
                        .frame(height: 3)
                    
                    Text("PLANNING")
                        .font(.system(size: 16,
                                      weight: page == 1 ? .semibold : .regular))
                        .foregroundColor(page == 1 ? .black : .gray)


                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(height: 64)
        .background(Color.white)
    }
}
    
    
struct TaskCard: View {
    let Item: PlanItem
    let currentTime: Int
    
    var remainingTime: String {
        if currentTime < Item.startTime {
            let ready = Item.startTime - currentTime
            if ready < 60 {
                return "\(ready % 60)m"
            }
            
            return "\(ready / 60)h \(ready % 60)m"
        }

        let remaining = Item.endTime - currentTime
        
        if remaining < 60 {
            return "\(remaining % 60)m"
        }
        
        return "\(remaining / 60)h \(remaining % 60)m"
    }
    
    var progress_c: Color {
        if currentTime < Item.startTime {
            return Color(white: 0.95)
        }
        else {
            return Color(white: 0.85)
        }
    }

    var body: some View {
        HStack {
            Text(Item.task)
                .font(.system(size: 20))
            Spacer()

            Text(remainingTime)
                .font(.system(size: 20))
            
        }
        .padding(.horizontal, 18)
        .frame(height: 72)
        .frame(maxWidth: .infinity)
        .background(progress_c)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct CreatePlanView: View {

    let date: Date
    let onCreated: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var task = ""
    @State private var startTime = 20 * 60
    @State private var endTime = 21 * 60
    @State private var priority = 1
    @State private var isSaving = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            Form {

                Section("Plan") {
                    TextField("Task name", text: $task)

                    DatePicker(
                        "Start",
                        selection: Binding(
                            get: {
                                dateFromMinutes(startTime)
                            },
                            set: {
                                startTime = minutesFromDate($0)
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )

                    DatePicker(
                        "End",
                        selection: Binding(
                            get: {
                                dateFromMinutes(endTime)
                            },
                            set: {
                                endTime = minutesFromDate($0)
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )

                    Stepper(
                        "Priority: \(priority)",
                        value: $priority,
                        in: 1...5
                    )
                }

                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        Task {
                            await savePlan()
                        }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("CREATE")
                        }
                    }
                    .disabled(
                        task.trimmingCharacters(in: .whitespaces).isEmpty
                        || isSaving
                        || startTime >= endTime
                    )
                }
            }
            .navigationTitle("New Plan")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func dateFromMinutes(_ minutes: Int) -> Date {
        var components = Calendar.current.dateComponents(
            [.year, .month, .day],
            from: date
        )

        components.hour = minutes / 60
        components.minute = minutes % 60

        return Calendar.current.date(from: components) ?? date
    }

    private func minutesFromDate(_ date: Date) -> Int {
        Calendar.current.component(.hour, from: date) * 60
        + Calendar.current.component(.minute, from: date)
    }

    private func savePlan() async {

        guard startTime < endTime else {
            errorMessage = "End time must be later than start time."
            return
        }

        isSaving = true
        errorMessage = ""

        let plan = PlanItem(
            task: task,
            date: date,
            startTime: startTime,
            endTime: endTime,
            priority: priority
        )

        do {
            _ = try await createPlan(plan)

            onCreated()
            dismiss()

        } catch {
            errorMessage = "Failed to create plan: \(error)"
        }

        isSaving = false
    }
}
struct EditPlanView: View {

    let plan: PlanItem
    let onUpdated: () -> Void
    let onDeleted: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var task: String
    @State private var startTime: Int
    @State private var endTime: Int
    @State private var priority: Int

    @State private var isSaving = false
    @State private var errorMessage = ""

    init(
        plan: PlanItem,
        onUpdated: @escaping () -> Void,
        onDeleted: @escaping () -> Void
    ) {
        self.plan = plan
        self.onUpdated = onUpdated
        self.onDeleted = onDeleted

        _task = State(initialValue: plan.task)
        _startTime = State(initialValue: plan.startTime)
        _endTime = State(initialValue: plan.endTime)
        _priority = State(initialValue: plan.priority)
    }

    var body: some View {
        NavigationStack {
            Form {

                Section("Plan") {

                    TextField(
                        "Task name",
                        text: $task
                    )

                    DatePicker(
                        "Start",
                        selection: Binding(
                            get: {
                                dateFromMinutes(startTime)
                            },
                            set: {
                                startTime = minutesFromDate($0)
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )

                    DatePicker(
                        "End",
                        selection: Binding(
                            get: {
                                dateFromMinutes(endTime)
                            },
                            set: {
                                endTime = minutesFromDate($0)
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )

                    Stepper(
                        "Priority: \(priority)",
                        value: $priority,
                        in: 1...5
                    )
                }

                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                Section {

                    Button {
                        Task {
                            await update()
                        }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("UPDATE")
                        }
                    }
                    .disabled(
                        task.trimmingCharacters(in: .whitespaces).isEmpty
                        || startTime >= endTime
                        || isSaving
                    )
                }

                Section {

                    Button(role: .destructive) {
                        Task {
                            await delete()
                        }
                    } label: {
                        Text("DELETE")
                    }
                    .disabled(isSaving)
                }
            }
            .navigationTitle("Edit Plan")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func dateFromMinutes(_ minutes: Int) -> Date {
        var components = Calendar.current.dateComponents(
            [.year, .month, .day],
            from: plan.date
        )

        components.hour = minutes / 60
        components.minute = minutes % 60

        return Calendar.current.date(
            from: components
        ) ?? plan.date
    }

    private func minutesFromDate(_ date: Date) -> Int {
        Calendar.current.component(.hour, from: date) * 60
        + Calendar.current.component(.minute, from: date)
    }

    private func update() async {

        guard startTime < endTime else {
            errorMessage = "End time must be later than start time."
            return
        }

        isSaving = true
        errorMessage = ""

        let updatedPlan = PlanItem(
            id: plan.id,
            task: task,
            date: plan.date,
            startTime: startTime,
            endTime: endTime,
            priority: priority
        )

        do {
            _ = try await updatePlan(updatedPlan)

            onUpdated()
            dismiss()

        } catch {
            errorMessage = "Failed to update plan: \(error)"
        }

        isSaving = false
    }

    private func delete() async {

        isSaving = true
        errorMessage = ""

        do {
            try await deletePlan(plan)

            onDeleted()
            dismiss()

        } catch {
            errorMessage = "Failed to delete plan: \(error)"
        }

        isSaving = false
    }
}

#Preview {
    ContentView()
}
