# Book Time

**Book Time** is a Flutter application designed for book lovers. It allows you to discover new books, manage your personal library, and track your reading sessions using a built-in timer.

## Features

- **Book Search:** Easily find any book and fetch details thanks to the **Open Library API** integration.
- **Personal Library:** Add books and organize them (e.g., To Read, Reading, Read).
- **Reading Timer:** Time your reading sessions and keep track of how much time you dedicate to your books.
- **User Profile & Stats:** Monitor your reading progress over time.
- **Suggestions:** Discover new titles recommended based on your preferences.
- **Partial Offline Support:** Uses `shared_preferences` to save essential data locally.

## Project Architecture (Three-Tier & MVC)

The application is structured following a strict **Three-Tier** system architecture, with the presentation and application logic organized using the **Model-View-Controller (MVC)** design pattern. This ensures high cohesion and low coupling.

- **Interface Layer (Views)**: Manages the UI and user interactions.
- **Application Logic Layer (Controllers & Models)**: Defines the central data structures (`Book`) and orchestrates the app state using `provider`.
- **Storage Layer (Services)**: Handles persistent data via `shared_preferences` and external HTTP requests to the Open Library API.

### Directory Structure

```text
lib/
│
├── main.dart
│
├── models/                   
│   └── book.dart             (Entity object representing the core data)
│
├── controllers/              
│   └── app_controller.dart   (Handles business logic & orchestrates state)
│
├── views/                    
│   ├── pages/                (Full screens e.g., book_list_page, search_page)
│   ├── dialogs/              (Popups and modal sheets e.g., rating_dialog)
│   └── widgets/              (Reusable UI components)
│
└── services/                 
    ├── api_service.dart      (External API communication)
    └── storage_service.dart  (Local persistence)
```

## 🛠 Technologies Used

- **Framework:** [Flutter](https://flutter.dev/)
- **State Management:** `provider`
- **Local Storage:** `shared_preferences`
- **Networking:** `http` for Open Library API requests
- **Other:** `image_picker`, `uuid`, `path_provider`

## Getting Started

If you want to run this app locally, follow these steps:

1. **Clone the repository:**
   ```bash
   git clone https://github.com/GiadaDiSerio/book-time.git
   ```
2. **Navigate to the directory:**
   ```bash
   cd book_time
   ```
3. **Get dependencies:**
   ```bash
   flutter pub get
   ```
4. **Run the app:**
   ```bash
   flutter run
   ```