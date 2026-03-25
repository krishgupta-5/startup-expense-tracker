# Startup Expense Tracker

A comprehensive Flutter application for managing startup expenses, tracking runway, and monitoring financial health.

## Features

### Core Financial Management
- **Real-time Financial Dashboard**: Comprehensive overview with runway, burn rate, and available funds
- **Runway Calculator**: Accurate runway calculation using proper financial formulas (available_cash / monthly_burn)
- **Monthly Burn Tracking**: Detailed expense analysis with trend data and budget variance
- **Funds Overview**: Complete funding tracking including total raised, spent, and available capital
- **Bank Account Management**: Multiple bank account support with balance tracking

### Expense Management
- **Complete Expense CRUD**: Add, edit, delete, and view detailed expense records
- **Expense Scanning**: Camera-based receipt scanning and OCR processing
- **Smart Search**: Advanced search functionality across all expense data
- **Expense Categories**: Organized categorization with visual breakdowns
- **Budget Tracking**: Real-time budget variance analysis and alerts
- **Expense Reports**: Generate and export detailed financial reports
- **Expense Details**: Comprehensive expense information with metadata

### Team & HR Management
- **Team Member Management**: Add, edit, and manage team profiles
- **Salary Management**: Track and adjust team compensation
- **Role-based Organization**: Department and role categorization
- **Team Analytics**: Headcount costs and team performance metrics
- **Avatar System**: Customizable team member profiles

### AI-Powered Insights
- **Financial Intelligence**: AI-powered analysis of spending patterns
- **Runway Predictions**: Intelligent forecasting and recommendations
- **Investment Insights**: Data-driven investment advice
- **Performance Analytics**: Automated performance assessments
- **Expense Intelligence**: Smart categorization and anomaly detection

### Authentication & Security
- **Google Sign-In**: Secure OAuth authentication
- **Email/Password Auth**: Traditional authentication methods
- **Password Recovery**: Secure password reset functionality
- **Privacy Controls**: Comprehensive data access and privacy settings

### Settings & Configuration
- **Company Setup**: Complete company profile and funding configuration
- **Profile Management**: User profile customization
- **Data Export**: Download statements and financial data
- **Privacy Settings**: Granular privacy and data access controls
- **App Settings**: Customizable app preferences and configurations

### Technical Features
- **Multi-platform Support**: iOS, Android, Web, macOS, Linux, Windows
- **Firebase Integration**: Real-time data synchronization
- **Offline Support**: Local data caching and sync
- **Dark Theme**: Modern dark mode UI throughout
- **Responsive Design**: Optimized for all screen sizes
- **Real-time Updates**: Live data synchronization across devices

## File Structure

