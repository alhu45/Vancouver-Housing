import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
import requests
import json

st.set_page_config(
    page_title  = "Vancouver Livability Platform",
    page_icon   = "🏙️",
    layout      = "wide",
)

st.markdown("""
<style>
    html, body, [class*="css"], .stApp {
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
        background-color: #0d1117 !important;
        color: #e6edf3 !important;
    }
    [data-testid="stSidebar"] {
        background-color: #161b22 !important;
        border-right: 1px solid #30363d;
    }
    [data-testid="stSidebar"] * { color: #e6edf3 !important; }
    .main .block-container {
        background-color: #0d1117 !important;
        padding-top: 2rem;
    }
    [data-testid="stMetric"] {
        background-color: #161b22 !important;
        border: 1px solid #30363d !important;
        border-radius: 10px !important;
        padding: 1rem !important;
    }
    [data-testid="stMetricLabel"] p { color: #8b949e !important; font-size: 0.8rem !important; }
    [data-testid="stMetricValue"]   { color: #e6edf3 !important; }
    [data-testid="stSelectbox"] > div > div {
        background-color: #161b22 !important;
        border: 1px solid #30363d !important;
        color: #e6edf3 !important;
        border-radius: 8px !important;
    }
    [data-testid="stSelectbox"] label {
        color: #8b949e !important; font-size: 0.8rem !important;
        text-transform: uppercase; letter-spacing: 0.5px;
    }
    [data-testid="stSlider"] label {
        color: #8b949e !important; font-size: 0.8rem !important;
        text-transform: uppercase; letter-spacing: 0.5px;
    }
    hr { border-color: #30363d !important; }
    [data-testid="stAlert"] {
        background-color: #161b22 !important;
        border: 1px solid #30363d !important;
        color: #e6edf3 !important;
    }
    .main-title {
        font-size: 2.2rem; font-weight: 700;
        color: #58a6ff; letter-spacing: -0.5px; margin-bottom: 0;
    }
    .subtitle {
        font-size: 1rem; color: #8b949e;
        margin-top: 0.2rem; margin-bottom: 2rem;
    }
    .section-header {
        font-size: 1.2rem; font-weight: 600; color: #e6edf3;
        border-bottom: 1px solid #30363d;
        padding-bottom: 0.5rem; margin-bottom: 1rem;
    }
</style>
""", unsafe_allow_html=True)


@st.cache_data(ttl=3600)
def load_from_snowflake() -> pd.DataFrame:
    import snowflake.connector
    conn = snowflake.connector.connect(
        user      = st.secrets["snowflake"]["user"],
        password  = st.secrets["snowflake"]["password"],
        account   = st.secrets["snowflake"]["account"],
        warehouse = st.secrets["snowflake"]["warehouse"],
        database  = "VANCOUVER_DATA",
        schema    = "GOLD",
    )
    df = pd.read_sql("SELECT * FROM GOLD_NEIGHBOURHOOD_LIVABILITY_INDEX ORDER BY LIVABILITY_RANK", conn)
    conn.close()
    return df


@st.cache_data(ttl=3600)
def load_geojson() -> dict:
    url = "https://opendata.vancouver.ca/api/explore/v2.1/catalog/datasets/local-area-boundary/exports/geojson"
    return requests.get(url, timeout=10).json()


def load_demo_data() -> pd.DataFrame:
    return pd.read_csv("gold-fetch_2026-04-14-1154.csv")


try:
    df = load_from_snowflake()
except Exception:
    df = load_demo_data()

df.columns = [c.upper() for c in df.columns]

try:
    geojson = load_geojson()
except Exception:
    geojson = None

# ── Header ──
st.markdown('<p class="main-title">🏙️ Vancouver Livability Platform</p>', unsafe_allow_html=True)
st.markdown('<p class="subtitle">Neighbourhood intelligence powered by crime, housing, and transit data</p>', unsafe_allow_html=True)

# ── Sidebar ──
with st.sidebar:
    st.markdown("### 🎛️ Filters")
    score_metric = st.selectbox(
        "Colour map by",
        options=["COMPOSITE_LIVABILITY_SCORE","CRIME_SAFETY_SCORE",
                 "HOUSING_AFFORDABILITY_SCORE","TRANSIT_ACCESSIBILITY_SCORE","TRANSIT_COVERAGE_SCORE"],
        format_func=lambda x: x.replace("_", " ").title()
    )
    min_score = st.slider(
        "Min composite score",
        min_value=0, max_value=int(df["COMPOSITE_LIVABILITY_SCORE"].max()), value=0, step=5,
    )
    st.markdown("---")
    st.markdown("### 📊 About")
    st.markdown("""
    **Composite Score Weights:**
    - 🔴 Crime Safety — 30%
    - 🏠 Housing Affordability — 25%
    - 🚌 Transit Accessibility — 25%
    - 🗺️ Transit Coverage — 20%

    *Scores are min-max normalized (0–100). Higher = better livability.*
    """)

