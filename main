import os
import json
from datetime import datetime, timedelta
from flask import Flask, request, jsonify
from flask_cors import CORS
import google.generativeai as genai
import resend

# ---- Flask App ----
app = Flask(__name__)
CORS(app, resources={r"/*": {"origins": "*"}})

# ---- Add global CORS headers ----
@app.after_request
def apply_cors(response):
    response.headers["Access-Control-Allow-Origin"] = "*"
    response.headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
    response.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization"
    return response

# ---- Gemini Config ----
GOOGLE_API_KEY = os.getenv("GOOGLE_API_KEY")
MODEL_NAME = os.getenv("GEMINI_MODEL", "gemini-1.5-flash")

if GOOGLE_API_KEY:
    genai.configure(api_key=GOOGLE_API_KEY)

# ---- Resend Config ----
RESEND_API_KEY = os.getenv("RESEND_API_KEY")
if RESEND_API_KEY:
    resend.api_key = RESEND_API_KEY

SYSTEM_INSTRUCTIONS = """
You are an agronomy assistant. Suggest pesticide recommendations and treatment
schedules based on crop, disease, severity, and field details.
Return strictly JSON only.
"""

# ---- Helpers ----
def make_prompt(payload: dict) -> str:
    return f"""
SYSTEM:
{SYSTEM_INSTRUCTIONS}

INPUT:
- plant_name: {payload['plant_name']}
- disease_percentage: {payload['disease_percentage']} %
- previous_fertilizers: {payload.get('previous_fertilizers') or 'None'}
- acres: {payload['acres']}
- location: {payload['location']}
- predicted_class: {payload['predicted_class']}

OUTPUT:
Provide JSON strictly in this format:
{{
  "confidence": 0.9,
  "treatment_schedule": [
    {{
      "product": "Azoxystrobin + Difenoconazole",
      "timing": "Day 0",
      "notes": "Systemic fungicide"
    }},
    {{
      "product": "Mancozeb",
      "timing": "Day 7",
      "notes": "Protectant fungicide"
    }}
  ]
}}
"""

def validate_payload(data):
    required = [
        "plant_name", "disease_percentage", "previous_fertilizers",
        "acres", "location", "predicted_class", "email"
    ]
    missing = [k for k in required if k not in data]
    if missing:
        return False, f"Missing: {', '.join(missing)}"

    try:
        float(data["disease_percentage"])
        float(data["acres"])
    except:
        return False, "disease_percentage and acres must be numbers."

    return True, None

def send_email(to_email, subject, html):
    if not RESEND_API_KEY:
        return {"success": False, "error": "Missing RESEND_API_KEY"}
    try:
        params: resend.Emails.SendParams = {
            "from": "Resend <onboarding@resend.dev>",
            "to": [to_email],
            "subject": subject,
            "html": html,
        }
        return resend.Emails.send(params)
    except Exception as e:
        return {"success": False, "error": str(e)}

# ---- Routes ----
@app.route("/", methods=["GET"])
def health():
    return jsonify({"status": "ok", "time": datetime.utcnow().isoformat() + "Z"})

@app.route("/recommend", methods=["POST", "OPTIONS"])
def recommend():
    if request.method == "OPTIONS":
        return jsonify({"status": "ok"}), 200

    if not GOOGLE_API_KEY:
        return jsonify({"status": "fail", "error": "Missing GOOGLE_API_KEY env var"}), 500

    data = request.get_json(silent=True)
    if not data:
        return jsonify({"status": "fail", "error": "Expected JSON body"}), 400

    ok, err = validate_payload(data)
    if not ok:
        return jsonify({"status": "fail", "error": err}), 400

    try:
        # Call Gemini
        prompt = make_prompt(data)
        model = genai.GenerativeModel(MODEL_NAME)
        resp = model.generate_content(prompt)
        text = (resp.text or "").strip()

        # Extract JSON safely
        start, end = text.find("{"), text.rfind("}")
        parsed = {}
        if start != -1 and end != -1:
            parsed = json.loads(text[start:end+1])

        treatment_schedule = parsed.get("treatment_schedule", [])

        # Build schedules & pesticides
        schedules = []
        pesticides = []
        today = datetime.utcnow().date()
        for idx, t in enumerate(treatment_schedule, start=1):
            pname = t.get("product", "Unknown")
            pesticides.append(pname)
            schedules.append({
                "pesticide_name": pname,
                "scheduled_date": (today + timedelta(days=(idx-1)*7)).isoformat(),
                "completed": False
            })

        # ---- Build HTML for email ----
        # ---- Build HTML for email ----
        html_rows = "".join([
            f"<tr><td>{s['pesticide_name']}</td><td>{s['scheduled_date']}</td><td>Not Completed</td></tr>"
            for s in schedules
        ])
        html_content = f"""
<!DOCTYPE html>
<html>
  <head>
    <meta charset="UTF-8">
    <style>
      body {{
        font-family: Arial, sans-serif;
        background: #f9fafb;
        margin: 0;
        padding: 20px;
        color: #333;
      }}
      .container {{
        max-width: 600px;
        margin: auto;
        background: #ffffff;
        border-radius: 12px;
        overflow: hidden;
        box-shadow: 0 4px 12px rgba(0,0,0,0.1);
      }}
      .header {{
        background: linear-gradient(90deg, #16a34a, #4ade80);
        padding: 20px;
        color: white;
        text-align: center;
      }}
      .header h1 {{
        margin: 0;
        font-size: 22px;
      }}
      .details {{
        padding: 20px;
        font-size: 14px;
        line-height: 1.6;
      }}
      .details strong {{
        color: #16a34a;
      }}
      table {{
        width: 100%;
        border-collapse: collapse;
        margin-top: 10px;
      }}
      table th, table td {{
        border: 1px solid #e5e7eb;
        padding: 10px;
        text-align: left;
      }}
      table th {{
        background: #f3f4f6;
        font-size: 13px;
        text-transform: uppercase;
      }}
      table tr:nth-child(even) {{
        background: #f9fafb;
      }}
      .footer {{
        text-align: center;
        font-size: 12px;
        color: #6b7280;
        padding: 15px;
        background: #f3f4f6;
      }}
    </style>
  </head>
  <body>
    <div class="container">
      <div class="header">
        <h1>🌱 Farmcare Treatment Schedule</h1>
      </div>
      <div class="details">
        <p><strong>Plant:</strong> {data['plant_name']}</p>
        <p><strong>Disease:</strong> {data['predicted_class']} ({data['disease_percentage']}%)</p>
        <p><strong>Acres:</strong> {data['acres']} | <strong>Location:</strong> {data['location']}</p>
        <h3>🧾 Recommended Schedule:</h3>
        <table>
          <tr>
            <th>Pesticide</th>
            <th>Date</th>
            <th>Status</th>
          </tr>
          {html_rows}
        </table>
      </div>
      <div class="footer">
        <p>💡 Tip: Follow this schedule carefully for best results.<br>
        Powered by Farmcare AI Assistant.</p>
      </div>
    </div>
  </body>
</html>
"""



        # ---- Send Email ----
        email_response = send_email(
            data["email"],
            f"Treatment Schedule for {data['plant_name']}",
            html_content
        )

        return jsonify({
            "status": "success",
            "pesticides": pesticides,
            "treatment_schedules": schedules,
            "email_response": email_response
        })

    except Exception as e:
        return jsonify({"status": "fail", "error": str(e)}), 500


if __name__ == "__main__":
    port = int(os.getenv("PORT", 5000))
    app.run(host="0.0.0.0", port=port)
