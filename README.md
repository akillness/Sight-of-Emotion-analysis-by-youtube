# youtube_trends_flutter

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Project Structure

The project follows a standard Flutter feature-first structure:

*   **`lib/main.dart`**: Entry point of the application. Initializes Flutter and sets up the initial screen.
*   **`lib/screens/`**: Contains the different screens (pages) of the application.
    *   `trends_screen.dart`: The main screen displaying YouTube video trends, analysis results, and visualizations.
*   **`lib/widgets/`**: Contains reusable UI components used across different screens.
    *   `app_theme.dart`: Defines the application's visual theme (colors, fonts, etc.).
    *   `pagination_controls.dart`: UI component for navigating paginated data.
    *   `charts/`: Directory containing specific chart widgets.
        *   `trends_pie_chart.dart`: Displays sentiment distribution in a pie chart.
        *   `keyword_network_graph.dart`: Visualizes keyword relationships as a network graph.
        *   `keyword_typography.dart`: Displays keywords, potentially styled by relevance or sentiment.
*   **`lib/models/`**: Defines the data structures (data classes) used throughout the application.
    *   `youtube_data.dart`: Represents data for a YouTube video (title, ID, stats, etc.).
    *   `keyword_sentiment.dart`: Represents a keyword and its associated sentiment score.
    *   `video_analysis_result.dart`: Holds the results of analyzing a video (keywords, sentiments).
    *   `api_response.dart`: Defines the structure for YouTube API responses.
    *   `database.dart`, `database.g.dart`, `database/`: Defines the local database schema (using Drift/Moor), generated code, and platform-specific connection logic (native, web).
*   **`lib/services/`**: Contains classes responsible for business logic and external interactions.
    *   `api_service.dart`: Handles communication with the YouTube Data API.
    *   `nlp_service.dart`: Provides Natural Language Processing capabilities (e.g., sentiment analysis).
    *   `database_helper.dart`: Manages operations (CRUD) on the local database.
    *   `migration_service.dart`: Handles database schema updates and migrations.
*   **`lib/utils/`**: Contains utility functions and helper classes.
    *   `text_analyzer.dart`: Provides text analysis functionalities like keyword extraction.
