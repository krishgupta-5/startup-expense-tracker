# Startup Expense Tracker

A comprehensive Flutter application for managing startup expenses, tracking runway, and monitoring financial health.

## Features

- **Expense Management**: Add, categorize, and track business expenses
- **Runway Calculator**: Real-time runway calculation based on funding and burn rate
- **Financial Dashboard**: Overview of financial health with key metrics
- **Team Management**: Manage team members and roles
- **Company Setup**: Configure company details and funding information
- **AI Integration**: AI-powered expense analysis and insights
- **Multi-platform Support**: iOS, Android, Web, macOS, Linux, Windows

## File Structure

```
StartupExpenseTracker/
├── lib/
│   ├── main.dart                     # App entry point
│   ├── firebase_options.dart         # Firebase configuration
│   ├── theme/
│   │   └── app_theme.dart            # App theme and styling
│   ├── features/
│   │   ├── ai/                       # AI-powered features
│   │   ├── auth/                     # Authentication screens
│   │   ├── company-setup/            # Company configuration
│   │   ├── expenses/                 # Expense management
│   │   │   ├── screens/
│   │   │   │   ├── scan_expense_screen.dart
│   │   │   │   └── expenses_screen.dart
│   │   │   └── ...
│   │   └── team/                     # Team management
│   │       ├── screens/
│   │       │   ├── edit_team_screen.dart
│   │       │   └── team_screen.dart
│   │       └── ...
│   ├── services/
│   │   ├── bank_account_service.dart
│   │   ├── cashflow_service.dart
│   │   ├── currency_formatter.dart
│   │   └── financial_calculator.dart  # Centralized financial calculations
│   └── widgets/
│       ├── avatar_widget.dart
│       └── custom_bottom_nav.dart
├── android/                          # Android-specific files
├── ios/                             # iOS-specific files
├── web/                             # Web-specific files
├── macos/                           # macOS-specific files
├── linux/                           # Linux-specific files
├── windows/                         # Windows-specific files
├── assets/
│   └── images/
│       └── google_logo.png
├── test/                            # Test files
│   ├── name_sync_test.dart
│   └── widget_test.dart
├── .env.local                       # Environment variables
├── .firebaserc                      # Firebase configuration
├── .fvmrc                          # Flutter version configuration
├── .gitignore
├── .metadata
├── pubspec.yaml                     # Flutter dependencies
├── pubspec.lock
├── analysis_options.yaml
├── firebase.json                    # Firebase project configuration
├── firestore.indexes.json          # Firestore index configuration
└── firestore.rules                  # Firestore security rules
```

## Architecture

The app follows a clean architecture pattern with:

- **Feature-based structure**: Each major feature has its own directory
- **Service layer**: Centralized business logic and data services
- **Widget layer**: Reusable UI components
- **Theme layer**: Consistent app styling

### Key Services

- **FinancialCalculator**: Centralized financial calculations (runway, burn rate, etc.)
- **BankAccountService**: Bank account management
- **CashflowService**: Cash flow analysis
- **CurrencyFormatter**: Currency formatting utilities

## Getting Started

### Prerequisites

- Flutter SDK (version specified in `.fvmrc`)
- Firebase project configured
- Environment variables set in `.env.local`

### Installation

1. Clone the repository
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Set up Firebase:
   ```bash
   flutterfire configure
   ```
4. Run the app:
   ```bash
   flutter run
   ```

### Firebase Configuration

The app uses Firebase for:
- Authentication
- Cloud Firestore (database)
- Firebase Storage (file uploads)

Make sure to:
1. Create a Firebase project
2. Configure iOS and Android apps
3. Set up Firestore rules and indexes
4. Add service account configuration

## Development

### Running Tests

```bash
flutter test
```

### Code Analysis

```bash
flutter analyze
```

### Build for Production

```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release

# Web
flutter build web --release
```

## Contributing

1. Follow the existing code style
2. Run tests before submitting
3. Update documentation as needed
4. Use feature branches for new development

## License

This project is proprietary software.
