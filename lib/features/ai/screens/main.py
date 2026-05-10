from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import requests
import os
import pandas as pd
from dotenv import load_dotenv

load_dotenv()

app = FastAPI(title="AI CFO Backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

API_KEY = os.getenv("GROQ_API_KEY")


# ---------------------------
# GROQ CALL
# ---------------------------
def call_llm(prompt):
    try:
        response = requests.post(
            "https://api.groq.com/openai/v1/chat/completions",
            headers={
                "Authorization": f"Bearer {API_KEY}",
                "Content-Type": "application/json"
            },
            json={
                "model": "llama-3.1-8b-instant",
                "messages": [
                    {
                        "role": "user",
                        "content": prompt
                    }
                ],
                "temperature": 0.3,
                "max_tokens": 400
            },
            timeout=15
        )

        if response.status_code != 200:
            return f"Groq Error: {response.text}"

        return response.json()["choices"][0]["message"]["content"]

    except Exception as e:
        return f"Error: {str(e)}"


# ---------------------------
# HEALTH CHECK
# ---------------------------
@app.get("/")
def home():
    return {
        "status": "AI backend running"
    }


# ---------------------------
# MAIN ENDPOINT
# ---------------------------
@app.post("/generate-ai-section")
def generate_ai_section(data: dict):

    print("INCOMING DATA:", data)

    section_name = data.get("sectionName")
    section_data = data.get("sectionData", {})

    expenses = section_data.get("expenses", [])
    revenue = section_data.get("revenue", [])
    company = section_data.get("company", {})
    members = section_data.get("members", [])
    teams = section_data.get("teams", [])

    metrics = {}

    # ---------------------------
    # EXPENSE CALCULATIONS
    # ---------------------------
    total_spending = 0

    if expenses:
        expense_df = pd.DataFrame(expenses)

        if "Amount" in expense_df.columns:
            expense_df["Amount"] = pd.to_numeric(
                expense_df["Amount"],
                errors="coerce"
            ).fillna(0)

            total_spending = float(
                expense_df["Amount"].sum()
            )

            metrics["total_spending"] = total_spending
            metrics["avg_spending"] = float(
                expense_df["Amount"].mean()
            )

            if "Category" in expense_df.columns:
                metrics["category_breakdown"] = (
                    expense_df.groupby("Category")["Amount"]
                    .sum()
                    .to_dict()
                )

    # ---------------------------
    # REVENUE CALCULATIONS
    # ---------------------------
    total_revenue = 0

    if revenue:
        revenue_df = pd.DataFrame(revenue)

        if "Amount" in revenue_df.columns:
            revenue_df["Amount"] = pd.to_numeric(
                revenue_df["Amount"],
                errors="coerce"
            ).fillna(0)

            total_revenue = float(
                revenue_df["Amount"].sum()
            )

    metrics["total_revenue"] = total_revenue

    # ---------------------------
    # COMPANY DATA
    # ---------------------------
    funding = float(
        company.get("Funding", 0) or 0
    )

    runway = company.get(
        "Runway",
        "Unknown"
    )

    metrics["funding"] = funding
    metrics["runway"] = runway

    # ---------------------------
    # MEMBERS / TEAMS
    # ---------------------------
    metrics["team_count"] = len(teams)
    metrics["member_count"] = len(members)

    # ---------------------------
    # NET BURN
    # ---------------------------
    net_burn = total_spending - total_revenue
    metrics["net_burn"] = net_burn

    # ---------------------------
    # RISK
    # ---------------------------
    risk = "Low"

    if net_burn > 50000:
        risk = "Medium"

    if net_burn > 100000:
        risk = "High"

    metrics["risk"] = risk

    print("CALCULATED METRICS:", metrics)

    # ---------------------------
    # LLM PROMPT
    # ---------------------------
    prompt = f"""
You are an AI CFO advisor for startups.

Section:
{section_name}

Calculated Business Metrics:
{metrics}

Give:

1. Main financial insight
2. Risk explanation
3. Cost optimization suggestion
4. Growth recommendation
5. Future warning

Keep it concise and actionable.
"""

    result = call_llm(prompt)

    return {
        "status": "success",
        "metrics": metrics,
        "insight": result
    }