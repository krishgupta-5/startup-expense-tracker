# from fastapi import FastAPI
# from fastapi.middleware.cors import CORSMiddleware
# import requests
# import os
# from dotenv import load_dotenv

# # Load env
# load_dotenv()

# app = FastAPI(title="AI Financial Advisor API")

# # ✅ CORS
# app.add_middleware(
#     CORSMiddleware,
#     allow_origins=["*"],
#     allow_credentials=True,
#     allow_methods=["*"],
#     allow_headers=["*"],
# )

# API_KEY = os.getenv("GROQ_API_KEY")

# print("API KEY LOADED:", "YES" if API_KEY else "NO")


# # 🔥 LLM CALL FUNCTION
# def call_llm(prompt: str):
#     try:
#         res = requests.post(
#             "https://api.groq.com/openai/v1/chat/completions",
#             headers={
#                 "Authorization": f"Bearer {API_KEY}",
#                 "Content-Type": "application/json"
#             },
#             json={
#                 "model": "llama-3.1-8b-instant",
#                 "messages": [{"role": "user", "content": prompt}],
#                 "temperature": 0.7,
#                 "max_tokens": 300
#             },
#             timeout=10
#         )

#         print("STATUS:", res.status_code)
#         print("RESPONSE:", res.text)

#         if res.status_code != 200:
#             return f"AI ERROR: {res.text}"

#         return res.json()["choices"][0]["message"]["content"]

#     except Exception as e:
#         return f"Exception: {str(e)}"


# # ✅ HEALTH
# @app.get("/")
# def home():
#     return {"status": "AI API running 🚀"}


# # 🔥 MAIN ENDPOINT
# @app.post("/expense-ai")
# def expense_ai(data: dict):

#     # 🔥 MULTI EXPENSE ANALYSIS
#     if "expenses" in data:
#         expenses = data["expenses"]

#         summary = ""
#         total = 0
#         category_map = {}
#         team_map = {}

#         for e in expenses:
#             amount = float(e.get("amount", 0))
#             category = e.get("category", "unknown")
#             team = e.get("team", "general")

#             total += amount

#             # category aggregation
#             category_map[category] = category_map.get(category, 0) + amount

#             # team aggregation
#             team_map[team] = team_map.get(team, 0) + amount

#             summary += f"""
# Amount: {amount}
# Category: {category}
# Type: {e.get('type')}
# Description: {e.get('description')}
# Team: {team}
# ---
# """

#         prompt = f"""
# You are an AI financial advisor for startups.

# Analyze these expenses:

# {summary}

# Total Spending: {total}

# Category Breakdown: {category_map}
# Team Breakdown: {team_map}

# Give:
# 1. Overall financial insight
# 2. Risk level (Low/Medium/High)
# 3. Category-wise analysis
# 4. Monthly burn rate estimate
# 5. Budget warning if needed
# 6. Team-wise spending insight
# 7. 3 actionable recommendations

# Keep it short, structured, and practical.
# """

#     else:
#         # fallback (single expense)
#         prompt = f"""
# Analyze this expense:
# Amount: {data['amount']}
# Category: {data['category']}
# Type: {data['type']}
# Description: {data['description']}
# """

#     result = call_llm(prompt)

#     return {
#         "status": "success",
#         "insight": result
#     }

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import requests
import os
from dotenv import load_dotenv
import pandas as pd

# Load env
load_dotenv()

app = FastAPI(title="AI Financial Advisor API")

# ✅ CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

API_KEY = os.getenv("GROQ_API_KEY")


# ---------------------------
# 🔥 LLM CALL
# ---------------------------
def call_llm(prompt: str):
    try:
        res = requests.post(
            "https://api.groq.com/openai/v1/chat/completions",
            headers={
                "Authorization": f"Bearer {API_KEY}",
                "Content-Type": "application/json"
            },
            json={
                "model": "llama-3.1-8b-instant",
                "messages": [{"role": "user", "content": prompt}],
                "temperature": 0.3,
                "max_tokens": 400
            },
            timeout=10
        )

        if res.status_code != 200:
            return f"AI ERROR: {res.text}"

        return res.json()["choices"][0]["message"]["content"]

    except Exception as e:
        return f"Exception: {str(e)}"


# ---------------------------
# ✅ HEALTH
# ---------------------------
@app.get("/")
def home():
    return {"status": "AI API running 🚀"}


# ---------------------------
# 🔥 MAIN ENDPOINT (FIXED)
# ---------------------------
@app.post("/expense-ai")
def expense_ai(data: dict):

    if "expenses" not in data:
        return {"status": "error", "insight": "No expenses provided"}

    expenses = data["expenses"]

    if not expenses:
        return {"status": "success", "insight": "No expense data found"}

    # ---------------------------
    # ✅ REAL CALCULATIONS (IMPORTANT)
    # ---------------------------

    df = pd.DataFrame(expenses)

    df["amount"] = pd.to_numeric(df["amount"], errors="coerce").fillna(0)

    total_spend = df["amount"].sum()

    category_map = df.groupby("category")["amount"].sum().to_dict()
    team_map = df.groupby("team")["amount"].sum().to_dict()

    avg_expense = df["amount"].mean()

    top_category = max(category_map, key=category_map.get)
    top_team = max(team_map, key=team_map.get)

    # Simple burn estimate (since no full timeline)
    burn_rate = total_spend  # can improve later with dates

    # Risk logic
    risk = "Low"
    if total_spend > 50000:
        risk = "Medium"
    if total_spend > 100000:
        risk = "High"

    # Detect anomalies
    anomalies = df[df["amount"] > avg_expense * 2]

    anomaly_text = ""
    if not anomalies.empty:
        anomaly_text = f"{len(anomalies)} high-value expenses detected"

    # ---------------------------
    # 🔥 STRUCTURED PROMPT (CRITICAL FIX)
    # ---------------------------

    prompt = f"""
You are a startup financial advisor.

IMPORTANT:
- Use ONLY the provided numbers
- DO NOT assume extra data
- DO NOT hallucinate

DATA:
Total Spending: {total_spend}
Burn Rate: {burn_rate}
Risk Level: {risk}

Category Breakdown:
{category_map}

Team Breakdown:
{team_map}

Top Category: {top_category}
Top Team: {top_team}

Anomalies: {anomaly_text}

TASK:
Generate:

1. Financial Summary (based strictly on data)
2. Risk Explanation (justify the risk level)
3. Category Insight
4. Team Insight
5. 3 Actionable Cost-Cutting Recommendations

Keep it:
- Short
- Structured
- Practical
"""

    result = call_llm(prompt)

    return {
        "status": "success",
        "metrics": {
            "total_spending": total_spend,
            "burn_rate": burn_rate,
            "risk": risk,
            "top_category": top_category,
            "top_team": top_team
        },
        "insight": result
    }