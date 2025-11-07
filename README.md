# Calamity Report App

A Flutter application for sharing images, videos, and location data during calamities.

## Features

- 📸 Image and video capture/upload
- 🗺️ Location tracking and sharing
- 💬 Real-time chat functionality
- 📱 Media gallery with preview
- ⭐ Favorite media items
- 🔍 Search and filter capabilities

## Getting Started

### Prerequisites

- Flutter (latest stable version)
- Dart SDK
- Android Studio / Xcode
- VS Code (recommended)

### Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/yourusername/calamity_report.git
   cd calamity_report
   ```

2. Install dependencies:

   ```bash
   # Clear pub cache if downloads are slow
   flutter pub cache repair
   
   # Set pub.dev as host
   set PUB_HOSTED_URL=https://pub.dev
   
   # Use specific mirror for faster downloads
   set PUB_HOSTED_URL=https://pub.flutter-io.cn
   
   # Install dependencies
   flutter pub get --verbose
   ```

3. If still slow, try offline mode:

   ```bash
   # Cache packages locally
   flutter pub get --offline
   ```

### Troubleshooting Slow Downloads

If `flutter pub get` is running slowly:

1. Check your internet connection
2. Try using a VPN if pub.dev is blocked
3. Clear Flutter cache:

   ```bash
   flutter clean
   del pubspec.lock
   flutter pub cache repair
   ```

4. Use verbose mode to identify bottlenecks:

   ```bash
   flutter pub get --verbose
   ```

## Project Structure

```
lib/
├── models/
│   └── media_item.dart
├── screens/
│   ├── chat_screen.dart
│   ├── map_screen.dart
│   ├── media_preview_screen.dart
│   └── multi_media_screen.dart
├── services/
│   ├── media_service.dart
│   └── media_upload_service.dart
├── widgets/
│   └── media_grid.dart
└── main.dart
```

## Dependencies

- provider: ^6.1.0
- image_picker: ^1.0.4
- video_player: ^2.8.1
- chewie: ^1.7.4
- path_provider: ^2.1.1
- flutter_staggered_grid_view: ^0.7.0

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Flutter team for the amazing framework
- All contributors who participate in this project