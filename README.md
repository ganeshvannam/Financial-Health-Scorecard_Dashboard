# Financial Health Scorecard Dashboard

An end-to-end **ETL + Power BI solution** designed to help **restaurant owners** and **corporate analysts** gain insights into revenue, compliance, and financial health across 600+ retail stores.  

This project integrates **Azure SQL + Power BI** with a **custom SQL validation framework** to detect anomalies, enforce financial rules, and provide dynamic reporting dashboards.

---

## 🎯 Objectives
- Build an **interactive dashboard** for both store-level managers and corporate teams.
- Import, clean, and format raw data into structured, scalable tables.
- Design a **database and ETL pipeline** that supports incremental updates and new data.
- Detect **data anomalies** and visualize KPIs like revenue growth, compliance, and expense ratios.

---

## ⚙️ Implementation
- **ETL & Modeling**:  
  - Created consolidated rollups (Store → Franchisee → Organization) using `FinancialPivot`.
  - Automated account transformations with `AccountCalc` mappings.
  - Indexed key tables to boost query performance.
- **Validation Rules** (implemented in [`sql/Implentation.sql`](sql/Implentation.sql)):  
  1. **Assets vs Liabilities** (Store level)  
  2. **Revenue Growth ≥ 5%** (Organization level)  
  3. **Non-compliance Rate ≤ 10%** (Organization level)  
  4. **Expense-to-Sales ≤ 80%** (Franchisee level)
- **Dashboard (Power BI)**:
  - Selectable filters for Store, Franchisee, and Organization IDs.
  - KPI visuals for assets/liabilities, growth %, expense ratios, and compliance.

---

## 🖼️ Prototypes → Final Design
- **Prototype 1**: Hand-drawn outline (proof of concept).  
- **Prototype 2**: Figma design mock-up, more detailed.  
- **Prototype 3**: Power BI template with structure, no data.  
- **Final Product**: Clean, minimalist dashboard with dynamic filtering and rule-based views.

---

## 📊 Final Product Features
- Rule-based views update KPIs dynamically (Assets vs Liabilities, Expense-to-Sales, etc.).
- Drilldowns by **Store ID**, **Franchisee ID**, or **Organization ID**.
- Key statistics:  
  - Monthly revenue growth %  
  - Expense-to-Income ratios  
  - Total assets, liabilities, gross profit  

---

## 🚧 Challenges
- **Team**: Role clarity and learning new tools (Azure, Power BI).  
- **Data**: Null values, duplicates, negative IDs, failed conversions, dependency issues.  
- **Design**: Agreeing on platform choice, OS compatibility, and data-to-dashboard workflows.

---

## 🚀 Future Enhancements
- AI-driven insights & natural language Q&A.  
- Real-time streaming data + automated refresh.  
- Predictive analytics with ML models.  
- Advanced custom visuals and cross-platform embedding.  
- Stronger governance, security, and compliance.  

---
## 📂 Files
- **Implemntation.SQL**: Core ETL + validation scripts (account rollups, rules, pivoting)
- **Dashboard**: Final product of dashboard
- **Res_dashboard.pbix**: Power BI dashboard file visualizing revenue growth, assets vs liabilities, compliance, and expense ratios.
- **Final**: Supporting Documentation


---

## 👤 Author
**Ganesh Vannam**  
📧 [gvannam@mtu.edu](mailto:gvannam@mtu.edu)  
🔗 [LinkedIn](https://www.linkedin.com/in/ganesh-vannam-8681642a8/) | [GitHub](https://github.com/ganeshvannam)

---

## 📜 License
MIT License – see [LICENSE](LICENSE) for details.