# ── Filter ──
filtered_df = df[df["COMPOSITE_LIVABILITY_SCORE"] >= min_score].copy()

# ── Top Metrics ──
col1, col2, col3, col4 = st.columns(4)

if filtered_df.empty:
    top_neighbourhood, avg_score, avg_crime, avg_housing = "N/A", 0, 0, 0
else:
    top_neighbourhood = filtered_df.loc[filtered_df["LIVABILITY_RANK"].idxmin(), "NEIGHBOURHOOD"]
    avg_score         = filtered_df["COMPOSITE_LIVABILITY_SCORE"].mean()
    avg_crime         = filtered_df["TOTAL_CRIME_INCIDENTS"].mean()
    avg_housing       = filtered_df["AVG_HOUSING_PRICE"].mean()

with col1: st.metric("🏆 Most Livable", top_neighbourhood)
with col2: st.metric("📊 Avg Livability Score", f"{avg_score:.1f} / 100")
with col3: st.metric("🚨 Avg Crime Incidents", f"{avg_crime:,.0f}")
with col4: st.metric("🏠 Avg Housing Price", f"${avg_housing:,.0f}")

st.markdown("---")

# ── Map + Table ──
map_col, table_col = st.columns([3, 2])

with map_col:
    st.markdown('<p class="section-header">Neighbourhood Map</p>', unsafe_allow_html=True)

    if geojson:
        name_mapping = {"Arbutus-Ridge": "Arbutus Ridge"}
        filtered_df["NEIGHBOURHOOD_CLEAN"] = filtered_df["NEIGHBOURHOOD"].str.strip().replace(name_mapping)

        fig_map = px.choropleth_mapbox(
            filtered_df,
            geojson=geojson, locations="NEIGHBOURHOOD_CLEAN", featureidkey="properties.name",
            color=score_metric, color_continuous_scale="RdYlGn", range_color=(0, 100),
            mapbox_style="carto-darkmatter", zoom=11,
            center={"lat": 49.2827, "lon": -123.1207}, opacity=0.75,
            hover_name="NEIGHBOURHOOD",
            hover_data={
                "COMPOSITE_LIVABILITY_SCORE": ":.1f", "CRIME_SAFETY_SCORE": ":.1f",
                "HOUSING_AFFORDABILITY_SCORE": ":.1f", "TRANSIT_ACCESSIBILITY_SCORE": ":.1f",
                "NEIGHBOURHOOD_CLEAN": False,
            },
            labels={
                "COMPOSITE_LIVABILITY_SCORE": "Livability", "CRIME_SAFETY_SCORE": "Crime Safety",
                "HOUSING_AFFORDABILITY_SCORE": "Housing", "TRANSIT_ACCESSIBILITY_SCORE": "Transit",
            }
        )

        # Hardcoded label positions (override centroid for any neighbourhood)
        label_overrides = {
            "West Point Grey": {"lat": 49.264545, "lon": -123.200499},
            "Kitslano": {"lat": 49.264074, "lon": -123.165706},
            "Strathcona": {"lat": 49.277702, "lon": -123.084045},
            "Kerrisdale": {"lat": 49.226761, "lon": -123.158349 },
            "Arbutus Ridge":          {"lat": 49.247908, "lon": -123.161873},
            "Shaughnessy": {"lat": 49.246589, "lon": -123.135610}, 
            "Riley Park": {"lat": 49.249793, "lon": -123.095852}, 
            "South Cambie":           {"lat": 49.236801, "lon": -123.125296},
            "Renfrew-Collingwood":    {"lat": 49.248245, "lon": -123.035092},

        }

        labels_lat, labels_lon, labels_text = [], [], []
        for feature in geojson["features"]:
            name = feature["properties"]["name"]
            geom = feature["geometry"]

            # Use hardcoded position if available
            if name in label_overrides:
                labels_lat.append(label_overrides[name]["lat"])
                labels_lon.append(label_overrides[name]["lon"])
                labels_text.append(name)
                continue

            # Otherwise calculate centroid automatically
            try:
                if geom["type"] == "Polygon":
                    pts = geom["coordinates"][0]
                elif geom["type"] == "MultiPolygon":
                    pts = max(geom["coordinates"], key=lambda p: len(p[0]))[0]
                else:
                    continue
                lat = sum(p[1] for p in pts) / len(pts)
                lon = sum(p[0] for p in pts) / len(pts)
                labels_lat.append(lat)
                labels_lon.append(lon)
                labels_text.append(name)
            except:
                pass

        fig_map.add_trace(go.Scattermapbox(
            lat  = labels_lat,
            lon  = labels_lon,
            mode = "text",
            text = labels_text,
            textfont = dict(size=10, color="white"),
            hoverinfo = "none",
            showlegend = False,
        ))

        fig_map.update_layout(
            margin={"r": 0, "t": 0, "l": 0, "b": 0},
            paper_bgcolor="#0d1117",
            coloraxis_colorbar=dict(
                title=dict(text=score_metric.replace("_", " ").title(), font=dict(color="#8b949e")),
                tickfont=dict(color="#8b949e"),
            )
        )
        st.plotly_chart(fig_map, use_container_width=True)

    else:
        st.warning("GeoJSON unavailable — showing scatter map instead.")

