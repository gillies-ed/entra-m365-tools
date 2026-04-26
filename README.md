# Entra / M365 Tools

A collection of browser-based tools for analysing Microsoft Entra ID and M365 data.
No server required — everything runs locally in the browser. No data leaves your machine.

---

## Sign-in Log Analyser

**`signin-analyser/v2/index.html`**

Multi-user sign-in log viewer for Entra ID CSV exports. Load logs for one or more users,
compare activity side-by-side, and surface potential threat signals automatically.

### How to use

1. Open `signin-analyser/v2/index.html` in any modern browser
2. Add a user row for each account you want to analyse
3. Export sign-in logs from the [Entra portal](https://entra.microsoft.com) under:
   - **Identity > Users > Sign-in logs** (Interactive + Non-Interactive)
   - **Identity > Applications > Enterprise apps > Sign-in logs** (Application)
4. Drop the CSV exports into the corresponding slots
5. Stats, charts, and threat signals populate automatically

### Features

- Colour-coded per-user view across Interactive, Non-Interactive, and Application log types
- Summary stats: total sign-ins, success/failure rates, unique IPs, apps, locations, date range
- Charts: status breakdown, sign-ins over time, top applications, top locations
- Filters: user, type, status, application, location, date range, free-text search
- **Threat signals:**
  - Shared IPs across users with failures
  - Shared locations across users with failures
  - High failure rate (>50%) per user
- Export filtered results as CSV
- Paginated table with grouping by IP, location, or user

### Privacy

All processing happens in your browser. No data is sent anywhere.
CSV files are read locally and never leave your machine.

### Tech

Vanilla HTML/JS — no build step, no install.
Dependencies loaded from CDN with SRI integrity hashes:
- [PapaParse](https://www.papaparse.com/) — CSV parsing
- [Chart.js](https://www.chartjs.org/) — charts