```
StartupExpenseTracker/
├── lib/
│   ├── main.dart                     # App entry point
│   ├── firebase_options.dart         # Firebase configuration
│   ├── theme/
│   │   └── app_theme.dart            # App theme and styling
│   ├── features/
│   │   ├── ai/                       # AI-powered insights and analytics
│   │   │   ├── screens/
│   │   │   │   └── ai_screen.dart
│   │   │   └── widgets/
│   │   │       └── ai_insight_card.dart
│   │   ├── auth/                     # Authentication system
│   │   │   ├── auth_wrapper.dart
│   │   │   ├── services/
│   │   │   │   └── google_sign_in_service.dart
│   │   │   └── screens/
│   │   │       ├── login.dart
│   │   │       ├── signup.dart
│   │   │       └── forget_password.dart
│   │   ├── company-setup/            # Company configuration
│   │   │   └── screen/
│   │   │       └── company_setup_screen.dart
│   │   ├── expenses/                 # Complete expense management
│   │   │   ├── screens/
│   │   │   │   ├── add_expense_screen.dart
│   │   │   │   ├── edit_expense_screen.dart
│   │   │   │   ├── expense_details_screen.dart
│   │   │   │   ├── expenses_screen.dart
│   │   │   │   ├── report_expense_screen.dart
│   │   │   │   ├── scan_expense_screen.dart
│   │   │   │   └── search_expense_screen.dart
│   │   │   └── widgets/
│   │   │       └── single_date_picker.dart
│   │   ├── home/                     # Financial dashboard and analytics
│   │   │   └── screens/
│   │   │       ├── AddBankAccountScreen.dart
│   │   │       ├── funds_overview_screen.dart
│   │   │       ├── home_screen.dart
│   │   │       ├── monthly_burn_screen.dart
│   │   │       └── runway_estimation_screen.dart
│   │   ├── navigation/               # App navigation system
│   │   │   └── screens/
│   │   │       ├── main_navigation_wrapper.dart
│   │   │       └── navigation_wrapper.dart
│   │   ├── settings/                # App settings and configuration
│   │   │   └── screens/
│   │   │       ├── change_password.dart
│   │   │       ├── company_details_screen.dart
│   │   │       ├── data_access_screen.dart
│   │   │       ├── edit_profile_screen.dart
│   │   │       ├── privacy_assurances_screen.dart
│   │   │       ├── rate_us_screen.dart
│   │   │       ├── settings_screen.dart
│   │   │       └── statements_screen.dart
│   │   └── team/                    # Team and HR management
│   │       ├── screens/
│   │       │   ├── add_member_screen.dart
│   │       │   ├── adjust_salary_screen.dart
│   │       │   ├── create_team_screen.dart
│   │       │   ├── edit_team_screen.dart
│   │       │   ├── team_detail_screen.dart
│   │       │   └── team_screen.dart
│   │       └── widgets/
│   │           └── team_member_card.dart
│   ├── services/                    # Core business logic
│   │   ├── bank_account_service.dart
│   │   ├── cashflow_service.dart
│   │   ├── currency_formatter.dart
│   │   ├── financial_calculator.dart  # Centralized financial calculations
│   │   └── financial_data_service.dart
│   └── widgets/                     # Reusable UI components
│       ├── avatar_widget.dart
│       └── custom_bottom_nav.dart
├── android/                         # Android-specific files
├── ios/                            # iOS-specific files
├── web/                            # Web-specific files
├── macos/                          # macOS-specific files
├── linux/                          # Linux-specific files
├── windows/                        # Windows-specific files
├── assets/
│   └── images/
│       └── google_logo.png
├── test/                           # Test files
│   ├── name_sync_test.dart
│   └── widget_test.dart
├── .env.local                      # Environment variables
├── .firebaserc                     # Firebase configuration
├── .fvmrc                          # Flutter version configuration
├── .gitignore
├── .metadata
├── pubspec.yaml                    # Flutter dependencies
├── pubspec.lock
├── analysis_options.yaml
├── firebase.json                   # Firebase project configuration
├── firestore.indexes.json         # Firestore index configuration
└── firestore.rules                 # Firestore security rules
```

## Architecture

The app follows a clean, scalable architecture pattern with:

- **Feature-based structure**: Each major feature has its own directory with screens, widgets, and services
- **Service layer**: Centralized business logic and data services with proper separation of concerns
- **Widget layer**: Reusable UI components with consistent design patterns
- **Theme layer**: Centralized app styling with shadcn/ui dark theme
- **Navigation system**: Modular navigation with tab-based routing

### Key Services

- **FinancialCalculator**: Centralized financial calculations (runway, burn rate, budget variance) following fintech patterns
- **FinancialDataService**: Real-time financial data aggregation and caching
- **BankAccountService**: Bank account management and balance tracking
- **CashflowService**: Cash flow analysis and reporting
- **CurrencyFormatter**: Consistent currency formatting across the app

### Architecture Principles

- **Single Source of Truth**: All financial calculations go through FinancialCalculator
- **Investor-Safe Calculations**: Mathematically correct formulas for runway and burn metrics
- **Real-time Data**: Firebase integration with live synchronization
- **Error Handling**: Comprehensive error handling and user feedback
- **Performance**: Optimized data loading and caching strategies
- **Security**: Firebase security rules and proper authentication flows

## Technology Stack

### Core Framework
- **Flutter 3.10+**: Cross-platform UI framework
- **Dart**: Programming language
- **Firebase**: Backend services (Auth, Firestore, Storage)

### UI & Design
- **shadcn/ui**: Modern dark theme components
- **Google Fonts (Inter)**: Typography
- **FL Chart**: Financial charts and visualizations
- **Table Calendar**: Date selection and calendar views

### State Management & Data
- **Provider**: State management
- **Cloud Firestore**: Real-time database
- **Firebase Auth**: Authentication services

### Media & Documents
- **Camera**: Receipt scanning and photography
- **Image Picker**: Gallery access
- **Image Cropper**: Image editing
- **PDF**: Report generation
- **Printing**: Document export

### Utilities
- **URL Launcher**: External links and navigation
- **UUID**: Unique identifier generation
- **HTTP**: API communications
- **Permission Handler**: Device permissions
- **Flutter DotEnv**: Environment configuration

### Development Tools
- **Flutter Lints**: Code quality and style enforcement
- **Flutter Test**: Unit and widget testing

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