with table_col:
    st.markdown('<p class="section-header">Neighbourhood Rankings</p>', unsafe_allow_html=True)

    ranking_df = filtered_df.sort_values("LIVABILITY_RANK")[
        ["LIVABILITY_RANK", "NEIGHBOURHOOD", "COMPOSITE_LIVABILITY_SCORE",
         "CRIME_SAFETY_SCORE", "HOUSING_AFFORDABILITY_SCORE", "TRANSIT_ACCESSIBILITY_SCORE"]
    ].copy()
    ranking_df.columns = ["Rank", "Neighbourhood", "Score", "Crime", "Housing", "Transit"]

    def score_cell(val):
        v = float(val)
        if v >= 65:   return f"<td style='padding:7px 10px; text-align:center; background:#1a4731; color:#3fb950; border-radius:4px;'>{v:.1f}</td>"
        elif v >= 45: return f"<td style='padding:7px 10px; text-align:center; background:#3d2f00; color:#d29922; border-radius:4px;'>{v:.1f}</td>"
        else:         return f"<td style='padding:7px 10px; text-align:center; background:#3d1b1b; color:#f85149; border-radius:4px;'>{v:.1f}</td>"

    rows_html = ""
    for _, row in ranking_df.iterrows():
        rows_html += "<tr style='border-bottom:1px solid #21262d;'>"
        rows_html += f"<td style='padding:7px 10px; color:#8b949e;'>{int(row['Rank'])}</td>"
        rows_html += f"<td style='padding:7px 10px; color:#e6edf3; font-weight:500;'>{row['Neighbourhood']}</td>"
        for col in ["Score", "Crime", "Housing", "Transit"]:
            rows_html += score_cell(row[col])
        rows_html += "</tr>"

    st.markdown(f"""
    <div style="overflow-y:auto; max-height:500px; border:1px solid #30363d; border-radius:8px; background:#161b22;">
        <table style="width:100%; border-collapse:collapse; font-size:0.85rem;">
            <thead>
                <tr style="border-bottom:2px solid #30363d; background:#161b22; position:sticky; top:0;">
                    <th style="padding:10px; color:#8b949e; text-align:left; font-weight:500;">Rank</th>
                    <th style="padding:10px; color:#8b949e; text-align:left; font-weight:500;">Neighbourhood</th>
                    <th style="padding:10px; color:#8b949e; text-align:center; font-weight:500;">Score</th>
                    <th style="padding:10px; color:#8b949e; text-align:center; font-weight:500;">Crime</th>
                    <th style="padding:10px; color:#8b949e; text-align:center; font-weight:500;">Housing</th>
                    <th style="padding:10px; color:#8b949e; text-align:center; font-weight:500;">Transit</th>
                </tr>
            </thead>
            <tbody>{rows_html}</tbody>
        </table>
    </div>
    """, unsafe_allow_html=True)

# ── Pillar Breakdown ──
st.markdown("---")
st.markdown('<p class="section-header">Pillar Breakdown by Neighbourhood</p>', unsafe_allow_html=True)

pillar_df = filtered_df.sort_values("COMPOSITE_LIVABILITY_SCORE", ascending=False)
fig_bar   = go.Figure()

