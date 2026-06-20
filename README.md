# Book Time

**Book Time** is a Flutter application designed for book lovers. It allows you to discover new books, manage your personal library, and track your reading sessions using a built-in timer.

## Features

- **Book Search:** Easily find any book and fetch details thanks to the **Open Library API** integration.
- **Personal Library:** Add books and organize them (e.g., To Read, Reading, Read).
- **Reading Timer:** Time your reading sessions and keep track of how much time you dedicate to your books.
- **User Profile & Stats:** Monitor your reading progress over time.
- **Suggestions:** Discover new titles recommended based on your preferences.
- **Smart Offline Support & Caching:** Uses `shared_preferences` for instantaneous Stale-while-revalidate data loading, and `cached_network_image` for persistent cover image caching, resulting in lightning-fast, zero-wait loading times.

## Project Architecture (MVC)

The application is structured following the **Model-View-Controller (MVC)** design pattern. This ensures a clean Separation of Concerns (SoC), making the codebase highly cohesive, modular, and easy to maintain.

- **Model**: Defines the core data structures (e.g., the `Book` entity) and handles data serialization, completely independent of the UI.
- **View**: The passive Flutter UI components (`views/`) that render the application and capture user interactions. They react automatically to state changes.
- **Controller**: The brain of the app (`controllers/`). It handles the business logic, orchestrates the global state using the `provider` package, and delegates data persistence and networking to dedicated **Services**.

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

## Technologies Used

- **Framework:** [Flutter](https://flutter.dev/)
- **State Management:** `provider`
- **Local Storage:** `shared_preferences`
- **Networking:** `http` for Open Library API requests
- **Image Caching:** `cached_network_image` for offline covers and RAM optimization
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