<div align="center">

# 💰 Startup Expense Tracker (SET)

### The Financial Operating System for Modern Startups

Track expenses, monitor burn rate, estimate runway, manage teams, and receive AI-powered financial insights—all from a single platform built specifically for startups.

---

![Flutter](https://img.shields.io/badge/Flutter-3.38-blue?style=for-the-badge&logo=flutter)
![Firebase](https://img.shields.io/badge/Firebase-Backend-orange?style=for-the-badge&logo=firebase)
![Gemini](https://img.shields.io/badge/Gemini-AI-blue?style=for-the-badge)
![Groq](https://img.shields.io/badge/Groq-Llama%203.1-black?style=for-the-badge)
![FastAPI](https://img.shields.io/badge/FastAPI-Python-009688?style=for-the-badge&logo=fastapi)

---

**Helping founders make smarter financial decisions with AI.**

</div>

---

# 📖 Table of Contents

- 🚀 Introduction
- ❗ Problem Statement
- 📉 Why Existing Solutions Fail
- 💡 Our Solution
- 🎯 Target Users
- ✨ Core Features
- 🏗️ System Architecture
- 🤖 AI Workflow
- 🛠️ Tech Stack
- 📸 Screenshots
- 📈 Roadmap
- ⚡ Installation

---

# 🚀 Introduction

Managing startup finances is difficult.

Most founders don't have a finance team, a CFO, or expensive accounting software.

Instead, they rely on spreadsheets, notes, WhatsApp messages, and bank statements.

As the company grows, financial visibility becomes increasingly difficult.

Startup Expense Tracker (SET) gives founders one place to manage company expenses, understand cash flow, monitor runway, and receive AI-powered financial insights.

Instead of focusing on bookkeeping, founders can focus on building their company.

---

# ❗ Problem Statement

Early-stage startups often struggle with financial management.

Common challenges include:

- No centralized expense tracking
- Poor visibility into monthly burn
- No runway estimation
- Manual reporting
- Team expenses scattered across departments
- Difficulty preparing investor updates
- Time-consuming financial analysis

Most existing accounting software is designed for established businesses—not startups.

Small teams need something faster, simpler, and focused on decision-making rather than accounting complexity.

---

# 📉 Why Existing Solutions Fall Short

| Traditional Accounting Software | Startup Expense Tracker |
|--------------------------------|-------------------------|
| Built for accountants | Built for founders |
| Complex dashboards | Simple financial overview |
| Expensive monthly pricing | Startup-friendly |
| Heavy accounting workflows | Fast expense tracking |
| Limited startup metrics | Burn rate & runway built-in |
| Generic reporting | AI-powered financial insights |

Our goal isn't to replace enterprise accounting software.

Our goal is to become the financial command center for startups.

---

# 💡 Our Solution

Startup Expense Tracker provides founders with real-time financial visibility.

Everything—from daily expenses to AI-generated financial insights—is available in one application.

The platform combines:

- 📊 Financial Dashboard
- 💸 Expense Management
- 👥 Team & Payroll
- 🏦 Bank Account Management
- 📄 Report Generation
- 🤖 AI Financial Advisor

This enables startup teams to understand where money is being spent and make better financial decisions.

---

# 🎯 Who Is It For?

Startup Expense Tracker is designed for:

- 🚀 Startup Founders
- 👨‍💻 Indie Hackers
- 💼 Small Business Owners
- 👥 Early-stage Teams
- 🏢 Startup Accelerators
- 🎓 Student Startups
- 💰 Pre-seed & Seed Companies

---

# 🌟 Why SET?

Instead of switching between multiple tools, founders get:

✅ Expense Tracking

✅ Burn Rate Monitoring

✅ Runway Estimation

✅ Team Expense Management

✅ Payroll Tracking

✅ AI Financial Insights

✅ PDF Reports

✅ Receipt Scanner

—all inside one platform.

---



# 📈 Vision

Our long-term vision is to build an **AI Financial Operating System** for startups.

Today, SET helps founders understand where their money goes.

Tomorrow, it will help them decide where their money should go.
# ✨ Core Features

Startup Expense Tracker is designed specifically for startups, helping founders manage finances without the complexity of traditional accounting software.

---

## 📊 Financial Dashboard

A centralized dashboard that provides an overview of your startup's financial health.

### Features

- Monthly Burn Rate
- Cash Flow Overview
- Available Balance
- Runway Estimation
- Expense Distribution
- Financial Summary Cards

---

## 💸 Expense Management

Record and organize company expenses efficiently.

### Features

- Add Expenses
- Edit & Delete Expenses
- Expense Categories
- Recurring Expenses
- Receipt Attachments
- Expense Timeline

---

## 👥 Team & Payroll

Manage employees and payroll from a single workspace.

### Features

- Team Members
- Salary Records
- Payroll History
- Monthly Salary Tracking
- Employee Management

---

## 🏦 Bank Account Management

Track multiple business accounts.

### Features

- Multiple Accounts
- Account Balance
- Transaction History
- Cash Monitoring

---

## 🤖 AI Financial Advisor

SET leverages AI to provide smarter financial insights.

Current AI capabilities include:

- Financial Health Analysis
- Burn Rate Analysis
- Runway Suggestions
- Spending Pattern Insights
- Expense Recommendations
- Startup Financial Guidance

---

## 📷 Smart Receipt Scanner

Capture receipts and extract important information automatically.

Features include:

- Receipt OCR
- Auto Expense Detection
- Data Extraction
- Expense Categorization

---

## 📄 Reports

Generate financial reports for better decision making.

Current reports include:

- Expense Reports
- Financial Summary
- Payroll Reports
- Exportable PDF Reports

---

## 🔐 Authentication & Security

Secure authentication powered by Firebase.

Features:

- Email Authentication
- Google Sign-In
- Password Reset
- Email Verification
- Secure User Sessions

---

# 🏗️ System Architecture

Startup Expense Tracker follows a modular architecture where every service is isolated and independently scalable.

> **📌 Replace the image below with the Excalidraw Architecture Diagram.**

<p align="center">

<img src="./assets/System Arch.png" width="100%" />

</p>

---

## Architecture Overview

```text
                    Flutter App
                          │
                          ▼
                Firebase Authentication
                          │
                          ▼
                Startup Expense Tracker
                          │
        ┌─────────────────┼──────────────────┐
        │                 │                  │
        ▼                 ▼                  ▼
 Expenses Service   Team Service     Bank Accounts
        │                 │                  │
        └─────────────────┼──────────────────┘
                          │
                          ▼
                 AI Financial Engine
                (Gemini + Groq APIs)
                          │
                          ▼
              OCR & Financial Analysis
                          │
                          ▼
                Firebase Firestore
                          │
                          ▼
                 Cloud Storage
```

---

# 🤖 AI Workflow

Instead of acting as a chatbot, AI is integrated into the product workflow.

```text
Receipt
   │
   ▼
OCR Processing
   │
   ▼
Expense Extraction
   │
   ▼
Categorization
   │
   ▼
Financial Analysis
   │
   ▼
Insights & Recommendations
```

---

## AI Services

| AI Model | Purpose |
|----------|----------|
| Gemini | Financial Insights |
| Gemini Vision | Receipt OCR |
| Groq (Llama 3.1) | Financial Analysis |

---

# 🔥 Firebase Services

Firebase powers the backend infrastructure.

### Firestore

Stores:

- Users
- Expenses
- Teams
- Payroll
- Bank Accounts
- Transactions

---

### Firebase Storage

Stores:

- Receipt Images
- User Profile Photos
- Generated Reports

---

### Firebase Authentication

Handles:

- Login
- Registration
- Password Reset
- Google Sign-In

---

# 🛠️ Tech Stack

| Category | Technology |
|-----------|------------|
| Mobile | Flutter |
| Language | Dart |
| Backend | Firebase |
| Database | Cloud Firestore |
| Authentication | Firebase Auth |
| Storage | Firebase Storage |
| AI | Gemini |
| OCR | Gemini Vision |
| Financial Analysis | Groq |
| State Management | Provider |
| Charts | fl_chart |
| PDF Generation | PDF |

---

# 📂 Project Structure

```text
lib/
│
├── core/
├── models/
├── providers/
├── repositories/
├── screens/
│
├── dashboard/
├── expenses/
├── payroll/
├── teams/
├── reports/
├── ai/
├── bank_accounts/
│
├── widgets/
├── services/
├── utils/
│
└── main.dart
```

---

# 📸 Screenshots

## 🏠 Dashboard

> *Dashboard screenshot to be added later*

---

## 💸 Expense Management

> *Expense management screenshot to be added later*

---

## 👥 Team Management

> *Team management screenshot to be added later*

---

## 🤖 AI Financial Advisor

> *AI insights screenshot to be added later*

---

## 📄 Reports

> *PDF report screenshot to be added later*
# 📈 Product Roadmap

We're building Startup Expense Tracker step by step with a focus on solving real financial problems faced by early-stage startups.

---

## ✅ Phase 1 — MVP (Current)

The current version includes:

- 📊 Financial Dashboard
- 💸 Expense Tracking
- 👥 Team Management
- 💰 Payroll Management
- 🏦 Bank Account Management
- 🤖 AI Financial Advisor
- 📄 PDF Report Generation
- 📷 Receipt OCR
- 🔐 Firebase Authentication
- ☁️ Cloud Storage

---

## 🚀 Phase 2

Planned improvements:

- Expense approval workflow
- Budget planning
- Goal tracking
- Better analytics

---

## 🌍 Phase 3

Business integrations

- Razorpay
- Stripe

---

## 🧠 Phase 4

AI Financial Copilot

Instead of only showing numbers,

the platform will answer questions like

> Can I hire another developer?

> How many months of runway do I have?

> Which department is overspending?

> What happens if revenue drops by 20%?

Our long-term vision is to become an AI CFO for startups.

---

# 🌍 Market Opportunity

Every startup has one common problem:

Managing money.

Early-stage founders rarely have

- Finance Teams
- Accountants
- CFOs

Most rely on

- Excel Sheets
- Google Sheets
- Bank Statements
- Manual Bookkeeping

Traditional accounting software is often too expensive, complex, and designed for established businesses.

Startup Expense Tracker is built specifically for startup founders who need fast financial visibility—not enterprise accounting software.

---

# 💰 Business Model

Startup Expense Tracker follows a SaaS subscription model.

### Free

Perfect for individuals and student startups.

- Expense Tracking
- Dashboard
- AI Insights (Limited)
- Reports

---

### Pro

Designed for growing startups.

Includes:

- Unlimited Expenses
- Team Management
- Payroll
- Advanced AI Insights
- Unlimited Reports

---

### Enterprise

For incubators and startup accelerators.

Includes:

- Priority Support
- Dedicated Workspace

---

# 🚀 Why Now?

Startups are being created faster than ever.

However, financial management tools have not evolved for founders.

Founders don't need accounting software.

They need financial clarity.

With modern AI, we can transform financial data into actionable business insights instead of static spreadsheets.

---

# ❤️ Why We Built This

As developers, we realized that startup founders spend too much time managing expenses manually.

Financial decisions should be simple.

Instead of opening multiple spreadsheets, founders should be able to open one application and instantly understand:

- How much money is left
- Monthly burn rate
- Cash flow
- Team costs
- Financial health

Startup Expense Tracker was built to make startup finance simple, visual, and intelligent.

---



# 🚀 Future Vision

Today,

Startup Expense Tracker helps founders understand their finances.

Tomorrow,

it will help them make better financial decisions using AI.

Our vision is to build

> **The Financial Operating System for Startups.**

---

# ⚡ Installation

Clone the repository

```bash
git clone https://github.com/your-username/startup-expense-tracker.git
```

Move into the project

```bash
cd startup-expense-tracker
```

Install dependencies

```bash
flutter pub get
```

Run the application

```bash
flutter run
```

---

# 🔐 Environment Variables

Configure Firebase and AI credentials before running the project.

Required services include:

- Firebase Authentication
- Cloud Firestore
- Firebase Storage
- Gemini API
- Groq API

---

# 🛠 Built With

- Flutter
- Dart
- Firebase
- Firestore
- Firebase Storage
- Provider
- Gemini AI
- Groq
- PDF
- Flutter Charts

---

# 🤝 Contributing

Contributions are welcome.

If you'd like to improve Startup Expense Tracker,

feel free to fork the repository and submit a Pull Request.

---

# 👨‍💻 Developer

**Atishay Bhaiya**
**Sahil Mishra**
**Krish Gupta**

Passionate about building AI-powered products that solve real-world problems.

---

# 📜 License

This project is licensed under the MIT License.

---

# ⭐ Support

If you found this project helpful,

please consider giving it a ⭐ on GitHub.

Your support motivates us to continue improving the platform.

---

<div align="center">

# 💰 Startup Expense Tracker

### Helping founders spend less time managing money

### and more time building companies.

---

**Built with ❤️ using Flutter, Firebase & AI**

</div>