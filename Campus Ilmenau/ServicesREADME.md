# 🌐 API Services - Dokumentation

## 📁 Struktur

```
Services/
├── MensaService.swift       # Haupt-API-Service
└── MockMensaService.swift   # Mock für Tests/Preview
```

---

## 🚀 MensaService

### Verwendung:

```swift
// Service initialisieren
let service = MensaService(
    baseURL: APIConfig.mensaBaseURL,
    apiKey: APIConfig.mensaAPIKey
)

// Oder in SwiftUI View:
@StateObject private var mensaService = MensaService()
```

### Methoden:

#### `fetchMeals(for date: Date) async throws`
Lädt Speiseplan für ein bestimmtes Datum.

```swift
Task {
    try await mensaService.fetchMeals(for: Date())
    // Daten sind jetzt in mensaService.meals verfügbar
}
```

#### `fetchMealsForWeek(startDate: Date, days: Int) async throws -> [Date: [MensaMeal]]`
Lädt Speiseplan für mehrere Tage.

```swift
Task {
    let weekMeals = try await mensaService.fetchMealsForWeek(days: 7)
    // weekMeals ist Dictionary mit Datum → [MensaMeal]
}
```

### Published Properties:

- `@Published var meals: [MensaMeal]` - Aktuelle Gerichte
- `@Published var isLoading: Bool` - Loading-State
- `@Published var errorMessage: String?` - Fehlermeldung

---

## 🧪 MockMensaService

Für Entwicklung ohne echte API:

```swift
let mockService = MockMensaService(useMockData: true)
```

Generiert automatisch Demo-Daten mit 1 Sekunde Delay.

---

## ⚙️ API-Konfiguration

### Setup:

1. Kopieren Sie `APIConfig.swift.example` zu `APIConfig.swift`:
```bash
cp APIConfig.swift.example APIConfig.swift
```

2. Fügen Sie Ihre API-Keys ein:
```swift
struct APIConfig {
    static let mensaAPIKey = "ihr-echter-key"
    static let mensaBaseURL = "https://echte-api-url.de"
    static let useMockData = false // true für Mock-Daten
}
```

3. APIConfig.swift wird NICHT committed (ist in .gitignore)!

---

## 🔌 API-Integration anpassen

### TODO: API-Dokumentation einfügen!

Passen Sie `MensaService.swift` an Ihre echte API an:

1. **URL-Struktur** (Zeile ~150):
```swift
private func buildURL(for date: Date) -> URL? {
    // TODO: An Ihre API anpassen!
    components?.queryItems = [
        URLQueryItem(name: "date", value: dateString)
    ]
}
```

2. **Authentication** (Zeile ~130):
```swift
// Option 1: API-Key Header
request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")

// Option 2: Bearer Token
request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

// Option 3: Query Parameter
// Fügen Sie apiKey als URLQueryItem hinzu
```

3. **Response-Format** (Zeile ~90):
```swift
// Passen Sie MensaAPIResponse und APIMeal an:
private struct MensaAPIResponse: Codable {
    let meals: [APIMeal]
    // TODO: Fügen Sie Ihre API-Felder hinzu
}
```

---

## 📋 Beispiel: API-Response

### Erwartetes JSON-Format:

```json
{
  "meals": [
    {
      "id": 1,
      "category": "Hauptgericht 1",
      "name": "Hähnchenschnitzel",
      "description": "mit Pommes Frites und Salat",
      "price": 350,
      "allergies": ["Gluten", "Ei"],
      "badges": []
    }
  ],
  "date": "2026-10-26",
  "mensa_name": "Mensa Ehrenberg"
}
```

### Wenn Ihre API anders aussieht:

Passen Sie die Structs an:

```swift
private struct APIMeal: Codable {
    let id: Int
    let title: String      // Statt "name"
    let priceInCents: Int  // Statt "price"
    
    enum CodingKeys: String, CodingKey {
        case id
        case title = "name"          // Mapping
        case priceInCents = "price"
    }
}
```

---

## 🧪 Testing

### Unit Tests:

```swift
func testFetchMeals() async throws {
    let mockService = MockMensaService()
    
    try await mockService.fetchMeals()
    
    XCTAssertFalse(mockService.meals.isEmpty)
    XCTAssertEqual(mockService.meals.count, 6)
}
```

### Preview:

```swift
#Preview {
    let mockService = MockMensaService()
    
    return MensaView()
        .environmentObject(mockService)
}
```

---

## 🐛 Error Handling

### Fehlertypen:

```swift
enum MensaAPIError {
    case invalidURL          // Falsche URL-Konfiguration
    case invalidResponse     // Server antwortet nicht korrekt
    case httpError(Int)      // HTTP-Fehler (404, 500, etc.)
    case decodingError       // JSON-Dekodierung fehlgeschlagen
    case networkError        // Netzwerkproblem
}
```

### Fehler abfangen:

```swift
Task {
    do {
        try await mensaService.fetchMeals()
    } catch MensaAPIError.httpError(let code) {
        print("HTTP Error: \(code)")
    } catch {
        print("Error: \(error.localizedDescription)")
    }
}
```

---

## 🎯 Nächste Schritte:

1. ✅ API-Dokumentation bereitstellen
2. ✅ API-Response-Format prüfen
3. ✅ `MensaService` an echte API anpassen
4. ✅ Authentifizierung konfigurieren
5. ✅ Tests schreiben
6. ✅ MensaView mit Service verbinden

---

## 📞 Fragen?

- Zeigen Sie mir Ihre API-Dokumentation
- Ich passe den Service dann exakt an!