pillars = {
    "Crime Safety":          ("CRIME_SAFETY_SCORE",          "#f85149"),
    "Housing Affordability": ("HOUSING_AFFORDABILITY_SCORE", "#58a6ff"),
    "Transit Accessibility": ("TRANSIT_ACCESSIBILITY_SCORE", "#3fb950"),
    "Transit Coverage":      ("TRANSIT_COVERAGE_SCORE",      "#d29922"),
}

for label, (col, color) in pillars.items():
    fig_bar.add_trace(go.Bar(name=label, x=pillar_df["NEIGHBOURHOOD"], y=pillar_df[col],
                             marker_color=color, opacity=0.85))

fig_bar.update_layout(
    barmode="group", paper_bgcolor="#0d1117", plot_bgcolor="#0d1117", font_color="#8b949e",
    legend=dict(font=dict(color="#e6edf3"), bgcolor="#161b22", bordercolor="#30363d", borderwidth=1),
    xaxis=dict(tickangle=-35, gridcolor="#21262d", tickfont=dict(color="#e6edf3")),
    yaxis=dict(title="Score (0-100)", gridcolor="#21262d", range=[0, 100], tickfont=dict(color="#e6edf3")),
    margin=dict(t=20, b=100), height=420,
)
st.plotly_chart(fig_bar, use_container_width=True)

# ── Deep Dive ──
st.markdown("---")
st.markdown('<p class="section-header">Neighbourhood Deep Dive</p>', unsafe_allow_html=True)

if not filtered_df.empty:
    selected = st.selectbox(
        "Select a neighbourhood",
        options=filtered_df.sort_values("LIVABILITY_RANK")["NEIGHBOURHOOD"].tolist()
    )
    row = filtered_df[filtered_df["NEIGHBOURHOOD"] == selected].iloc[0]

    d1, d2, d3, d4, d5 = st.columns(5)
    d1.metric("🏆 Livability Score",  f"{row['COMPOSITE_LIVABILITY_SCORE']:.1f}")
    d2.metric("🔴 Crime Safety",      f"{row['CRIME_SAFETY_SCORE']:.1f}")
    d3.metric("🏠 Housing Afford.",   f"{row['HOUSING_AFFORDABILITY_SCORE']:.1f}")
    d4.metric("🚌 Transit Access.",   f"{row['TRANSIT_ACCESSIBILITY_SCORE']:.1f}")
    d5.metric("🗺️ Transit Coverage", f"{row['TRANSIT_COVERAGE_SCORE']:.1f}")

    r1, r2, r3 = st.columns(3)
    r1.metric("Avg Housing Price",     f"${row['AVG_HOUSING_PRICE']:,.0f}")
    r2.metric("Total Crime Incidents", f"{row['TOTAL_CRIME_INCIDENTS']:,}")
    r3.metric("Total Transit Trips",   f"{row['TOTAL_TRANSIT_TRIPS']:,}")

    fig_radar = go.Figure(go.Scatterpolar(
        r=[row["CRIME_SAFETY_SCORE"], row["HOUSING_AFFORDABILITY_SCORE"],
           row["TRANSIT_ACCESSIBILITY_SCORE"], row["TRANSIT_COVERAGE_SCORE"],
           row["ANOMALY_SAFETY_SCORE"], row["CRIME_SAFETY_SCORE"]],
        theta=["Crime Safety", "Housing", "Transit Access.", "Transit Coverage", "Anomaly Safety", "Crime Safety"],
        fill="toself", fillcolor="rgba(88, 166, 255, 0.15)",
        line=dict(color="#58a6ff", width=2), name=selected,
    ))
    fig_radar.update_layout(
        polar=dict(
            bgcolor="#161b22",
            radialaxis=dict(visible=True, range=[0, 100], gridcolor="#30363d", tickfont=dict(color="#8b949e")),
            angularaxis=dict(gridcolor="#30363d", tickfont=dict(color="#e6edf3")),
        ),
        paper_bgcolor="#0d1117", showlegend=False, height=350, margin=dict(t=30, b=30),
    )
    st.plotly_chart(fig_radar, use_container_width=True)
else:
    st.info("Adjust the filter to see neighbourhood details.")

# ── Footer ──
st.markdown("---")
st.markdown(
    "<p style='color:#8b949e; font-size:0.8rem; text-align:center;'>"
    "Vancouver Livability Analytics Platform · Data: Vancouver Open Data · "
    "Stack: Terraform · AWS S3 · Snowflake · Databricks · dbt · Streamlit · Airflow"
    "</p>", unsafe_allow_html=True
)